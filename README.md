# auto-zebra

This is a small automatic printing utility for Zebra label printers.

It watches a folder and when it detects new files downloaded that contain a certain string it will send them to the label printer and then remove the file.

## 1. Install on Windows

From Powershell

```bash
iwr https://raw.githubusercontent.com/dane-stevens/auto-zebra/main/install.ps1 | iex
```

## 2. Disable automatic opening of PDFs

1. Open Adobe Acrobat
2. `Ctrl` + `K` to open settings
3. General
4. Uncheck "Always open PDFs saved from the web