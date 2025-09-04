# PS2EXE Wrapper

**PS2EXE Wrapper** is a PowerShell utility that allows you to wrap any PowerShell script or inline command into a standalone Windows executable (EXE) with metadata, optional UAC (administrator) elevation, and code signing. It automatically manages dependencies like `ps2exe` and `signtool`, and can generate or reuse a self-signed certificate.

---

## Installation / Update

You can install or update the wrapper with a single command:

```powershell
iwr https://raw.githubusercontent.com/ExcuseMi/ps2exe-wrapper/refs/heads/main/install.ps1 -UseBasicParsing | iex
```

This will:

- Download or update `wrap-ps2exe.ps1` to `%LOCALAPPDATA%\ps2exe-wrapper\`
- Build a standalone `ps2exe-wrapper.exe`
- Add it to your user PATH so you can run it from any terminal
- Automatically handle code signing with a self-signed certificate

After installation, restart your terminal to ensure the PATH is updated.

---

## Basic Usage

### Wrap a PS1 Script

```powershell
ps2exe-wrapper.exe -ScriptPath .\myscript.ps1 -OutputFile .\myscript.exe
```

### Wrap an Inline Command

```powershell
ps2exe-wrapper.exe -InlineCommand 'Write-Host "Hello world!"' -OutputFile .\hello.exe
```

### Optional Parameters

- `-IconFile <path>` – Set a custom icon for the EXE.
- `-RequireAdmin` – Request administrator privileges via UAC.
- `-Title <string>` – Title metadata embedded in the EXE.
- `-Description <string>` – Description metadata embedded in the EXE.
- `-Company <string>` – Company metadata embedded in the EXE.
- `-Product <string>` – Product metadata embedded in the EXE.
- `-Version <string>` – Version metadata embedded in the EXE (default: `1.0.0.0`).
- `-NoConsole` – Generate a Windows Forms EXE without a console.
- `-OtherArgs <hashtable>` – Pass any additional PS2EXE parameters (x86/x64, STA/MTA, embedFiles, DPIAware, supportOS, longPaths, etc.).

---

## Examples

**Wrap a script with custom metadata and icon:**

```powershell
ps2exe-wrapper.exe -ScriptPath .\winutil.ps1 `
                   -OutputFile .\winutil.exe `
                   -IconFile .\winutil.ico `
                   -RequireAdmin `
                   -Title "Winutil Wrapper" `
                   -Description "Wraps Chris Titus Tech Winutil script" `
                   -Company "ExcuseMi" `
                   -Product "Winutil Wrapper" `
                   -Version "1.2.0.0"
```

**Wrap a one-liner inline command as a GUI EXE:**

```powershell
ps2exe-wrapper.exe -InlineCommand 'irm "https://christitus.com/win" | iex' `
                   -OutputFile .\winutil.exe `
                   -NoConsole
```

**Wrap a multi-line inline command:**

```powershell
ps2exe-wrapper.exe -InlineCommand @'
Write-Host "Starting..."
$service = Get-Service -Name wuauserv
if ($service.Status -ne 'Running') {
    Start-Service -Name wuauserv
}
Write-Host "Service started."
'@ `
-OutputFile .\winutil-multiline.exe
```

**Pass additional PS2EXE options via `-OtherArgs`:**

```powershell
ps2exe-wrapper.exe -ScriptPath .\myscript.ps1 `
                   -OutputFile .\myscript.exe `
                   -OtherArgs @{ x64 = $true; STA = $true; embedFiles = @{"data.txt"="data.txt"} }
```

---

## Notes

- The wrapper automatically creates or reuses a self-signed certificate stored in `%LOCALAPPDATA%\PS2EXE-Certs`.
- EXEs built with a self-signed certificate will show **“Unknown Publisher”** on new machines — this is normal and safe for development/testing.
- Only certificates issued by a trusted Certificate Authority (CA) will show a verified publisher in Windows.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

