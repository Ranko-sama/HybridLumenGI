$ErrorActionPreference='Stop'
$taskRootPath='C:/Users/Administrator/Desktop/test/HybridLumenGI'
$taskPackagePath=Join-Path $taskRootPath 'LocalComparison/Review/material-mpb-propagation-01'
$taskRunPath=Join-Path $taskPackagePath 'native-window'
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskPlayer='I:/Unity test/Comparison/Builds/MaterialEvent24/HybridLumenGITest.exe'
if(!(Get-Content -LiteralPath (Join-Path $taskPackagePath 'build-analysis.json') -Raw | ConvertFrom-Json).currentSourceBuildVerified){throw 'Build not accepted.'}
if(Test-Path -LiteralPath (Join-Path $taskRunPath 'attempt.json')){throw 'The unique material-event Player attempt already exists.'}
& $taskPython (Join-Path $taskRootPath 'LocalComparison/Harness/analyze-material-event.py') products
if($LASTEXITCODE -ne 0){throw 'Player products changed.'}
New-Item -ItemType Directory -Path $taskRunPath -Force | Out-Null
$taskArgs=@('-force-d3d12','-screen-fullscreen','0','-screen-width','640','-screen-height','360',
    '-auditScene','functional','-materialEvent','-comparisonMode','hardware','-auditOutput',(Join-Path $taskRunPath 'run'),'-logFile',(Join-Path $taskRunPath 'player.log'))
@{attempt=1;executable=$taskPlayer;arguments=$taskArgs;startedUtc=[DateTime]::UtcNow.ToString('o');maximumLogicalFrames=256;watchdogSeconds=1200} |
    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $taskRunPath 'attempt.json') -Encoding utf8
$taskInfo=New-Object System.Diagnostics.ProcessStartInfo
$taskInfo.FileName=$taskPlayer;$taskInfo.WorkingDirectory=Split-Path -Parent $taskPlayer;$taskInfo.UseShellExecute=$false
# This user-authorized rendered Player is an interactive application, not a background helper.
$taskInfo.WindowStyle=[System.Diagnostics.ProcessWindowStyle]::Normal;$taskInfo.CreateNoWindow=$false
$taskInfo.Arguments=($taskArgs | ForEach-Object {'"'+$_+'"'}) -join ' '
$taskProcess=[System.Diagnostics.Process]::Start($taskInfo)
Write-Output "Material event Player PID $($taskProcess.Id)"
$taskTerminated=$false
if(!$taskProcess.WaitForExit(1200000)){$taskTerminated=$true;Stop-Process -Id $taskProcess.Id -Force;$taskProcess.WaitForExit()}
$taskNativeExit=$taskProcess.ExitCode
@{processId=$taskProcess.Id;exitCode=$taskNativeExit;watchdogTerminated=$taskTerminated;completedUtc=[DateTime]::UtcNow.ToString('o')} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRunPath 'native-exit.json') -Encoding utf8
Write-Output "Material event Player exited $taskNativeExit; watchdog=$taskTerminated"
exit $taskNativeExit
