$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$output = 'I:/Unity test/Comparison/Builds/LocalRelease78'
$qualityPath = "$project/ProjectSettings/QualitySettings.asset"
$auditPath = "$project/Assets/ComparisonHarness/RuntimeAuditEntry.cs"
$attempt = Join-Path $PSScriptRoot 'build-attempt.json'
if ((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath $attempt)) {
    throw 'Preserve existing build output and attempt.'
}
if (Get-Process Unity,HybridLumenGIPlayer -ErrorAction SilentlyContinue) {
    throw 'An existing rendering process is active.'
}
$qualityBytes = [IO.File]::ReadAllBytes($qualityPath)
$auditBytes = [IO.File]::ReadAllBytes($auditPath)
$backup = Join-Path $env:TEMP ('hlgi-source-cache-build-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
[IO.File]::WriteAllBytes((Join-Path $backup 'QualitySettings.asset'), $qualityBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'RuntimeAuditEntry.cs'), $auditBytes)
$nativeExit = $null
try {
    $qualityText = [Text.Encoding]::UTF8.GetString($qualityBytes)
    $oldPipeline = 'c4904ab5031e93c4a8f8e6ca539e4152'
    $samplePipeline = 'ca5b7ea101c75f645851495aea1b326c'
    if (-not $qualityText.Contains($oldPipeline)) { throw 'Expected original PC pipeline setting is missing.' }
    $qualityText = $qualityText.Replace($oldPipeline, $samplePipeline)
    [IO.File]::WriteAllText($qualityPath, $qualityText, [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath 'I:/Unity test/Comparison/Release74BuildArchive/Assets/ComparisonHarness/RuntimeAuditEntry.cs' -Destination $auditPath
    [ordered]@{
        startedUtc = [DateTime]::UtcNow.ToString('o')
        source = '3e41f69 plus adopted four-file source-separated cache change'
        scene = 'Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity'
        output = $output
        scope = 'One public Release/None build of the existing ordinary sample; no new scene, observer, hash, Player run or performance test.'
        backup = $backup
    } | ConvertTo-Json | Set-Content -LiteralPath $attempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -LogName 'LocalRelease78Build' `
        -ExecuteMethod 'HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build' `
        -ExtraArguments @('-buildTarget', 'StandaloneWindows64', '-hlgiScene', 'Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity', '-hlgiOutput', $output)
    $nativeExit = $LASTEXITCODE
    [ordered]@{ exitCode = $nativeExit; endedUtc = [DateTime]::UtcNow.ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'build-exit.json') -Encoding utf8
}
finally {
    if (Get-Process Unity -ErrorAction SilentlyContinue) { throw "Unity still owns the project. Preserve backup at $backup until it exits." }
    [IO.File]::WriteAllBytes($qualityPath, $qualityBytes)
    [IO.File]::WriteAllBytes($auditPath, $auditBytes)
    Write-Output "Restored quality settings and existing initializer. Backup: $backup"
}
if ($null -ne $nativeExit) { exit $nativeExit }
