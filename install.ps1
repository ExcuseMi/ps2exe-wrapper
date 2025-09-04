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

# 3️⃣ Ensure ps2exe module
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "Installing ps2exe module..."
    Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
}

# 4️⃣ Certificate handling
$Username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[-1]
$CertName = "PS2EXE-$Username"
$CertFile = Join-Path $InstallDir "$CertName.pfx"
$CertPass = "changeme"
$secpasswd = ConvertTo-SecureString $CertPass -AsPlainText -Force

$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -eq "CN=$CertName" }
if (-not $cert) {
    Write-Host "Creating self-signed certificate..."
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=$CertName" `
        -KeyUsage DigitalSignature -CertStoreLocation Cert:\CurrentUser\My
    Export-PfxCertificate -Cert $cert -FilePath $CertFile -Password $secpasswd | Out-Null
} else { Write-Host "Using existing certificate in store." }

# Install in Trusted Root
$rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root","CurrentUser"
$rootStore.Open("ReadWrite")
if (-not $rootStore.Certificates | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }) {
    $rootStore.Add($cert)
}
$rootStore.Close()

# 5️⃣ Build EXE
$exeFile = Join-Path $InstallDir "ps2exe-wrapper.exe"
$Ps2ExeParams = @{
    inputFile   = $ps1File
    outputFile  = $exeFile
    title       = "PS2EXE Wrapper"
    description = "Standalone EXE for wrap-ps2exe.ps1"
    company     = $Username
    product     = "ps2exe-wrapper"
    copyright   = "Copyright (c) $(Get-Date -Format yyyy) $Username"
    requireAdmin = $true
}

Write-Host "Building ps2exe-wrapper.exe..."
ps2exe.ps1 @Ps2ExeParams | Out-Null

# 6️⃣ Sign EXE
$signtoolPaths = @(
    "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe",
    "C:\Program Files (x86)\Windows Kits\10\bin\*\x86\signtool.exe"
)
$signtool = Get-ChildItem -Path $signtoolPaths -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $signtool) { $signtool = Get-Command "signtool.exe" -ErrorAction SilentlyContinue }

if ($signtool) {
    Write-Host "Signing EXE..."
    & $signtool.FullName sign /f $CertFile /p $CertPass /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 $exeFile
    Write-Host "EXE signed successfully."
} else {
    Write-Host "Warning: signtool.exe not found. EXE built but not signed."
}

# 7️⃣ Add to PATH
$oldPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($oldPath -notmatch [regex]::Escape($InstallDir)) {
    setx PATH "$oldPath;$InstallDir" | Out-Null
    Write-Host "Added $InstallDir to user PATH. Restart terminal to apply."
}

Write-Host "Installation/update complete! EXE available at: $exeFile"
