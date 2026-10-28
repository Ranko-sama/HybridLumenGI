$ErrorActionPreference='Stop'
$taskRoot='C:/Users/Administrator/Desktop/test/HybridLumenGI'
$taskPackage=Join-Path $taskRoot 'LocalComparison/Review/skinned-native-capture-boundary-01'
$taskNative=Join-Path $taskPackage 'native-editor'
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskPrepare=Join-Path $taskPackage 'prepare.py'
if(Test-Path -LiteralPath $taskNative){throw 'The one native Editor attempt already exists.'}
if(Get-Process -Name Unity -ErrorAction SilentlyContinue){throw 'An existing Editor must be handled first.'}
if((Get-Content -LiteralPath (Join-Path $taskPackage 'preflight/exit.json') -Raw|ConvertFrom-Json).exitCode -ne 0){throw 'Managed preflight failed.'}
& $taskPython $taskPrepare install
if($LASTEXITCODE -ne 0){throw 'Editor-only staging failed.'}
$taskExit=-1
try {
    New-Item -ItemType Directory -Path $taskNative | Out-Null
    @{attempt=1;editorProcesses=1;plannedCaptures=3;startedUtc=[DateTime]::UtcNow.ToString('o');workspaceHead=(git rev-parse HEAD);runtimeDeployment='5120a8c';executeMethod='SkinnedNativeCaptureBoundary.Run'} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskNative 'attempt.json') -Encoding utf8
    $taskOutput=(Join-Path $taskNative 'run').Replace('\','/')
    $taskCommand="& 'I:/Unity test/Start-Unity.ps1' -Batch -LogName 'SkinnedNative46' -ExecuteMethod 'SkinnedNativeCaptureBoundary.Run' -ExtraArguments @('-skinnedNativeOutput','$taskOutput')"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $taskCommand
    $taskExit=$LASTEXITCODE
} finally {
    @{exitCode=$taskExit;completedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskNative 'exit.json') -Encoding utf8
    foreach($taskLog in @('SkinnedNative46.log','SkinnedNative46-upm.log')){
        $taskSource=Join-Path 'I:/Unity test/Logs' $taskLog
        if(Test-Path -LiteralPath $taskSource){$taskName=if($taskLog -eq 'SkinnedNative46.log'){'unity.log'}else{'upm.log'};Copy-Item -LiteralPath $taskSource -Destination (Join-Path $taskNative $taskName)}
    }
    & $taskPython $taskPrepare restore
    if($LASTEXITCODE -ne 0){throw 'Editor-only source restoration failed.'}
}
exit $taskExit
