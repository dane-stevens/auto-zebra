#!/usr/bin/env bash
set -e

echo "== Auto Zebra install =="

# --- CONFIG ---
INSTALL_DIR="C:/auto-zebra"
REPO_RAW="https://raw.githubusercontent.com/dane-stevens/auto-zebra/main/src"
STARTUP_DIR="$(cmd.exe /c 'echo %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup' 2>/dev/null | tr -d '\r')"
SHORTCUT_PATH="$STARTUP_DIR/Auto Print Labels.lnk"

# --- CHECK OS ---
if [[ "$OS" != "Windows_NT" ]]; then
  echo "This installer is intended for Windows."
  exit 1
fi

# --- ENSURE PYTHON ---
if ! command -v py >/dev/null 2>&1; then
  echo "Python not found. Installing..."
  winget install --id 9NQ7512CXL7T -e \
    --accept-package-agreements \
    --accept-source-agreements
else
  echo "Python already installed."
fi

# --- ENSURE PIP ---
echo "Ensuring pip is up to date..."
py -m ensurepip --upgrade >/dev/null 2>&1 || true
py -m pip install --upgrade pip >/dev/null

# --- ENSURE WATCHDOG ---
if ! py -m pip show watchdog >/dev/null 2>&1; then
  echo "Installing watchdog..."
  py -m pip install watchdog
else
  echo "watchdog already installed."
fi

# --- ENSURE INSTALL DIR ---
mkdir -p "$INSTALL_DIR"

# --- FILE HANDLING ---
echo "Updating managed files..."

# Always update
curl -fsSL "$REPO_RAW/auto_print_labels.py" \
  -o "$INSTALL_DIR/auto_print_labels.py"

curl -fsSL "$REPO_RAW/PDF-XChange Viewer Settings.dat" \
  -o "$INSTALL_DIR/PDF-XChange Viewer Settings.dat"

# Download once if missing
if [[ ! -f "$INSTALL_DIR/PDFtoPrinter.exe" ]]; then
  echo "Downloading PDFtoPrinter.exe..."
  curl -fsSL "$REPO_RAW/PDFtoPrinter.exe" \
    -o "$INSTALL_DIR/PDFtoPrinter.exe"
else
  echo "PDFtoPrinter.exe already exists."
fi

# --- ENSURE STARTUP SHORTCUT ---
if [[ -f "$SHORTCUT_PATH" ]]; then
  echo "Startup shortcut already exists."
else
  echo "Creating startup shortcut..."

  POWERSHELL_SCRIPT=$(cat <<EOF
\$WshShell = New-Object -ComObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut("$SHORTCUT_PATH")
\$Shortcut.TargetPath = "pythonw.exe"
\$Shortcut.Arguments = "\"$INSTALL_DIR\\auto_print_labels.py\""
\$Shortcut.WorkingDirectory = "$INSTALL_DIR"
\$Shortcut.Save()
EOF
)

  powershell.exe -NoProfile -Command "$POWERSHELL_SCRIPT"
fi

echo
echo "✔ Auto Zebra installed / updated"
echo "✔ Re-running this script will update logic & settings"
