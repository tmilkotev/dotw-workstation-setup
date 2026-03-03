# workstation-setup

Automated bootstrap for a clean Windows 11 development workstation.

## Run

Open PowerShell (Admin recommended for installs):

    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    .\bootstrap.ps1

## If python opens Microsoft Store

Windows 11 sometimes hijacks python via App Execution Aliases.

Fix:

Settings → Apps → Advanced app settings → App execution aliases

Turn OFF:

- python.exe
- python3.exe

Close PowerShell, open a new one, then verify:

    python --version
    pip --version
