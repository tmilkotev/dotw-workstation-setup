# scripts/setup-check.ps1
# Existence-only verification. Prints PASS/FAIL with colors and exits non-zero on failures.
# Scales better as your stack grows.

param(
  [switch]$Strict  # if set, treat "optional" items as required
)

$ErrorActionPreference = "Stop"

function Pass([string]$msg) { Write-Host "[PASS] $msg" -ForegroundColor Green }
function Fail([string]$msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Warn([string]$msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Info([string]$msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }

function Has-Cmd([string]$name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Check-Cmd([string]$name, [string]$hint = "", [switch]$Optional) {
  if (Has-Cmd $name) {
    $src = (Get-Command $name).Source
    Pass "$name found ($src)"
    return $true
  }

  if ($Optional -and -not $Strict) {
    if ($hint) { Warn "$name missing (optional). $hint" } else { Warn "$name missing (optional)." }
    return $true
  }

  if ($hint) { Fail "$name missing. $hint" } else { Fail "$name missing." }
  return $false
}

function Run-Group([string]$Title, $Items, [ref]$Failures) {
  Info "`n=== $Title ==="
  foreach ($it in $Items) {
    $name = $it.Name
    $hint = $it.Hint
    $optional = [bool]$it.Optional

    $ok = Check-Cmd -name $name -hint $hint -Optional:($optional)
    if (-not $ok) { $Failures.Value++ }
  }
}

$failures = 0

# --- Define your stack here (easy to grow) ---
$core = @(
  @{ Name="git"  ; Hint="" ; Optional=$false }
  @{ Name="pwsh" ; Hint="" ; Optional=$false }
  @{ Name="code" ; Hint="" ; Optional=$false }
)

$editors_tools = @(
  @{ Name="notepad++" ; Hint="Notepad++ installs a GUI app; command may not exist. Consider skipping this check if it annoys you." ; Optional=$true }
)

$languages = @(
  @{ Name="python"; Hint="If Microsoft Store alias hijacks python: Settings > Apps > Advanced app settings > App execution aliases > disable python.exe/python3.exe" ; Optional=$false }
  @{ Name="pip"   ; Hint="" ; Optional=$false }
  @{ Name="node"  ; Hint="" ; Optional=$false }
  @{ Name="npm"   ; Hint="" ; Optional=$false }
  @{ Name="java"  ; Hint="" ; Optional=$false }
)

$infrastructure = @(
  @{ Name="terraform"; Hint="" ; Optional=$false }
  @{ Name="aws"      ; Hint="" ; Optional=$false }
  @{ Name="awsume"   ; Hint="If blocked by policy: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned" ; Optional=$false }
)

$virtualization = @(
  @{ Name="vagrant"   ; Hint="" ; Optional=$false }
  @{ Name="VBoxManage"; Hint="If installed but not on PATH: ensure C:\Program Files\Oracle\VirtualBox is in USER PATH" ; Optional=$false }
)

$containers = @(
  @{ Name="docker"; Hint="Docker Desktop may require first-run/sign-in/reboot; rerun after it finishes initialization." ; Optional=$true }
)

$network_security = @(
  @{ Name="wireshark"; Hint="Wireshark is a GUI app; command may not exist. If you want a CLI check, use 'tshark' instead." ; Optional=$true }
  @{ Name="tshark"   ; Hint="Installed with Wireshark; useful CLI validation." ; Optional=$true }
)

# --- Run checks ---
Run-Group "CORE"            $core            ([ref]$failures)
Run-Group "EDITORS/TOOLS"   $editors_tools   ([ref]$failures)
Run-Group "LANGUAGES"       $languages       ([ref]$failures)
Run-Group "INFRASTRUCTURE"  $infrastructure  ([ref]$failures)
Run-Group "VIRTUALIZATION"  $virtualization  ([ref]$failures)
Run-Group "CONTAINERS"      $containers      ([ref]$failures)
Run-Group "NETWORK/SECURITY"$network_security([ref]$failures)

Write-Host ""
if ($failures -eq 0) {
  Write-Host "=== GREEN LIGHT: all checks passed ===" -ForegroundColor Green
  exit 0
} else {
  Write-Host "=== RED LIGHT: failures = $failures ===" -ForegroundColor Red
  exit 1
}