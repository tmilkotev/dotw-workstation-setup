# setup.ps1
# Main entry point: install → post-install → verify (with logging)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Allow script execution for this session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Ensure logs folder
$logsDir = Join-Path $repoRoot "logs"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

# Log files
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logsDir "setup-$ts.log"
$latestLog = Join-Path $logsDir "latest.log"

# Start transcript (captures everything written to host)
Start-Transcript -Path $logFile -Append | Out-Null

function Write-Stage($msg) {
  Write-Host ""
  Write-Host $msg -ForegroundColor Cyan
}

Write-Host "=== workstation-setup: START ===" -ForegroundColor Cyan
Write-Host "Log: $logFile"

try {
  Write-Stage "--- Installing packages ---"
  & (Join-Path $repoRoot "scripts\install-packages.ps1") -RepoRoot $repoRoot

  Write-Stage "--- Running post-install ---"
  & (Join-Path $repoRoot "scripts\post-install.ps1")

  Write-Stage "--- Running setup checks ---"
  & (Join-Path $repoRoot "scripts\setup-check.ps1")

  Write-Host ""
  Write-Host "=== workstation-setup: COMPLETE ===" -ForegroundColor Green
}
catch {
  Write-Host ""
  Write-Host "=== workstation-setup: FAILED ===" -ForegroundColor Red
  Write-Host $_ | Format-List * -Force
  $script:SetupFailed = $true
}
finally {
  Stop-Transcript | Out-Null
  Copy-Item -Force $logFile $latestLog

  if ($script:SetupFailed) {
    Write-Host "Log saved to: $logFile" -ForegroundColor Yellow
    exit 1
  } else {
    Write-Host "Log saved to: $logFile" -ForegroundColor Green
    exit 0
  }
}