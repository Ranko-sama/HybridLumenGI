$ErrorActionPreference='Stop'
$taskPackagePath=$PSScriptRoot
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskInstaller=Join-Path $taskPackagePath 'prepare.py'
$taskAttempt=Join-Path $taskPackagePath 'build-attempt.json'
$taskPlayerOutput='I:/Unity test/Comparison/Builds/LocalRelease71/HybridLumenGITest.exe'
$taskBuildName='LocalRelease71Build'
if(Test-Path -LiteralPath $taskAttempt){throw 'Existing build attempt must be preserved.'}
if(Test-Path -LiteralPath (Split-Path -Parent $taskPlayerOutput)){throw 'New build output must not replace an existing Player.'}
if(Get-Process -Name Unity -ErrorAction SilentlyContinue){throw 'Existing Unity process.'}
if((Get-Content -LiteralPath (Join-Path $taskPackagePath 'preflight/exit.json') -Raw | ConvertFrom-Json).exitCode -ne 0){throw 'Preflight failed.'}
$taskNativeExit=-1
try {
    & $taskPython -Xutf8 -B $taskInstaller install
    if($LASTEXITCODE -ne 0){throw 'Release wiring installation failed.'}
    @{attempt=1;sourceCommit=(git rev-parse HEAD);startedUtc=[DateTime]::UtcNow.ToString('o');output=$taskPlayerOutput} | ConvertTo-Json | Set-Content -LiteralPath $taskAttempt -Encoding utf8
    $taskReceipt=Join-Path $taskPackagePath 'build-report.json'
    & 'I:/Unity test/Start-Unity.ps1' -Batch -LogName $taskBuildName -ExecuteMethod 'CurrentPlayerBuild.Build' -ExtraArguments @('-currentPlayerConfiguration','Release','-currentPlayerOutput',$taskPlayerOutput,'-currentPlayerReceipt',$taskReceipt)
    $taskNativeExit=$LASTEXITCODE
} finally {
    @{exitCode=$taskNativeExit;completedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskPackagePath 'build-exit.json') -Encoding utf8
    foreach($taskLog in @(($taskBuildName+'.log'),($taskBuildName+'-upm.log'))){
        $taskSourceLog=Join-Path 'I:/Unity test/Logs' $taskLog
        if(Test-Path -LiteralPath $taskSourceLog){$taskLogName=if($taskLog -eq ($taskBuildName+'.log')){'build-unity.log'}else{'build-upm.log'};Copy-Item -LiteralPath $taskSourceLog -Destination (Join-Path $taskPackagePath $taskLogName)}
    }
    & $taskPython -Xutf8 -B $taskInstaller restore
    if($LASTEXITCODE -ne 0){throw 'Release wiring restoration failed.'}
}
if($taskNativeExit -eq 0){
    & $taskPython -Xutf8 -B $taskInstaller launcher
    if($LASTEXITCODE -ne 0){throw 'Launcher preparation failed.'}
}
exit $taskNativeExit
