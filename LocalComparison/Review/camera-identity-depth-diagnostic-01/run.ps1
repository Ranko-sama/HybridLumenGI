$ErrorActionPreference='Stop'
$taskPackagePath=$PSScriptRoot
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskPrepare=Join-Path $taskPackagePath 'prepare.py'
$taskAttempt=Join-Path $taskPackagePath 'attempt.json'
$taskLogName='CameraIdentityDepthDiagnostic01'
if(Test-Path -LiteralPath $taskAttempt){throw 'Preserve the previous native diagnostic attempt.'}
if(Get-Process -Name Unity,HybridLumenGITest -ErrorAction SilentlyContinue){throw 'Unity or a test Player is already active.'}
if((Get-Content -LiteralPath (Join-Path $taskPackagePath 'preflight/exit.json') -Raw | ConvertFrom-Json).exitCode -ne 0){throw 'Managed preflight failed.'}
if(-not (Get-Content -LiteralPath (Join-Path $taskPackagePath 'compile-probe-03/report.json') -Raw | ConvertFrom-Json).passed){throw 'Diagnostic shader preflight failed.'}
$taskNativeExit=-1
try {
    & $taskPython -Xutf8 -B $taskPrepare install
    if($LASTEXITCODE -ne 0){throw 'Diagnostic staging failed.'}
    @{startedUtc=[DateTime]::UtcNow.ToString('o');sourceCommit=(git rev-parse HEAD);scope='One hidden DX12 Editor diagnostic; original 48-frame camera/TAA scene and path; identity fragment observations only on fixed frames36..43; no acceptance rerun or performance comparison'} | ConvertTo-Json | Set-Content -LiteralPath $taskAttempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -KeepRunning -LogName $taskLogName -ExecuteMethod 'CameraMotionTaaEditor.Run' -ExtraArguments @('-cameraMotionTaaOutput',(Join-Path $taskPackagePath 'native'))
    $taskNativeExit=$LASTEXITCODE
} finally {
    @{exitCode=$taskNativeExit;completedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskPackagePath 'native-exit.json') -Encoding utf8
    foreach($taskSuffix in @('.log','-upm.log')){
        $taskSource=Join-Path 'I:/Unity test/Logs' ($taskLogName+$taskSuffix)
        if(Test-Path -LiteralPath $taskSource){Copy-Item -LiteralPath $taskSource -Destination (Join-Path $taskPackagePath ('unity'+$taskSuffix))}
    }
    & $taskPython -Xutf8 -B $taskPrepare restore
    if($LASTEXITCODE -ne 0){throw 'Diagnostic restoration failed.'}
}
exit $taskNativeExit
