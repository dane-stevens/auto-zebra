powershell
$ErrorActionPreference = "Stop"

Write-Host "== Auto Zebra install =="

# ---------------- CONFIG ----------------
$InstallDir   = "C:\auto-zebra"
$RepoRaw      = "https://raw.githubusercontent.com/dane-stevens/auto-zebra/main/src"
$StartupDir   = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$ShortcutPath = "$StartupDir\Auto Print Labels.lnk"

# ---------------- PYTHON ----------------
$PyCommand = Get-Command py -ErrorAction SilentlyContinue

if (-not $PyCommand) {
    Write-Host "Python launcher not found. Installing Python 3.13..."

    # Explicitly use the community repository, not Microsoft Store.
    & winget install --id Python.Python.3.13 --exact `
        --source winget `
        --accept-package-agreements `
        --accept-source-agreements

    if ($LASTEXITCODE -ne 0) {
        throw "Python installation failed. Check WinGet/network errors above."
    }

    # Refresh PATH for this PowerShell process.
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") +
        ";" +
        [Environment]::GetEnvironmentVariable("Path", "User")

    $PyCommand = Get-Command py -ErrorAction SilentlyContinue
}

if (-not $PyCommand) {
    throw "Python launcher is still unavailable. Reopen PowerShell and rerun."
}

# Resolve the launcher path for subsequent commands.
$PyExe = $PyCommand.Source
if (-not $PyExe) { $PyExe = $PyCommand.Path }

Write-Host "Using Python launcher: $PyExe"

& $PyExe -3 -c "import sys; print(sys.version)"
if ($LASTEXITCODE -ne 0) {
    throw "Python could not start."
}

# ---------------- PIP / WATCHDOG ----------------
Write-Host "Ensuring pip..."
& $PyExe -3 -m ensurepip --upgrade
if ($LASTEXITCODE -ne 0) {
    throw "ensurepip failed."
}

& $PyExe -3 -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) {
    throw "pip upgrade failed."
}

Write-Host "Installing/updating watchdog..."
& $PyExe -3 -m pip install --upgrade watchdog
if ($LASTEXITCODE -ne 0) {
    throw "watchdog installation failed."
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

if (-not (Test-Path "$InstallDir\config.json")) {
    Write-Host "Downloading config.json..."
    Invoke-WebRequest "$RepoRaw/config.json" `
        -OutFile "$InstallDir\config.json"
} else {
    Write-Host "Keeping existing config.json."
}

# ---------------- FIND PYTHONW ----------------
Write-Host "Locating pythonw.exe..."

$PythonExe = & $PyExe -3 -c "import sys; print(sys.executable)"
if ($LASTEXITCODE -ne 0 -or -not $PythonExe) {
    throw "Failed to locate python.exe."
}

$PythonExe = ($PythonExe | Select-Object -Last 1).Trim()

if (-not (Test-Path $PythonExe)) {
    throw "Python executable not found: $PythonExe"
}

$PythonDir = Split-Path $PythonExe
$PythonW   = Join-Path $PythonDir "pythonw.exe"

if (-not (Test-Path $PythonW)) {
    throw "pythonw.exe not found at $PythonW"
}

# ---------------- STARTUP SHORTCUT ----------------
New-Item -ItemType Directory -Force -Path $StartupDir | Out-Null

Write-Host "Creating/updating startup shortcut..."

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $PythonW
$Shortcut.Arguments = "`"$InstallDir\auto_print_labels.py`""
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Save()

Write-Host "Auto Zebra installed / updated successfully."
