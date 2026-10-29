$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$ownedRoot = [IO.Path]::GetFullPath("$project/Assets/SkinnedUnifiedUsageRetry01")
$output = 'I:/Unity test/Comparison/SkinnedUnifiedUsageRetry01'
$qualityPath = "$project/ProjectSettings/QualitySettings.asset"
$auditPath = "$project/Assets/ComparisonHarness/RuntimeAuditEntry.cs"
$attempt = Join-Path $PSScriptRoot 'retry-attempt.json'
if ((Test-Path -LiteralPath $attempt) -or (Test-Path -LiteralPath $ownedRoot) -or
    (Test-Path -LiteralPath "$ownedRoot.meta") -or (Test-Path -LiteralPath $output)) { throw 'Preserve existing attempt and inputs.' }
if (Get-Process Unity,HybridLumenGIPlayer -ErrorAction SilentlyContinue) { throw 'An existing rendering process is active.' }
$qualityBytes = [IO.File]::ReadAllBytes($qualityPath)
$auditBytes = [IO.File]::ReadAllBytes($auditPath)
$backup = Join-Path $env:TEMP ('hlgi-skin-usage-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
[IO.File]::WriteAllBytes((Join-Path $backup 'QualitySettings.asset'), $qualityBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'RuntimeAuditEntry.cs'), $auditBytes)
$exitCode = $null
try {
    [IO.Directory]::CreateDirectory("$ownedRoot/Editor") | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'SkinnedSampleUsage.cs') -Destination "$ownedRoot/SkinnedSampleUsage.cs"
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'SkinnedSampleUsageEditor.cs') -Destination "$ownedRoot/Editor/SkinnedSampleUsageEditor.cs"
    Copy-Item -LiteralPath 'I:/Unity test/Comparison/Release74BuildArchive/Assets/ComparisonHarness/RuntimeAuditEntry.cs' -Destination $auditPath
    [ordered]@{ startedUtc=[DateTime]::UtcNow.ToString('o'); output=$output; backup=$backup;
        source='89be36a plus sample interaction and two-bone skin helper';
        sequence='Readable mesh -> real Skinned motion -> stopped snapshot/source match -> return to mesh -> close/restore';
        bounds='Finish as soon as the necessary states complete; at most600 requests or600 seconds after driver Start.';
        scope='One saved ordinary scene; at most one stopped Final picture; no hashes, radiometric reference, dynamic-quality or performance acceptance.'
    } | ConvertTo-Json | Set-Content -LiteralPath $attempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -KeepRunning -LogName 'SkinnedUnifiedUsageRetry01' `
        -ExecuteMethod 'SkinnedSampleUsageEditor.Run' -ExtraArguments @('-skinUsageOutput',$output)
    $exitCode = $LASTEXITCODE
    [ordered]@{ exitCode=$exitCode; endedUtc=[DateTime]::UtcNow.ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'retry-native-exit.json') -Encoding utf8
}
finally {
    if (Get-Process Unity -ErrorAction SilentlyContinue) { throw "Unity still owns the temporary input; preserve backup $backup." }
    [IO.File]::WriteAllBytes($qualityPath,$qualityBytes)
    [IO.File]::WriteAllBytes($auditPath,$auditBytes)
    if (Test-Path -LiteralPath $ownedRoot) {
        $resolved = (Resolve-Path -LiteralPath $ownedRoot).Path
        $expected = [IO.Path]::GetFullPath('I:/Unity test/Project/Assets/SkinnedUnifiedUsageRetry01')
        if (-not $resolved.Equals($expected,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup target.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    if (Test-Path -LiteralPath "$ownedRoot.meta") { Remove-Item -LiteralPath "$ownedRoot.meta" }
    Write-Output "Restored quality and initializer; removed only temporary usage scripts. Backup: $backup"
}
if ($null -ne $exitCode) { exit $exitCode }
