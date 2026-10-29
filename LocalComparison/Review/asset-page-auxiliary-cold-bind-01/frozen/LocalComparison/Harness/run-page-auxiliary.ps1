$ErrorActionPreference='Stop'
$taskPackagePath='C:/Users/Administrator/Desktop/test/HybridLumenGI/LocalComparison/Review/asset-page-auxiliary-cold-bind-01'
$taskRunPath=Join-Path $taskPackagePath 'native-window'
$taskPlayer='I:/Unity test/Comparison/Builds/AuxiliaryColdBind60/HybridLumenGITest.exe'
if(!(Get-Content -LiteralPath (Join-Path $taskPackagePath 'build-qualified.json') -Raw | ConvertFrom-Json).currentSourceBuildVerified){throw 'Build not accepted.'}
if(Test-Path -LiteralPath $taskRunPath){throw 'The single native attempt already exists.'}
New-Item -ItemType Directory -Path $taskRunPath | Out-Null
$taskArgs=@('-force-d3d12','-screen-fullscreen','0','-screen-width','640','-screen-height','360','-auxiliaryColdBind',
    '-auditOutput',(Join-Path $taskRunPath 'run'),'-logFile',(Join-Path $taskRunPath 'player.log'))
@{attempt=1;executable=$taskPlayer;arguments=$taskArgs;maximumCameraFrames=120;watchdogSeconds=1200;startedUtc=[DateTime]::UtcNow.ToString('o')} |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $taskRunPath 'attempt.json') -Encoding utf8
$taskInfo=New-Object System.Diagnostics.ProcessStartInfo
$taskInfo.FileName=$taskPlayer;$taskInfo.WorkingDirectory=Split-Path -Parent $taskPlayer;$taskInfo.UseShellExecute=$false
$taskInfo.WindowStyle=[System.Diagnostics.ProcessWindowStyle]::Normal;$taskInfo.CreateNoWindow=$false
$taskInfo.Arguments=($taskArgs | ForEach-Object {'"'+$_+'"'}) -join ' '
$taskProcess=[System.Diagnostics.Process]::Start($taskInfo)
Write-Output "Auxiliary cold-bind Player PID $($taskProcess.Id)"
$taskTerminated=$false
if(!$taskProcess.WaitForExit(1200000)){$taskTerminated=$true;Stop-Process -Id $taskProcess.Id -Force;$taskProcess.WaitForExit()}
$taskNativeExit=$taskProcess.ExitCode
@{processId=$taskProcess.Id;exitCode=$taskNativeExit;watchdogTerminated=$taskTerminated;completedUtc=[DateTime]::UtcNow.ToString('o')} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRunPath 'native-exit.json') -Encoding utf8
Write-Output "Auxiliary cold-bind Player exited $taskNativeExit; watchdog=$taskTerminated"
exit $taskNativeExit
