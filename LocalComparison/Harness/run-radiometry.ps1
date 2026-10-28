$ErrorActionPreference='Stop'
$taskRootPath='C:/Users/Administrator/Desktop/test/HybridLumenGI'
$taskPackagePath=Join-Path $taskRootPath 'LocalComparison/Review/scene-radiometry-matched-baseline-01'
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskInstaller=Join-Path $taskRootPath 'LocalComparison/Harness/prepare-radiometry.py'
$taskAttempt=Join-Path $taskPackagePath 'native-attempt.json'
if(Test-Path -LiteralPath $taskAttempt){throw 'This finite package already used its only native attempt.'}
if(Get-Process -Name Unity -ErrorAction SilentlyContinue){throw 'An existing Unity process must be handled before installation.'}
& $taskPython $taskInstaller install
if($LASTEXITCODE -ne 0){throw 'Prospective installation failed.'}
$taskNativeExit=-1
try {
    @{nativeAttempt=1;maximumLogicalFrames=120;startedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $taskAttempt -Encoding utf8
    # Use a direct scriptblock invocation so the array remains an array for the existing launcher.
    $taskCommand="& 'I:/Unity test/Start-Unity.ps1' -Batch -KeepRunning -LogName 'CProspective01' -ExecuteMethod 'SceneRadiometryExport.Play' -ExtraArguments @('-sceneRadiometryProbe','-gatherCacheProbe','-radiometryScene','Assets/RadiometryBaseline/Static.unity','-comparisonOutput','$($taskPackagePath.Replace('\','/'))/run')"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $taskCommand
    $taskNativeExit=$LASTEXITCODE
} finally {
    @{exitCode=$taskNativeExit;completedUtc=[DateTime]::UtcNow.ToString('o');scope='single Unity process; original exceptional scratch remains open'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskPackagePath 'native-exit.json') -Encoding utf8
    foreach($taskLog in @('CProspective01.log','CProspective01-upm.log')){
        $taskSourceLog=Join-Path 'I:/Unity test/Logs' $taskLog
        if(Test-Path -LiteralPath $taskSourceLog){$taskLogName=if($taskLog -eq 'CProspective01.log'){'unity.log'}else{'upm.log'};Copy-Item -LiteralPath $taskSourceLog -Destination (Join-Path $taskPackagePath $taskLogName)}
    }
    & $taskPython $taskInstaller restore
    if($LASTEXITCODE -ne 0){throw 'Deployment restoration failed; inspect archived originals before continuing.'}
}
exit $taskNativeExit
