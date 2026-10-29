$ErrorActionPreference = 'Stop'
$taskPackage = $PSScriptRoot
$taskPython = 'C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskStage = Join-Path $taskPackage 'native_stage.py'
$taskOutput = 'I:/Unity test/Comparison/ValidationPackageV205'
$taskAttempt = Join-Path $taskPackage 'attempt.json'
$taskLogName = 'ValidationPackageV205'
if (Test-Path -LiteralPath $taskAttempt) { throw 'Preserve the first native attempt.' }
if (Get-Process -Name Unity,HybridLumenGITest -ErrorAction SilentlyContinue) { throw 'Unity or Player is already active.' }
$taskNativeExit = -1
$taskInstalled = $false
try {
    & $taskPython -Xutf8 -B $taskStage install
    if ($LASTEXITCODE -ne 0) { throw 'Validation driver staging failed.' }
    $taskInstalled = $true
    @{startedUtc=[DateTime]::UtcNow.ToString('o'); sourceCommit=(git rev-parse HEAD); sourceFreezeSha256=(Get-FileHash -LiteralPath (Join-Path $taskPackage 'source-freeze.json') -Algorithm SHA256).Hash.ToLowerInvariant(); nativeOutput=$taskOutput; userGaming=$true; performanceComparisonAllowed=$false} | ConvertTo-Json | Set-Content -LiteralPath $taskAttempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -KeepRunning -LogName $taskLogName -ExecuteMethod 'ValidationPackageV2Editor.Run' -ExtraArguments @('-validationPackageOutput',$taskOutput)
    $taskNativeExit = $LASTEXITCODE
} finally {
    if ($taskInstalled) {
        @{exitCode=$taskNativeExit; completedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskPackage 'native-exit.json') -Encoding utf8
        foreach ($taskSuffix in @('.log','-upm.log')) {
            $taskSource = Join-Path 'I:/Unity test/Logs' ($taskLogName + $taskSuffix)
            if (Test-Path -LiteralPath $taskSource) { Copy-Item -LiteralPath $taskSource -Destination (Join-Path $taskPackage ('unity' + $taskSuffix)) }
        }
        & $taskPython -Xutf8 -B $taskStage restore
        if ($LASTEXITCODE -ne 0) { throw 'Validation driver restoration failed.' }
    }
}
exit $taskNativeExit
