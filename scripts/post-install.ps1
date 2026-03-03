# scripts/post-install.ps1
# Post-install steps that winget doesn't fully complete:
# - Initialize WSL distro (AlmaLinux-10)
# - Install Ansible inside WSL (AlmaLinux-10) when available
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

function Test-WSLDistroRunnable([string]$DistroName) {
  try {
    # If this works, the distro is initialized enough to execute commands.
    & wsl -d $DistroName -e sh -lc "echo ok" 2>$null | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Invoke-WSL([string]$DistroName, [string]$Command) {
  # Use sh for maximum compatibility.
  & wsl -d $DistroName -e sh -lc $Command
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

  # --- WSL: install Ansible inside AlmaLinux-10 (dnf) ---
  if ($existing -contains $targetDistro) {
    if (Test-WSLDistroRunnable $targetDistro) {
      Write-Info "Installing/Upgrading Ansible inside WSL distro: $targetDistro"

      # AlmaLinux uses dnf. ansible-core is commonly available; fall back to ansible if needed.
      try {
        Invoke-WSL $targetDistro "set -e; sudo dnf -y makecache; (sudo dnf -y install ansible-core || sudo dnf -y install ansible); ansible --version || ansible-playbook --version || true"
        Write-Info "Ansible install step completed inside $targetDistro."
      } catch {
        Write-Warn "Ansible install inside WSL failed (distro may still need first-launch setup or sudo password). Error: $($_.Exception.Message)"
      }
    } else {
      Write-Warn "WSL distro '$targetDistro' exists but isn't runnable yet (likely first-launch setup / reboot pending). Skipping Ansible for now."
      Write-Warn "After first launch of '$targetDistro', re-run this script to install Ansible."
    }
  } else {
    Write-Warn "WSL distro '$targetDistro' not present. Skipping Ansible-in-WSL."
  }

} else {
  Write-Warn "wsl command not found. Skipping WSL + Ansible."
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