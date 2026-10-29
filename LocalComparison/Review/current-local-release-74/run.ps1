$ErrorActionPreference='Stop'
$taskPackage=$PSScriptRoot
$taskPlayer='I:/Unity test/Comparison/Builds/LocalRelease74/HybridLumenGITest.exe'
$taskOutput='I:/Unity test/Comparison/LocalRelease74Verification'
if(!(Get-Content -LiteralPath (Join-Path $taskPackage 'build-analysis.json') -Raw | ConvertFrom-Json).passed){throw 'Build verification is required.'}
if(Test-Path -LiteralPath $taskOutput){throw 'Preserve existing Player evidence.'}
if(Get-Process -Name Unity,HybridLumenGITest -ErrorAction SilentlyContinue){throw 'Unity or Player is running.'}
$taskArgs=@('-batchmode','-force-d3d12','-screen-fullscreen','0','-screen-width','640','-screen-height','360','-unifiedSampleVerify','-unifiedSampleOutput',$taskOutput,'-logFile',(Join-Path $taskPackage 'unity.log'))
$taskAttempt=Join-Path $taskPackage 'run-attempt.json'
if(Test-Path -LiteralPath $taskAttempt){throw 'Preserve first Player attempt.'}
@{startedUtc=[DateTime]::UtcNow.ToString('o');executable=$taskPlayer;arguments=$taskArgs;userReportedGameExit=$true;performanceCompared=$false} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $taskAttempt -Encoding utf8
$taskInfo=New-Object System.Diagnostics.ProcessStartInfo
$taskInfo.FileName=$taskPlayer
$taskInfo.WorkingDirectory=Split-Path -Parent $taskPlayer
$taskInfo.UseShellExecute=$false
$taskInfo.WindowStyle=[System.Diagnostics.ProcessWindowStyle]::Hidden
$taskInfo.CreateNoWindow=$true
$taskInfo.Arguments=($taskArgs | ForEach-Object {'"'+$_+'"'}) -join ' '
$taskProcess=[System.Diagnostics.Process]::Start($taskInfo)
Write-Output "Unified Release74 verification PID $($taskProcess.Id)"
$taskTerminated=$false
if(!$taskProcess.WaitForExit(1800000)){
    $taskTerminated=$true
    Stop-Process -Id $taskProcess.Id -Force
    $taskProcess.WaitForExit()
}
@{processId=$taskProcess.Id;exitCode=$taskProcess.ExitCode;watchdogTerminated=$taskTerminated;completedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskPackage 'native-exit.json') -Encoding utf8
exit $taskProcess.ExitCode
