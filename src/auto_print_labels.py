import os
import json
import time
import subprocess
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Path to config file
CONFIG_FILE = os.path.join(os.path.dirname(__file__), "config.json")

DEFAULT_CONFIG = {
  PRINTER_NAME: "ZDesigner ZD410-300dpi ZPL",
  KEYWORDS: ["TreatmentLabel", "RxLabel", "PatientLabel"]
}

# Load config
if os.path.exists(CONFIG_FILE):
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        config = json.load(f)
else:
    config = DEFAULT_CONFIG

# ️ Path to your Downloads folder
DOWNLOADS_FOLDER = os.path.join(os.path.expanduser("~"), "Downloads")

# ️ Printer name
PRINTER_NAME = config.get("PRINTER_NAME") 

#  Keywords to match in filenames
KEYWORDS = config.get("KEYWORDS")

# ⏱️ Wait before printing (seconds) - helps avoid printing incomplete downloads
WAIT_SECONDS = 2

# Logging
LOG_FILE = os.path.join(os.path.dirname(__file__), "auto-zebra.log")

logging.basicConfig(
    handlers=[
        RotatingFileHandler(
            LOG_FILE,
            maxBytes=1_000_000,   # 1 MB
            backupCount=5,        # Keep 5 old logs
            encoding="utf-8"
        ),
        logging.StreamHandler()   # Still print to console
    ],
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

logger = logging.getLogger(__name__)


class PDFHandler(FileSystemEventHandler):
    def on_created(self, event):
        self.handle_event(event.src_path)

    def on_moved(self, event):
        self.handle_event(event.dest_path)

    def handle_event(self, file_path):
        if os.path.isdir(file_path):
            return

        file_name = os.path.basename(file_path)

        if (
            file_path.lower().endswith(".pdf")
            and any(k.lower() in file_name.lower() for k in KEYWORDS)
        ):
            logger.info(f"📄 Detected matching PDF: {file_name}")
            self.wait_for_download(file_path)
            self.print_and_delete(file_path)

    def wait_for_download(self, file_path):
        """Wait until file size stops changing"""
        last_size = -1
        while True:
            try:
                size = os.path.getsize(file_path)
                if size == last_size:
                    break
                last_size = size
                time.sleep(1)
            except FileNotFoundError:
                time.sleep(1)

    def print_and_delete(self, file_path):
        try:
            logger.info(f"️ Sending '{file_path}' to printer '{PRINTER_NAME}'...")
            # Use PowerShell to send to printer
            subprocess.run([
                "powershell",
                "-Command",
                f'C:\\auto-zebra\\PDFtoPrinter.exe "{file_path}" "{PRINTER_NAME}"'
            ], shell=True, check=True)

            time.sleep(WAIT_SECONDS)
            logger.info("✅ Print command sent successfully. Deleting file...")
            os.remove(file_path)
            logger.info(f"️ Deleted: {file_path}")

        except subprocess.CalledProcessError as e:
            logger.error(f"❌ Print command failed: {e}")
        except PermissionError:
            logger.warning(f"⚠️ Could not delete '{file_path}' (file in use). Will retry later.")
        except Exception as e:
            logger.error(f"❌ Error: {e}")


if __name__ == "__main__":
    event_handler = PDFHandler()
    observer = Observer()
    observer.schedule(event_handler, DOWNLOADS_FOLDER, recursive=False)

    logger.info(f" Watching folder: {DOWNLOADS_FOLDER}")
    logger.info(f" Target printer: {PRINTER_NAME}")
    logger.info(f" Matching filenames containing: {KEYWORDS}")
    logger.info(" Press Ctrl+C to stop.\n")

    observer.start()
    try:
        while True:
            time.sleep(2)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()

