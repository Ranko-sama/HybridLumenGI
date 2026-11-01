$ErrorActionPreference = 'Stop'
$build = 'I:/Unity test/Comparison/Builds/LocalRelease100StreamingSustained30m01'
$output = 'I:/Unity test/Comparison/StreamingSustained30m01'
$log = 'I:/Unity test/Comparison/StreamingSustained30m01-player.log'
$attempt = Join-Path $PSScriptRoot 'player-attempt.json'
$exe = Join-Path $build 'HybridLumenGIPlayer.exe'
$report = Get-Content -Raw -LiteralPath (Join-Path $build 'build-result.json') | ConvertFrom-Json
if ($report.status -ne 'Succeeded' -or $report.actualOptions -ne 'None' -or $report.errors -ne 0) { throw 'Expected successful ordinary measurement build.' }
if ((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath $log) -or (Test-Path -LiteralPath $attempt)) { throw 'Preserve the existing run.' }
if (Get-Process Unity,HybridLumenGIPlayer -ErrorAction SilentlyContinue) { throw 'Another Unity workload is running.' }
$arguments = @('-force-d3d12','-screen-fullscreen','0','-screen-width','960','-screen-height','540','-hlgiStreamingSoak',('"'+$output+'"'),'-logFile',('"'+$log+'"'))
$p = Start-Process -FilePath $exe -WorkingDirectory $build -ArgumentList $arguments -WindowStyle Hidden -PassThru
[ordered]@{startedUtc=[DateTime]::UtcNow.ToString('o');pid=$p.Id;output=$output;log=$log} | ConvertTo-Json | Set-Content -LiteralPath $attempt -Encoding utf8
Write-Output "Player PID $($p.Id), stream endpoints: $output/endpoints.jsonl"
# Includes the cold first render, initial readiness allowance and ordinary shutdown.
$timedOut = -not $p.WaitForExit(2400000)
if ($timedOut) { $p.Kill(); $p.WaitForExit() }
[ordered]@{endedUtc=[DateTime]::UtcNow.ToString('o');exitCode=$p.ExitCode;watchdogTerminated=$timedOut} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'player-exit.json') -Encoding utf8
if ($timedOut) { throw '40-minute process watchdog expired.' }
exit $p.ExitCode
