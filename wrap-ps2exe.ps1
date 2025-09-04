<#
.SYNOPSIS
Wrap any PowerShell script or inline command into an EXE using PS2EXE with metadata, UAC, and code signing.

.PARAMETER ScriptPath
Path to the PS1 script to wrap (mutually exclusive with InlineCommand).

.PARAMETER InlineCommand
PowerShell command string to wrap (mutually exclusive with ScriptPath).

.PARAMETER OutputFile
Destination EXE filename (required).

.PARAMETER IconFile
Optional icon path.

.PARAMETER RequireAdmin
Switch to request administrator privileges via UAC.

.PARAMETER NoConsole
Switch to create a Windows Forms app without a console window.

.PARAMETER Title
Optional EXE title (defaults to script name).

.PARAMETER Description
Optional EXE description (defaults to "Wrapped <ScriptName> PowerShell script").

.PARAMETER Product
Optional product name (defaults to script name).

.PARAMETER Company
Optional company name (defaults to current Windows username).

.PARAMETER Version
Optional version string (defaults to "1.0.0.0").

.PARAMETER OtherArgs
Hashtable of additional PS2EXE parameters (x86/x64, STA/MTA, embedFiles, DPIAware, etc.).
#>

param(
    [Parameter(Mandatory=$false, ParameterSetName="Script")] 
    [string]$ScriptPath,

    [Parameter(Mandatory=$false, ParameterSetName="Inline")]
    [string]$InlineCommand,

    [Parameter(Mandatory=$true)]
    [string]$OutputFile,

    [string]$IconFile = "",
    [switch]$RequireAdmin,
    [switch]$NoConsole,

    [string]$Title,
    [string]$Description,
    [string]$Product,
    [string]$Company,
    [string]$Version = "1.0.0.0",

    [hashtable]$OtherArgs
)

# -----------------------------
# Validate input
# -----------------------------
if ($PSCmdlet.ParameterSetName -eq "Script" -and -not (Test-Path $ScriptPath)) {
    Write-Error "Script file not found: $ScriptPath"; exit 1
} elseif ($PSCmdlet.ParameterSetName -eq "Inline" -and -not $InlineCommand) {
    Write-Error "InlineCommand cannot be empty"; exit 1
}

$ScriptName = if ($PSCmdlet.ParameterSetName -eq "Script") { [IO.Path]::GetFileNameWithoutExtension($ScriptPath) } else { "InlineScript" }

if (-not [System.IO.Path]::IsPathRooted($OutputFile)) {
    $OutputFile = Join-Path -Path (Get-Location) -ChildPath $OutputFile
}
$OutputFile = [System.IO.Path]::GetFullPath($OutputFile)
$TargetDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $TargetDir)) { New-Item -Path $TargetDir -ItemType Directory | Out-Null }

# -----------------------------
# Defaults for metadata
# -----------------------------
$Username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[-1]
if (-not $Title) { $Title = $ScriptName }
if (-not $Description) { $Description = "Wrapped $ScriptName PowerShell script" }
if (-not $Product) { $Product = $ScriptName }
if (-not $Company) { $Company = $Username }
if (-not $Version) { $Version = "1.0.0.0" }
$CertName = "PS2EXE-$Company"

# -----------------------------
# Ensure ps2exe module installed
# -----------------------------
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "Installing ps2exe module..." -ForegroundColor Yellow
    Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
}

# -----------------------------
# Prepare inline command
# -----------------------------
if ($PSCmdlet.ParameterSetName -eq "Inline") {
    $TempScript = Join-Path $env:TEMP ("wrap-inline-" + [guid]::NewGuid().ToString() + ".ps1")
    $ScriptContent = $InlineCommand -split "`r?`n"
    Set-Content -Path $TempScript -Value $ScriptContent -Encoding UTF8
    Write-Host "Created temporary script for inline command: $TempScript" -ForegroundColor Cyan
    $ScriptPath = $TempScript
}

# -----------------------------
# Certificate handling
# -----------------------------
$UserCertDir = Join-Path $env:LOCALAPPDATA "PS2EXE-Certs"
if (-not (Test-Path $UserCertDir)) { New-Item -Path $UserCertDir -ItemType Directory | Out-Null }

$CertFile = Join-Path $UserCertDir "$CertName.pfx"
$CertPass = "changeme"
$secpasswd = ConvertTo-SecureString $CertPass -AsPlainText -Force

$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -eq "CN=$CertName" }
if (-not $cert) {
    if (-not (Test-Path $CertFile)) {
        Write-Host "Creating self-signed certificate ($CertName)..." -ForegroundColor Yellow
        $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=$CertName" `
            -KeyUsage DigitalSignature -CertStoreLocation Cert:\CurrentUser\My
        Export-PfxCertificate -Cert $cert -FilePath $CertFile -Password $secpasswd | Out-Null
    } else {
        Write-Host "Importing existing certificate PFX into store..." -ForegroundColor Yellow
        $cert = Import-PfxCertificate -FilePath $CertFile -CertStoreLocation Cert:\CurrentUser\My -Password $secpasswd
    }
} else {
    Write-Host "Using existing certificate in store." -ForegroundColor Green
}

# Install certificate in Trusted Root if missing
$rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root","CurrentUser"
$rootStore.Open("ReadWrite")
if (-not $rootStore.Certificates | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }) {
    Write-Host "Installing certificate in Trusted Root..." -ForegroundColor Yellow
    $rootStore.Add($cert)
} else {
    Write-Host "Certificate already installed in Trusted Root." -ForegroundColor Green
}
$rootStore.Close()

# -----------------------------
# PS2EXE parameters with defaults
# -----------------------------
$Ps2ExeParams = @{
    inputFile   = $ScriptPath
    outputFile  = $OutputFile
    requireAdmin = $RequireAdmin
    noConsole   = $NoConsole
    iconFile    = $IconFile
    title       = $Title
    description = $Description
    company     = $Company
    product     = $Product
    version     = $Version
}

if ($OtherArgs) { $Ps2ExeParams += $OtherArgs }

Write-Host "Building EXE: $OutputFile" -ForegroundColor Cyan
ps2exe.ps1 @Ps2ExeParams | Out-Null

# -----------------------------
# Cleanup temp script
# -----------------------------
if ($PSCmdlet.ParameterSetName -eq "Inline" -and (Test-Path $TempScript)) {
    Remove-Item $TempScript -Force
}

# -----------------------------
# Locate signtool.exe
# -----------------------------
$signtoolPaths = @(
    "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe",
    "C:\Program Files (x86)\Windows Kits\10\bin\*\x86\signtool.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\*\*\bin\signtool.exe"
)
$signtool = Get-ChildItem -Path $signtoolPaths -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $signtool) { $signtool = Get-Command "signtool.exe" -ErrorAction SilentlyContinue }

# -----------------------------
# Sign EXE
# -----------------------------
if ($signtool) {
    Write-Host "Signing EXE: $OutputFile" -ForegroundColor Yellow
    & $signtool.FullName sign /f $CertFile /p $CertPass /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 $OutputFile
    Write-Host "EXE signed successfully." -ForegroundColor Green
} else {
    Write-Host "Warning: signtool.exe not found. EXE built but not signed." -ForegroundColor Red
}

Write-Host "Build complete! EXE created at: $OutputFile" -ForegroundColor Green
