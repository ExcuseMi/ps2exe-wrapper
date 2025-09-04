<#
.SYNOPSIS
Installs or updates ps2exe-wrapper.exe to a user-local folder and adds it to PATH.
#>

param(
    [string]$InstallDir = "$env:LOCALAPPDATA\ps2exe-wrapper",
    [string]$RepoPS1Url = "https://raw.githubusercontent.com/ExcuseMi/ps2exe-wrapper/refs/heads/main/wrap-ps2exe.ps1"
)

# -----------------------------
# Create main install folder if missing
# -----------------------------
if (-not (Test-Path $InstallDir)) { New-Item -Path $InstallDir -ItemType Directory | Out-Null }

# -----------------------------
# Download or update wrap-ps2exe.ps1
# -----------------------------
$ps1File = Join-Path $InstallDir "wrap-ps2exe.ps1"
Write-Host "Downloading/updating wrap-ps2exe.ps1..."
Invoke-WebRequest -Uri $RepoPS1Url -OutFile $ps1File -UseBasicParsing

# -----------------------------
# Create bin folder for EXE
# -----------------------------
$BinDir = Join-Path $InstallDir "bin"
if (-not (Test-Path $BinDir)) { New-Item -Path $BinDir -ItemType Directory | Out-Null }

# -----------------------------
# Build EXE
# -----------------------------
$exeFile = Join-Path $BinDir "ps2exe-wrapper.exe"
Write-Host "Building ps2exe-wrapper.exe..."
& $ps1File -ScriptPath $ps1File -OutputFile $exeFile -Title "PS2EXE Wrapper" -Description "PS2EXE Wrapper" -Company "Excuse Mi" -Product "ps2exe-wrapper"

# -----------------------------
# Add bin folder to user PATH
# -----------------------------
$oldPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($oldPath -notmatch [regex]::Escape($BinDir)) {
    setx PATH "$oldPath;$BinDir" | Out-Null
    Write-Host "Added $BinDir to user PATH. Restart terminal to apply."
}

Write-Host "Installation/update complete! EXE available at: $exeFile"
