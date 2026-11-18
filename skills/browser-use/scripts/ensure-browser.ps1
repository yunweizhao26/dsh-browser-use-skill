<#
.SYNOPSIS
  Ensure one or more local Chrome instances that expose CDP with no consent prompt.

.DESCRIPTION
  Each instance gets its own non-default --user-data-dir and its own
  --remote-debugging-port, which is the "isolated profile, no popups" route:
  Chrome skips the chrome://inspect "Allow remote debugging?" dialog entirely.
  Logins made inside a profile persist for later runs.

  An instance is started only when its port is not already serving
  /json/version, so this is safe to call before every swarm.

.PARAMETER BasePort
  First port. Agent i uses BasePort + i.

.PARAMETER Count
  How many instances to ensure.

.PARAMETER Root
  Profile root; one subdirectory per port.

.EXAMPLE
  ./ensure-browser.ps1 -BasePort 9333 -Count 3
  # then agent i: $env:BU_CDP_URL = 'http://127.0.0.1:' + (9333 + i)
#>
param(
  [int]$BasePort = 9333,
  [int]$Count = 1,
  [string]$Root = (Join-Path $env:USERPROFILE '.browser-use')
)

$chrome = Join-Path ${env:ProgramFiles} 'Google\Chrome\Application\chrome.exe'
if (-not (Test-Path $chrome)) { Write-Error "Chrome not found at $chrome"; exit 1 }

function Test-Cdp([int]$port) {
  try {
    Invoke-WebRequest "http://127.0.0.1:$port/json/version" -TimeoutSec 2 -UseBasicParsing | Out-Null
    return $true
  } catch { return $false }
}

for ($i = 0; $i -lt $Count; $i++) {
  $port = $BasePort + $i
  if (Test-Cdp $port) { "port $port : already up"; continue }

  $profile = Join-Path $Root "profile-$port"
  New-Item -ItemType Directory -Force -Path $profile | Out-Null
  $proc = Start-Process $chrome -PassThru -ArgumentList @(
    "--user-data-dir=$profile",
    "--remote-debugging-port=$port",
    "--no-first-run",
    "--no-default-browser-check",
    "about:blank"
  )

  $ready = $false
  for ($n = 0; $n -lt 40; $n++) {
    Start-Sleep -Milliseconds 500
    if (Test-Cdp $port) { $ready = $true; break }
  }

  if ($ready) { "port $port : started (browser pid $($proc.Id), profile $profile)" }
  else { "port $port : FAILED to open CDP (browser pid $($proc.Id))" }
}
