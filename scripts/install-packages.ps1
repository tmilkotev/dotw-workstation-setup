# scripts/install-packages.ps1
# Installs winget packages from packages\packages-winget.json

param(
  [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
  [string[]]$Profiles = @()  # optional override; if empty uses defaultProfile from JSON
)

$ErrorActionPreference = "Stop"

function Assert-Winget {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is not available. Install 'App Installer' from Microsoft Store or ensure winget is installed."
  }
}

function Read-PackagesConfig([string]$Path) {
  if (-not (Test-Path $Path)) { throw "Missing packages config: $Path" }
  return Get-Content $Path -Raw | ConvertFrom-Json
}

function Resolve-Packages($cfg, [string[]]$profiles) {
  $selectedProfiles = $profiles
  if ($selectedProfiles.Count -eq 0) {
    $selectedProfiles = @($cfg.defaultProfile)
  }

  $pkgs = New-Object System.Collections.Generic.List[string]
  foreach ($p in $selectedProfiles) {
    if (-not $cfg.profiles.$p) { throw "Unknown profile '$p' in packages config." }
    foreach ($id in $cfg.profiles.$p) { $pkgs.Add([string]$id) }
  }

  # unique while preserving order
  $seen = @{}
  $unique = @()
  foreach ($id in $pkgs) {
    if (-not $seen.ContainsKey($id)) { $seen[$id] = $true; $unique += $id }
  }
  return $unique
}

Assert-Winget

$configPath = Join-Path $RepoRoot "packages\packages-winget.json"
$cfg = Read-PackagesConfig $configPath
$packageIds = Resolve-Packages $cfg $Profiles

Write-Host "Installing packages (profiles: $($Profiles -join ', '))" -ForegroundColor Cyan
Write-Host "Count: $($packageIds.Count)" -ForegroundColor Cyan

foreach ($id in $packageIds) {
  Write-Host "-> $id"
  winget install --id $id --silent --accept-package-agreements --accept-source-agreements
}

Write-Host "Package installation complete." -ForegroundColor Green