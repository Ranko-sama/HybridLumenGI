$ErrorActionPreference='Stop'
$taskRootPath='C:/Users/Administrator/Desktop/test/HybridLumenGI'
$taskPackagePath=Join-Path $taskRootPath 'LocalComparison/Review/material-mpb-propagation-02'
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskInstaller=Join-Path $taskRootPath 'LocalComparison/Harness/prepare-material-event.py'
$taskAttempt=Join-Path $taskPackagePath 'build-attempt.json'
$taskPlayerOutput='I:/Unity test/Comparison/Builds/MaterialEvent25/HybridLumenGITest.exe'
if(Test-Path -LiteralPath $taskAttempt){throw 'Unique normal build already attempted.'}
if(Test-Path -LiteralPath (Split-Path -Parent $taskPlayerOutput)){throw 'New build output must not replace an existing Player.'}
if(Get-Process -Name Unity -ErrorAction SilentlyContinue){throw 'An existing Unity process must be handled before installation.'}
& $taskPython $taskInstaller install
if($LASTEXITCODE -ne 0){throw 'Player test wiring installation failed.'}
$taskNativeExit=-1
try {
    @{attempt=1;sourceCommit=(git rev-parse HEAD);startedUtc=[DateTime]::UtcNow.ToString('o');output=$taskPlayerOutput} | ConvertTo-Json | Set-Content -LiteralPath $taskAttempt -Encoding utf8
    $taskCommand="& 'I:/Unity test/Start-Unity.ps1' -Batch -LogName 'MaterialEvent25Build' -ExecuteMethod 'CurrentPlayerBuild.Build' -ExtraArguments @('-currentPlayerOutput','$taskPlayerOutput','-currentPlayerReceipt','$($taskPackagePath.Replace('\','/'))/build-report.json')"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $taskCommand
    $taskNativeExit=$LASTEXITCODE
} finally {
    @{exitCode=$taskNativeExit;completedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskPackagePath 'build-exit.json') -Encoding utf8
    foreach($taskLog in @('MaterialEvent25Build.log','MaterialEvent25Build-upm.log')){
        $taskSourceLog=Join-Path 'I:/Unity test/Logs' $taskLog
        if(Test-Path -LiteralPath $taskSourceLog){$taskLogName=if($taskLog -eq 'MaterialEvent25Build.log'){'build-unity.log'}else{'build-upm.log'};Copy-Item -LiteralPath $taskSourceLog -Destination (Join-Path $taskPackagePath $taskLogName)}
    }
    & $taskPython $taskInstaller restore
    if($LASTEXITCODE -ne 0){throw 'Player test wiring restoration failed.'}
}
exit $taskNativeExit
