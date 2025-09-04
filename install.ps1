<#
.SYNOPSIS
Installs or updates ps2exe-wrapper.exe to a user-local folder and adds it to PATH.
#>

param(
    [string]$InstallDir = "$env:LOCALAPPDATA\ps2exe-wrapper",
    [string]$RepoPS1Url = "https://raw.githubusercontent.com/ExcuseMi/ps2exe-wrapper/main/wrap-ps2exe.ps1"
)

# 1️⃣ Create folder if missing
if (-not (Test-Path $InstallDir)) { New-Item -Path $InstallDir -ItemType Directory | Out-Null }

# 2️⃣ Download or update wrap-ps2exe.ps1
$ps1File = Join-Path $InstallDir "wrap-ps2exe.ps1"
Write-Host "Downloading/updating wrap-ps2exe.ps1..."
Invoke-WebRequest -Uri $RepoPS1Url -OutFile $ps1File -UseBasicParsing


# 5️⃣ Build EXE
$exeFile = Join-Path $InstallDir "ps2exe-wrapper.exe"

Write-Host "Building ps2exe-wrapper.exe..."
& $ps1File -ScriptPath $ps1File -OutputFile $exeFile -Title "PS2EXE Wrapper" -Description "PS2EXE Wrapper" -Company "Excuse Mi" -Product "ps2exe-wrapper"
# 7️⃣ Add to PATH
$oldPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($oldPath -notmatch [regex]::Escape($InstallDir)) {
    setx PATH "$oldPath;$InstallDir" | Out-Null
    Write-Host "Added $InstallDir to user PATH. Restart terminal to apply."
}

Write-Host "Installation/update complete! EXE available at: $exeFile"
