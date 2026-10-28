param([switch]$SteadyUse,[switch]$Integration,[switch]$FinalImage)
$ErrorActionPreference='Stop'
if(([int]$SteadyUse.IsPresent+[int]$Integration.IsPresent+[int]$FinalImage.IsPresent) -gt 1){throw 'Select one Release destination.'}
$taskRootPath='C:/Users/Administrator/Desktop/test/HybridLumenGI'
$taskPackagePath=Join-Path $taskRootPath 'LocalComparison/Review/local-release-baseline-01'
$taskRunPath=Join-Path $taskPackagePath 'native-window'
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskPlayer='I:/Unity test/Comparison/Builds/LocalRelease40/HybridLumenGITest.exe'
$taskAnalyzer='LocalComparison/Harness/analyze-local-release.py';$taskMode='-localReleaseVerify120'
$taskAnalyzerArgs=@()
if($SteadyUse){
    $taskPackagePath=Join-Path $taskRootPath 'LocalComparison/Review/local-release-steady-use-01'
    $taskRunPath=Join-Path $taskPackagePath 'native-window'
    $taskPlayer='I:/Unity test/Comparison/Builds/LocalRelease44/HybridLumenGITest.exe'
    $taskAnalyzer='LocalComparison/Harness/analyze-release-steady.py';$taskMode='-localReleaseSteady300'
}
if($Integration){
    $taskPackagePath=Join-Path $taskRootPath 'LocalComparison/Review/current-release-integration-01'
    $taskRunPath=Join-Path $taskPackagePath 'native-window'
    $taskPlayer='I:/Unity test/Comparison/Builds/LocalRelease49/HybridLumenGITest.exe'
    $taskAnalyzerArgs=@('--integration')
}
if($FinalImage){
    $taskPackagePath=Join-Path $taskRootPath 'LocalComparison/Review/current-representative-final-image-01'
    $taskRunPath=Join-Path $taskPackagePath 'native-window'
    $taskPlayer='I:/Unity test/Comparison/Builds/LocalRelease54/HybridLumenGITest.exe'
    $taskMode='-localReleaseFinalImage120';$taskAnalyzerArgs=@('--final-image')
}
if(!(Get-Content -LiteralPath (Join-Path $taskPackagePath 'build-analysis.json') -Raw | ConvertFrom-Json).currentSourceBuildVerified){throw 'Build not accepted.'}
if(Test-Path -LiteralPath (Join-Path $taskRunPath 'attempt.json')){throw 'The unique local Release Player attempt already exists.'}
& $taskPython (Join-Path $taskRootPath $taskAnalyzer) products @taskAnalyzerArgs
if($LASTEXITCODE -ne 0){throw 'Player products changed.'}
New-Item -ItemType Directory -Path $taskRunPath -Force | Out-Null
$taskArgs=@('-force-d3d12','-screen-fullscreen','0','-screen-width','640','-screen-height','360',
    $taskMode,'-localReleaseOutput',(Join-Path $taskRunPath 'run'),'-logFile',(Join-Path $taskRunPath 'player.log'))
@{attempt=1;executable=$taskPlayer;arguments=$taskArgs;startedUtc=[DateTime]::UtcNow.ToString('o');maximumLogicalFrames=$(if($SteadyUse){0}else{120});fixedSeconds=$(if($SteadyUse){300}else{0});initializationSeconds=$(if($SteadyUse){60}else{0});watchdogSeconds=1200} |
    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $taskRunPath 'attempt.json') -Encoding utf8
$taskInfo=New-Object System.Diagnostics.ProcessStartInfo
$taskInfo.FileName=$taskPlayer;$taskInfo.WorkingDirectory=Split-Path -Parent $taskPlayer;$taskInfo.UseShellExecute=$false
# This user-authorized rendered Player is an interactive application, not a background helper.
$taskInfo.WindowStyle=[System.Diagnostics.ProcessWindowStyle]::Normal;$taskInfo.CreateNoWindow=$false
$taskInfo.Arguments=($taskArgs | ForEach-Object {'"'+$_+'"'}) -join ' '
$taskProcess=[System.Diagnostics.Process]::Start($taskInfo)
Write-Output "Local Release Player PID $($taskProcess.Id)"
$taskTerminated=$false
if(!$taskProcess.WaitForExit(1200000)){$taskTerminated=$true;Stop-Process -Id $taskProcess.Id -Force;$taskProcess.WaitForExit()}
$taskNativeExit=$taskProcess.ExitCode
@{processId=$taskProcess.Id;exitCode=$taskNativeExit;watchdogTerminated=$taskTerminated;completedUtc=[DateTime]::UtcNow.ToString('o')} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRunPath 'native-exit.json') -Encoding utf8
Write-Output "Local Release Player exited $taskNativeExit; watchdog=$taskTerminated"
exit $taskNativeExit
