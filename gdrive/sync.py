import os
import time
import mimetypes
import logging
from dotenv import load_dotenv
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Load environment variables
load_dotenv()


LOCAL_FOLDER = "/data"
DRIVE_FOLDER_ID = os.getenv("DRIVE_FOLDER_ID")
CREDENTIALS_FILE = "/app/credentials.json"
LOG_FILE = "/app/sync.log"

# Configure logging
logging.basicConfig(filename=LOG_FILE, level=logging.INFO,
                    format="%(asctime)s - %(levelname)s - %(message)s")

# Authenticate Google Drive API
SCOPES = ["https://www.googleapis.com/auth/drive"]
creds = service_account.Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=SCOPES)
drive_service = build("drive", "v3", credentials=creds)

def get_drive_files():
    """Retrieve a dictionary of file extensions and their corresponding file IDs in Google Drive."""
    query = f"'{DRIVE_FOLDER_ID}' in parents and trashed=false"
    results = drive_service.files().list(q=query, fields="files(id, name)").execute()
    
    files = {}
    for file in results.get("files", []):
        file_name = file["name"]
        file_ext = os.path.splitext(file_name)[1]  # Extract file extension
        files[file_ext] = file["id"]  # Store by extension

    return files

def upload_large_file(file_path, file_name):
    """Uploads a large file using resumable upload."""
    mime_type = mimetypes.guess_type(file_path)[0] or "application/octet-stream"
    media = MediaFileUpload(file_path, mimetype=mime_type, resumable=True)
    
    file_metadata = {"name": file_name, "parents": [DRIVE_FOLDER_ID]}
    request = drive_service.files().create(body=file_metadata, media_body=media, fields="id")
    
    response = None
    while response is None:
        status, response = request.next_chunk()
        if status:
            logging.info(f"Uploading {file_name}: {int(status.progress() * 100)}% complete.")

    logging.info(f"Uploaded {file_name} (ID: {response['id']}).")

def update_large_file(file_id, file_path):
    """Deletes the old file and updates it with a new version while renaming it."""
    mime_type = mimetypes.guess_type(file_path)[0] or "application/octet-stream"
    media = MediaFileUpload(file_path, mimetype=mime_type, resumable=True)
    
    # Extract the new file's name
    new_file_name = os.path.basename(file_path)
    
    file_metadata = {
        "name": new_file_name  # Update the file name to reflect the new file
    }

    # First, delete the old file
    try:
        drive_service.files().delete(fileId=file_id).execute()
        logging.info(f"Deleted old file (ID: {file_id}).")
    except Exception as e:
        logging.error(f"Failed to delete old file (ID: {file_id}): {str(e)}")

    # Now, upload the new file with the new name
    request = drive_service.files().create(
        body=file_metadata,
        media_body=media,
        fields="id"
    )

    response = None
    while response is None:
        status, response = request.next_chunk()
        if status:
            logging.info(f"Uploading and renaming {new_file_name}: {int(status.progress() * 100)}% complete.")

    logging.info(f"Uploaded and renamed file to {new_file_name} (ID: {response['id']}).")


def delete_drive_file(file_id, file_name):
    """Deletes a file from Google Drive."""
    drive_service.files().delete(fileId=file_id).execute()
    logging.info(f"Deleted {file_name} from Google Drive.")

def sync_file(file_path):
    """Syncs a single file when it is created or modified, replacing the file and renaming it."""
    file_name = os.path.basename(file_path)  # Get the new file's name
    drive_files = get_drive_files()

    # Check if the file already exists in Google Drive
    if file_name in drive_files:
        file_id = drive_files[file_name]
        logging.info(f"Replacing existing file with the new file: {file_name}")

        # Replace the old file with the new one and keep the new name
        update_large_file(file_id, file_path)  # Update existing file
    else:
        logging.info(f"Uploading new file: {file_name}")
        upload_large_file(file_path, file_name)  # Upload as a new file


class Watcher(FileSystemEventHandler):
    """Watches for file changes and triggers sync."""
    def on_modified(self, event):
        if not event.is_directory:
            logging.info(f"Detected change in: {event.src_path}")
            sync_file(event.src_path)

    def on_created(self, event):
        if not event.is_directory:
            logging.info(f"New file detected: {event.src_path}")
            sync_file(event.src_path)

    def on_deleted(self, event):
        """Deletes file from Google Drive when removed locally."""
        if not event.is_directory:
            file_name = os.path.basename(event.src_path)
            drive_files = get_drive_files()
            if file_name in drive_files:
                delete_drive_file(drive_files[file_name], file_name)
                logging.info(f"File {file_name} deleted locally. Removed from Google Drive.")

def start_watching():
    """Starts the watchdog observer to monitor changes."""
    event_handler = Watcher()
    observer = Observer()
    observer.schedule(event_handler, path=LOCAL_FOLDER, recursive=True)
    observer.start()
    
    logging.info(f"Started watching: {LOCAL_FOLDER}")
    
    try:
        while True:
            time.sleep(5)
    except KeyboardInterrupt:
        observer.stop()
        logging.info("Watcher stopped.")
    observer.join()

if __name__ == "__main__":
    print("Starting Watchdog service...")
    logging.info("Starting Watchdog service...")
    start_watching()
