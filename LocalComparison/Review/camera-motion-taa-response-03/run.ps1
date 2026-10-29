$ErrorActionPreference='Stop'
$taskPackagePath=$PSScriptRoot
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskPrepare=Join-Path $taskPackagePath 'prepare.py'
$taskAttempt=Join-Path $taskPackagePath 'attempt.json'
$taskLogName='CameraMotionTaaResponse03'
if(Test-Path -LiteralPath $taskAttempt){throw 'Preserve previous native attempt.'}
if(Get-Process -Name Unity,HybridLumenGITest -ErrorAction SilentlyContinue){throw 'Unity is already active.'}
if((Get-Content -LiteralPath (Join-Path $taskPackagePath 'preflight/exit.json') -Raw | ConvertFrom-Json).exitCode -ne 0){throw 'Managed preflight failed.'}
if((Get-Content -LiteralPath (Join-Path $taskPackagePath 'identity-shaders.json') -Raw | ConvertFrom-Json).status -ne 'passed'){throw 'Identity shader preflight failed.'}
$taskNativeExit=-1
try {
    & $taskPython -Xutf8 -B $taskPrepare install
    if($LASTEXITCODE -ne 0){throw 'Observer staging failed.'}
    @{startedUtc=[DateTime]::UtcNow.ToString('o');sourceCommit=(git rev-parse HEAD);scope='Hidden DX12 Editor Play; 48 explicit renders, static sources, camera translation8 plus actual URP TAA; compact identity/motion observations'} | ConvertTo-Json | Set-Content -LiteralPath $taskAttempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -KeepRunning -LogName $taskLogName -ExecuteMethod 'CameraMotionTaaEditor.Run' -ExtraArguments @('-cameraMotionTaaOutput',(Join-Path $taskPackagePath 'native'))
    $taskNativeExit=$LASTEXITCODE
} finally {
    @{exitCode=$taskNativeExit;completedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskPackagePath 'native-exit.json') -Encoding utf8
    foreach($taskSuffix in @('.log','-upm.log')){
        $taskSource=Join-Path 'I:/Unity test/Logs' ($taskLogName+$taskSuffix)
        if(Test-Path -LiteralPath $taskSource){Copy-Item -LiteralPath $taskSource -Destination (Join-Path $taskPackagePath ('unity'+$taskSuffix))}
    }
    & $taskPython -Xutf8 -B $taskPrepare restore
    if($LASTEXITCODE -ne 0){throw 'Observer restoration failed.'}
}
exit $taskNativeExit

