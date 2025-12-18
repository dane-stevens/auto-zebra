# auto-zebra

This is a small automatic printing utility for Zebra label printers.

It watches a folder and when it detects new files downloaded that contain a certain string it will send them to the label printer and then remove the file.

```bash
curl -fsSL https://raw.githubusercontent.com/dane-stevens/auto-zebra/main/install.sh | bash
```