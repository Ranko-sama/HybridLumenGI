$ErrorActionPreference='Stop'
$taskPackagePath=$PSScriptRoot
$taskRunPath=Join-Path $taskPackagePath 'native-explicit'
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskPlayer='I:/Unity test/Comparison/Builds/LocalRelease73/HybridLumenGITest.exe'
if(!(Get-Content -LiteralPath (Join-Path $taskPackagePath 'build-analysis.json') -Raw | ConvertFrom-Json).currentSourceBuildVerified){throw 'Build not accepted.'}
if(!(Get-Content -LiteralPath (Join-Path $taskPackagePath 'analysis67-build.json') -Raw | ConvertFrom-Json).passed){throw 'Cube build inputs not accepted.'}
if(Test-Path -LiteralPath (Join-Path $taskRunPath 'attempt.json')){throw 'Existing Player attempt must be preserved.'}
& $taskPython -Xutf8 -B (Join-Path $taskPackagePath 'prepare.py') products
if($LASTEXITCODE -ne 0){throw 'Player products changed.'}
New-Item -ItemType Directory -Path $taskRunPath -Force | Out-Null
$taskArgs=@('-batchmode','-force-d3d12','-screen-fullscreen','0','-screen-width','640','-screen-height','360','-localReleaseFinalImage120','-localReleaseExplicitRequest','-localReleaseOutput',(Join-Path $taskRunPath 'run'),'-logFile',(Join-Path $taskRunPath 'player.log'))
@{attempt=1;executable=$taskPlayer;arguments=$taskArgs;startedUtc=[DateTime]::UtcNow.ToString('o');maximumLogicalFrames=120;watchdogSeconds=1200} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $taskRunPath 'attempt.json') -Encoding utf8
$taskInfo=New-Object System.Diagnostics.ProcessStartInfo
$taskInfo.FileName=$taskPlayer
$taskInfo.WorkingDirectory=Split-Path -Parent $taskPlayer
$taskInfo.UseShellExecute=$false
$taskInfo.WindowStyle=[System.Diagnostics.ProcessWindowStyle]::Hidden
$taskInfo.CreateNoWindow=$true
$taskInfo.Arguments=($taskArgs | ForEach-Object {'"'+$_+'"'}) -join ' '
$taskProcess=[System.Diagnostics.Process]::Start($taskInfo)
Write-Output "Release73 Player PID $($taskProcess.Id)"
$taskTerminated=$false
if(!$taskProcess.WaitForExit(1200000)){
    $taskTerminated=$true
    Stop-Process -Id $taskProcess.Id -Force
    $taskProcess.WaitForExit()
}
$taskNativeExit=$taskProcess.ExitCode
@{processId=$taskProcess.Id;exitCode=$taskNativeExit;watchdogTerminated=$taskTerminated;completedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRunPath 'native-exit.json') -Encoding utf8
Write-Output "Release73 Player exited $taskNativeExit; watchdog=$taskTerminated"
exit $taskNativeExit
