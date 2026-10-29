$ErrorActionPreference='Stop'
$taskPackagePath=$PSScriptRoot
$taskRunPath=Join-Path $taskPackagePath 'native-window'
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskPlayer='I:/Unity test/Comparison/Builds/LocalRelease69/HybridLumenGITest.exe'
if(!(Get-Content -LiteralPath (Join-Path $taskPackagePath 'build-analysis.json') -Raw | ConvertFrom-Json).currentSourceBuildVerified){throw 'Build not accepted.'}
if(!(Get-Content -LiteralPath (Join-Path $taskPackagePath 'analysis69-build.json') -Raw | ConvertFrom-Json).passed){throw 'Cube build inputs not accepted.'}
if(Test-Path -LiteralPath (Join-Path $taskRunPath 'attempt.json')){throw 'Unique Player attempt already exists.'}
& $taskPython -Xutf8 -B (Join-Path $taskPackagePath 'analyze69.py') products
if($LASTEXITCODE -ne 0){throw 'Player products changed.'}
New-Item -ItemType Directory -Path $taskRunPath -Force | Out-Null
$taskArgs=@('-force-d3d12','-screen-fullscreen','0','-screen-width','640','-screen-height','360','-localContinuousDeformation256','-localReleaseOutput',(Join-Path $taskRunPath 'run'),'-logFile',(Join-Path $taskRunPath 'player.log'))
@{attempt=1;executable=$taskPlayer;arguments=$taskArgs;startedUtc=[DateTime]::UtcNow.ToString('o');maximumLogicalFrames=256;watchdogSeconds=1200} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $taskRunPath 'attempt.json') -Encoding utf8
$taskInfo=New-Object System.Diagnostics.ProcessStartInfo
$taskInfo.FileName=$taskPlayer;$taskInfo.WorkingDirectory=Split-Path -Parent $taskPlayer;$taskInfo.UseShellExecute=$false
# Explicitly authorized visible rendered Player; not a background helper.
$taskInfo.WindowStyle=[System.Diagnostics.ProcessWindowStyle]::Normal;$taskInfo.CreateNoWindow=$false
$taskInfo.Arguments=($taskArgs | ForEach-Object {'"'+$_+'"'}) -join ' '
$taskProcess=[System.Diagnostics.Process]::Start($taskInfo)
Write-Output "Release69 Player PID $($taskProcess.Id)"
$taskTerminated=$false
if(!$taskProcess.WaitForExit(1200000)){$taskTerminated=$true;Stop-Process -Id $taskProcess.Id -Force;$taskProcess.WaitForExit()}
$taskNativeExit=$taskProcess.ExitCode
@{processId=$taskProcess.Id;exitCode=$taskNativeExit;watchdogTerminated=$taskTerminated;completedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRunPath 'native-exit.json') -Encoding utf8
Write-Output "Release69 Player exited $taskNativeExit; watchdog=$taskTerminated"
exit $taskNativeExit
