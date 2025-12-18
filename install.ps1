$ErrorActionPreference = "Stop"

Write-Host "== Auto Zebra install =="

# ---------------- CONFIG ----------------
$InstallDir  = "C:\auto-zebra"
$RepoRaw     = "https://raw.githubusercontent.com/dane-stevens/auto-zebra/main/src"
$StartupDir  = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$ShortcutPath = "$StartupDir\Auto Print Labels.lnk"

# ---------------- PYTHON ----------------
if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
    Write-Host "Python not found. Installing..."
    winget install 9NQ7512CXL7T -e `
        --accept-package-agreements `
        --accept-source-agreements
} else {
    Write-Host "Python already installed."
}

# ---------------- PIP / WATCHDOG ----------------
Write-Host "Ensuring pip..."
py -m ensurepip --upgrade 2>$null
py -m pip install --upgrade pip --quiet

if (-not (py -m pip show watchdog 2>$null)) {
    Write-Host "Installing watchdog..."
    py -m pip install watchdog --quiet
} else {
    Write-Host "watchdog already installed."
}

# ---------------- FILES ----------------
Write-Host "Updating files..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

Invoke-WebRequest "$RepoRaw/auto_print_labels.py" `
    -OutFile "$InstallDir\auto_print_labels.py"

Invoke-WebRequest "$RepoRaw/PDF-XChange Viewer Settings.dat" `
    -OutFile "$InstallDir\PDF-XChange Viewer Settings.dat"

if (-not (Test-Path "$InstallDir\PDFtoPrinter.exe")) {
    Write-Host "Downloading PDFtoPrinter.exe..."
    Invoke-WebRequest "$RepoRaw/PDFtoPrinter.exe" `
        -OutFile "$InstallDir\PDFtoPrinter.exe"
} else {
    Write-Host "PDFtoPrinter.exe already exists."
}

# ---------------- FIND PYTHONW ----------------
Write-Host "Locating pythonw.exe..."

$PythonExe = & py -3 -c "import sys; print(sys.executable)" 2>$null |
    Select-Object -Last 1 |
    ForEach-Object { $_.Trim() }

if (-not $PythonExe -or -not (Test-Path $PythonExe)) {
    throw "Failed to locate python.exe via py launcher"
}

$PythonDir = Split-Path $PythonExe
$PythonW   = Join-Path $PythonDir "pythonw.exe"

if (-not (Test-Path $PythonW)) {
    throw "pythonw.exe not found at $PythonW"
}

# ---------------- STARTUP SHORTCUT ----------------
if (-not (Test-Path $ShortcutPath)) {
    Write-Host "Creating startup shortcut..."

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $PythonW
    $Shortcut.Arguments  = "`"$InstallDir\auto_print_labels.py`""
    $Shortcut.WorkingDirectory = $InstallDir
    $Shortcut.Save()
} else {
    Write-Host "Startup shortcut already exists."
}

Write-Host "✔ Auto Zebra installed / updated"
Write-Host "✔ Safe to re-run this installer"