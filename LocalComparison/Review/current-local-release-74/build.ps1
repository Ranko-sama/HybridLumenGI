$ErrorActionPreference='Stop'
$taskPackage=$PSScriptRoot
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskPrepare=Join-Path $taskPackage 'prepare.py'
$taskAttempt=Join-Path $taskPackage 'build-attempt.json'
if(Test-Path -LiteralPath $taskAttempt){throw 'Preserve the existing build attempt.'}
if(Get-Process -Name Unity,HybridLumenGITest -ErrorAction SilentlyContinue){throw 'Unity or Player already running.'}
$taskExit=-1
try {
    & $taskPython -Xutf8 -B $taskPrepare install
    if($LASTEXITCODE -ne 0){throw 'Build staging failed.'}
    @{startedUtc=[DateTime]::UtcNow.ToString('o');sourceManifestSha256=(Get-FileHash -LiteralPath (Join-Path $taskPackage 'instrumentation/manifest.json')).Hash.ToLowerInvariant();userReportedGameExit=$true;performanceCompared=$false} | ConvertTo-Json | Set-Content -LiteralPath $taskAttempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -LogName 'LocalRelease74Build' -ExecuteMethod 'UnifiedSampleReleaseBuild.Build' -ExtraArguments @('-currentPlayerOutput','I:/Unity test/Comparison/Builds/LocalRelease74/HybridLumenGITest.exe','-currentPlayerReceipt',(Join-Path $taskPackage 'build-report.json'))
    $taskExit=$LASTEXITCODE
} finally {
    @{exitCode=$taskExit;completedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskPackage 'build-exit.json') -Encoding utf8
    foreach($taskName in @('LocalRelease74Build.log','LocalRelease74Build-upm.log')) {
        $taskLog=Join-Path 'I:/Unity test/Logs' $taskName
        if(Test-Path -LiteralPath $taskLog){Copy-Item -LiteralPath $taskLog -Destination (Join-Path $taskPackage $taskName)}
    }
    if(Test-Path -LiteralPath (Join-Path $taskPackage 'instrumentation/installed.json')) {
        & $taskPython -Xutf8 -B $taskPrepare restore
        if($LASTEXITCODE -ne 0){throw 'Build source restoration failed.'}
    }
}
exit $taskExit
