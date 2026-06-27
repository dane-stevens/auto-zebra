import os
import json
import time
import logging
import subprocess
from logging.handlers import RotatingFileHandler

from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# ---------------- PATHS ----------------

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

CONFIG_FILE = os.path.join(BASE_DIR, "config.json")
LOG_FILE = os.path.join(BASE_DIR, "auto-zebra.log")
PDF_TO_PRINTER = os.path.join(BASE_DIR, "PDFtoPrinter.exe")

# ---------------- DEFAULT CONFIG ----------------

DEFAULT_CONFIG = {
    "PRINTER_NAME": "ZDesigner ZD410-300dpi ZPL",
    "KEYWORDS": [
        "TreatmentLabel",
        "RxLabel",
        "PatientLabel"
    ]
}

# ---------------- LOGGING ----------------

logging.basicConfig(
    handlers=[
        RotatingFileHandler(
            LOG_FILE,
            maxBytes=1_000_000,
            backupCount=5,
            encoding="utf-8"
        )
    ],
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

logger = logging.getLogger(__name__)

# ---------------- LOAD CONFIG ----------------

config = DEFAULT_CONFIG.copy()

if os.path.exists(CONFIG_FILE):
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            config.update(json.load(f))
    except Exception:
        logger.exception("Failed to load config.json. Using defaults.")

# ---------------- SETTINGS ----------------

DOWNLOADS_FOLDER = os.path.join(os.path.expanduser("~"), "Downloads")

PRINTER_NAME = config.get("PRINTER_NAME")
KEYWORDS = config.get("KEYWORDS", [])

WAIT_SECONDS = 2


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
            and any(keyword.lower() in file_name.lower() for keyword in KEYWORDS)
        ):
            logger.info("Detected matching PDF: %s", file_name)
            self.wait_for_download(file_path)
            self.print_and_delete(file_path)

    def wait_for_download(self, file_path):
        """Wait until the file size stops changing."""

        last_size = -1

        while True:
            try:
                size = os.path.getsize(file_path)

                if size == last_size:
                    return

                last_size = size
                time.sleep(1)

            except FileNotFoundError:
                time.sleep(1)

    def print_and_delete(self, file_path):

        try:

            logger.info(
                "Sending '%s' to printer '%s'",
                file_path,
                PRINTER_NAME
            )

            subprocess.run(
                [
                    PDF_TO_PRINTER,
                    file_path,
                    PRINTER_NAME,
                ],
                check=True
            )

            time.sleep(WAIT_SECONDS)

            logger.info("Print command completed.")

            os.remove(file_path)

            logger.info("Deleted %s", file_path)

        except subprocess.CalledProcessError:
            logger.exception("Printing failed.")

        except PermissionError:
            logger.warning(
                "Could not delete '%s' because it is still in use.",
                file_path
            )

        except Exception:
            logger.exception("Unexpected error while printing.")

# ---------------- MAIN ----------------

def main():

    logger.info("----------------------------------------")
    logger.info("Auto Zebra started")
    logger.info("Watching folder: %s", DOWNLOADS_FOLDER)
    logger.info("Printer: %s", PRINTER_NAME)
    logger.info("Keywords: %s", KEYWORDS)

    observer = Observer()
    observer.schedule(PDFHandler(), DOWNLOADS_FOLDER, recursive=False)
    observer.start()

    try:
        while True:
            time.sleep(2)

    except KeyboardInterrupt:
        logger.info("Stopping...")
        observer.stop()

    observer.join()


if __name__ == "__main__":

    try:
        main()

    except Exception:
        logger.exception("Fatal startup error.")
        raise
