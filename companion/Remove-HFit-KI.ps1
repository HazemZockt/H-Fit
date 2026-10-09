# Run as administrator only when you want to remove H-Fit's PC connection.
$ErrorActionPreference = 'Stop'
$companionRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$localRoot = [IO.Path]::GetFullPath((Join-Path $companionRoot '.local'))
if ($localRoot -ne ($companionRoot + '\.local')) { throw 'Unerwarteter Pfad; Abbruch.' }
$serverPath = Join-Path $companionRoot 'server.py'
$processes = Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^python(w)?\.exe$' -and $_.CommandLine -and $_.CommandLine.Contains($serverPath) }
foreach ($process in $processes) { Stop-Process -Id $process.ProcessId -ErrorAction SilentlyContinue }
Get-NetFirewallRule -DisplayName 'H-Fit KI im lokalen WLAN' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
if (Test-Path -LiteralPath $localRoot) { Remove-Item -LiteralPath $localRoot -Recurse -Force }
Write-Output 'H-Fit-Dienst, WLAN-Regel und private Kopplungsdaten entfernt. Auf dem iPhone zusätzlich PC trennen wählen. Ollama und Tagebuch bleiben erhalten.'
