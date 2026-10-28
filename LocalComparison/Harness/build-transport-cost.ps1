param([ValidateSet('locator','candidate')][string]$Side='locator')
$ErrorActionPreference='Stop'
$taskRootPath='C:/Users/Administrator/Desktop/test/HybridLumenGI'
$taskPackagePath=Join-Path $taskRootPath "LocalComparison/Review/transport-hotspot-and-reuse-01/$Side"
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskInstaller=Join-Path $taskRootPath 'LocalComparison/Harness/prepare-transport-cost.py'
$taskAttempt=Join-Path $taskPackagePath 'build-attempt.json'
$taskPlayerOutput="I:/Unity test/Comparison/Builds/TransportCost23-$Side/HybridLumenGITest.exe"
if(Test-Path -LiteralPath $taskAttempt){throw 'This side already used its unique build.'}
if(Test-Path -LiteralPath (Split-Path -Parent $taskPlayerOutput)){throw 'Output must be new.'}
if(Get-Process -Name Unity,HybridLumenGITest -ErrorAction SilentlyContinue){throw 'Existing Unity/Player process must finish first.'}
& $taskPython $taskInstaller install --side $Side
if($LASTEXITCODE -ne 0){throw 'Temporary transport wiring installation failed.'}
$taskNativeExit=-1
try {
    @{attempt=1;sourceCommit=(git rev-parse HEAD);startedUtc=[DateTime]::UtcNow.ToString('o');output=$taskPlayerOutput} | ConvertTo-Json | Set-Content -LiteralPath $taskAttempt -Encoding utf8
    $taskCommand="& 'I:/Unity test/Start-Unity.ps1' -Batch -LogName 'TransportCost23-$Side' -ExecuteMethod 'GpuCostPlayerBuild.Build' -ExtraArguments @('-currentPlayerOutput','$taskPlayerOutput','-currentPlayerReceipt','$($taskPackagePath.Replace('\','/'))/build-report.json')"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $taskCommand
    $taskNativeExit=$LASTEXITCODE
} finally {
    @{exitCode=$taskNativeExit;completedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskPackagePath 'build-exit.json') -Encoding utf8
    foreach($taskSuffix in @('.log','-upm.log')){
        $taskSourceLog=Join-Path 'I:/Unity test/Logs' "TransportCost23-$Side$taskSuffix"
        if(Test-Path -LiteralPath $taskSourceLog){$taskLogName=if($taskSuffix -eq '.log'){'build-unity.log'}else{'build-upm.log'};Copy-Item -LiteralPath $taskSourceLog -Destination (Join-Path $taskPackagePath $taskLogName)}
    }
    & $taskPython $taskInstaller restore --side $Side
    if($LASTEXITCODE -ne 0){throw 'Temporary transport wiring restoration failed.'}
}
exit $taskNativeExit
