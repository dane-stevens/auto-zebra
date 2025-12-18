$ErrorActionPreference = "Stop"

Write-Host "== Auto Zebra install =="

$InstallDir = "C:\auto-zebra"
$RepoRaw = "https://raw.githubusercontent.com/dane-stevens/auto-zebra/main/src"
$StartupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$ShortcutPath = "$StartupDir\Auto Print Labels.lnk"

# --- Python ---
if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Python..."
    winget install 9NQ7512CXL7T -e --accept-package-agreements --accept-source-agreements
} else {
    Write-Host "Python already installed."
}

# --- Pip / watchdog ---
py -m pip install --upgrade pip
if (-not (py -m pip show watchdog 2>$null)) {
    py -m pip install watchdog
}

# --- Files ---
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

Invoke-WebRequest "$RepoRaw/auto_print_labels.py" -OutFile "$InstallDir\auto_print_labels.py"
Invoke-WebRequest "$RepoRaw/PDF-XChange Viewer Settings.dat" -OutFile "$InstallDir\PDF-XChange Viewer Settings.dat"

if (-not (Test-Path "$InstallDir\PDFtoPrinter.exe")) {
    Invoke-WebRequest "$RepoRaw/PDFtoPrinter.exe" -OutFile "$InstallDir\PDFtoPrinter.exe"
}

# --- Locate pythonw.exe ---
$PythonBase = py -0p | Select-String "\*" -Context 0,0
if (-not $PythonBase) {
    Write-Error "Unable to locate Python installation"
}

$PythonDir = ($PythonBase -replace "^\s*-\S+\s+", "").Trim()
$PythonW = Join-Path $PythonDir "pythonw.exe"

if (-not (Test-Path $PythonW)) {
    Write-Error "pythonw.exe not found at $PythonW"
}

# --- Startup shortcut ---
if (-not (Test-Path $ShortcutPath)) {
    Write-Host "Creating startup shortcut..."

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $PythonW
    $Shortcut.Arguments = "`"$InstallDir\auto_print_labels.py`""
    $Shortcut.WorkingDirectory = $InstallDir
    $Shortcut.Save()
}

Write-Host "✔ Auto Zebra installed / updated"