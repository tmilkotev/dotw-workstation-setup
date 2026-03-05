# scripts/post-install.ps1
# Post-install steps that winget doesn't fully complete:
# - Initialize WSL distro (AlmaLinux-10)
# - Install Python packages (awsume)
# - Fix PowerShell ExecutionPolicy for pip script shims
# - Optional: start Docker Desktop to trigger first-run setup
# - Ensure VirtualBox CLI is available in PATH (User scope)

param(
  [switch]$StartDocker
)

$ErrorActionPreference = "Stop"

function Write-Info($m){ Write-Host "[INFO] $m" }
function Write-Warn($m){ Write-Host "[WARN] $m" }

function Get-WSLDistros {
  if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) { return @() }
  $out = (& wsl --list --quiet 2>$null)
  if (-not $out) { return @() }
  @($out | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# --- WSL: install AlmaLinux-10 (idempotent) ---
$targetDistro = "AlmaLinux-10"

if (Get-Command wsl -ErrorAction SilentlyContinue) {
  Write-Info "Ensuring WSL distro exists: $targetDistro"
  $existing = Get-WSLDistros

  if ($existing -contains $targetDistro) {
    Write-Info "WSL distro already present: $targetDistro"
  } else {
    try {
      & wsl --install -d $targetDistro
      Write-Info "WSL install/init triggered for $targetDistro (may require reboot / first-launch setup)."
    } catch {
      Write-Warn "WSL install/init failed. Error: $($_.Exception.Message)"
    }
  }

  # Refresh list after possible install trigger
  $existing = Get-WSLDistros
} else {
  Write-Warn "wsl command not found. Skipping WSL."
}

# --- AWSume: pip install ---
Write-Info "Checking Python..."
try {
  $pyv = & python --version 2>&1
  Write-Info "Python OK: $pyv"

  Write-Info "Upgrading pip..."
  & python -m pip install --upgrade pip

  Write-Info "Installing/Upgrading awsume..."
  & python -m pip install --upgrade awsume

  Write-Info "awsume installed successfully."
} catch {
  Write-Warn "Python not usable from PATH. awsume install skipped."
}

# --- Fix ExecutionPolicy for pip-installed PowerShell shims ---
try {
  $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
  if ($currentPolicy -ne "RemoteSigned") {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Write-Info "Set ExecutionPolicy CurrentUser=RemoteSigned"
  } else {
    Write-Info "ExecutionPolicy already RemoteSigned"
  }
} catch {
  Write-Warn "Could not set ExecutionPolicy: $($_.Exception.Message)"
}

# --- Docker Desktop: optional first-run ---
if ($StartDocker) {
  $dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
  if (Test-Path $dockerExe) {
    Write-Info "Starting Docker Desktop for first-run initialization..."
    Start-Process $dockerExe | Out-Null
  } else {
    Write-Warn "Docker Desktop executable not found. Skipping."
  }
} else {
  Write-Info "Docker Desktop first-run not requested. Skipping."
}

# --- Ensure VirtualBox PATH (User scope; no admin required) ---
$vbPath = "C:\Program Files\Oracle\VirtualBox"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($userPath -notlike "*$vbPath*") {
  try {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$vbPath", "User")
    Write-Info "Added VirtualBox to USER PATH."
  } catch {
    Write-Warn "Failed to set USER PATH: $($_.Exception.Message)"
  }
} else {
  Write-Info "VirtualBox already in USER PATH."
}

Write-Info "Post-install complete."