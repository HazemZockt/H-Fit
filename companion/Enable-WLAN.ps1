$ErrorActionPreference = 'Stop'
try {
$configPath = Join-Path $PSScriptRoot '.local\server.json'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$python = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if (-not (Test-Path -LiteralPath $python)) { $python = (Get-Command python -ErrorAction Stop).Source }
$rule = Get-NetFirewallRule -DisplayName 'H-Fit KI im lokalen WLAN' -ErrorAction SilentlyContinue
if (-not $rule) {
    New-NetFirewallRule -DisplayName 'H-Fit KI im lokalen WLAN' -Direction Inbound -Action Allow -Protocol TCP -LocalAddress $config.host -LocalPort $config.port -RemoteAddress LocalSubnet -Profile Any -Program $python | Out-Null
}
'H-Fit WLAN-Freigabe eingerichtet.' | Set-Content -LiteralPath (Join-Path $PSScriptRoot '.local\firewall-status.txt')
} catch {
    $_.Exception.Message | Set-Content -LiteralPath (Join-Path $PSScriptRoot '.local\firewall-status.txt')
    exit 1
}
