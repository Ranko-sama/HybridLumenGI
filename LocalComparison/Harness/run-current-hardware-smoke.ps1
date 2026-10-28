$ErrorActionPreference='Stop'
$taskRootPath='C:/Users/Administrator/Desktop/test/HybridLumenGI'
$taskPackagePath=Join-Path $taskRootPath 'LocalComparison/Review/current-player-dxr-smoke-01'
$taskModePath=Join-Path $taskPackagePath 'hardware-windowed'
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskPlayer='I:/Unity test/Comparison/Builds/CurrentShutdown20/HybridLumenGITest.exe'
if(Test-Path -LiteralPath (Join-Path $taskModePath 'attempt.json')){throw 'Hardware already used its unique attempt.'}
if(Get-Process -Name Unity,HybridLumenGITest -ErrorAction SilentlyContinue){throw 'Existing Unity/Player process must finish first.'}
& $taskPython (Join-Path $taskRootPath 'LocalComparison/Harness/current-hardware-smoke.py') prepare
if($LASTEXITCODE -ne 0){throw 'Same-build source/software/capability gate failed.'}
New-Item -ItemType Directory -Path $taskModePath -Force | Out-Null
$taskLog=Join-Path $taskModePath 'player.log'
$taskRun=Join-Path $taskModePath 'run'
$taskArgs=@('-force-d3d12','-screen-fullscreen','0','-screen-width','640','-screen-height','360',
    '-auditScene','functional','-auditSmoke','-auditFrames','120','-comparisonMode','hardware',
    '-auditDenoiseReadback','-auditOutput',$taskRun,'-logFile',$taskLog)
@{attempt=1;mode='hardware';executable=$taskPlayer;arguments=$taskArgs;startedUtc=[DateTime]::UtcNow.ToString('o');maximumLogicalFrames=120;watchdogSeconds=1200} |
    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $taskModePath 'attempt.json') -Encoding utf8
$taskInfo=New-Object System.Diagnostics.ProcessStartInfo
$taskInfo.FileName=$taskPlayer
$taskInfo.WorkingDirectory=Split-Path -Parent $taskPlayer
$taskInfo.UseShellExecute=$false
# Interactive rendered Player; the ordinary visible window is required for receipts.
$taskInfo.WindowStyle=[System.Diagnostics.ProcessWindowStyle]::Normal
$taskInfo.CreateNoWindow=$false
$taskInfo.Arguments=($taskArgs | ForEach-Object {'"'+$_+'"'}) -join ' '
$taskProcess=[System.Diagnostics.Process]::Start($taskInfo)
Write-Output "Player hardware PID $($taskProcess.Id); complete native log: $taskLog"
$taskTerminated=$false
if(!$taskProcess.WaitForExit(1200000)){$taskTerminated=$true;Stop-Process -Id $taskProcess.Id -Force;$taskProcess.WaitForExit()}
$taskNativeExit=$taskProcess.ExitCode
@{processId=$taskProcess.Id;exitCode=$taskNativeExit;watchdogTerminated=$taskTerminated;completedUtc=[DateTime]::UtcNow.ToString('o')} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskModePath 'native-exit.json') -Encoding utf8
Write-Output "Player hardware exited $taskNativeExit; watchdog=$taskTerminated"
exit $taskNativeExit
