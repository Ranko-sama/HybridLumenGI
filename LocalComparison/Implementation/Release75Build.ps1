$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$saved = 'I:/Unity test/Comparison/Release74BuildArchive/Assets'
$output = 'I:/Unity test/Comparison/Builds/LocalRelease75'
if (Test-Path -LiteralPath $output) { throw 'Preserve the existing Player output.' }
if (Get-Process Unity -ErrorAction SilentlyContinue) { throw 'Close the existing Unity process before this build.' }

# Reuse the saved ordinary scene, pipeline and pages. Keep these in the project
# for subsequent interactive use; no regeneration or source/archive hash pass.
foreach ($relative in @('UnifiedRelease74', 'StreamingAssets/UnifiedRelease74')) {
    $destination = Join-Path "$project/Assets" $relative
    if ((Test-Path -LiteralPath $destination) -or (Test-Path -LiteralPath "$destination.meta")) {
        throw "Preserve existing sample assets: $destination"
    }
}
foreach ($relative in @('UnifiedRelease74', 'StreamingAssets/UnifiedRelease74')) {
    $destination = Join-Path "$project/Assets" $relative
    Copy-Item -LiteralPath (Join-Path $saved $relative) -Destination $destination -Recurse
    Copy-Item -LiteralPath (Join-Path $saved "$relative.meta") -Destination "$destination.meta"
}

$qualityPath = "$project/ProjectSettings/QualitySettings.asset"
$auditPath = "$project/Assets/ComparisonHarness/RuntimeAuditEntry.cs"
$qualityBytes = [IO.File]::ReadAllBytes($qualityPath)
$auditBytes = [IO.File]::ReadAllBytes($auditPath)
$backup = Join-Path $env:TEMP ('hlgi-release75-settings-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
[IO.File]::WriteAllBytes((Join-Path $backup 'QualitySettings.asset'), $qualityBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'RuntimeAuditEntry.cs'), $auditBytes)
try {
    # Same PC quality level and saved pipeline used by Release74.
    $quality = [Text.Encoding]::UTF8.GetString($qualityBytes)
    $old = 'customRenderPipeline: {fileID: 11400000, guid: c4904ab5031e93c4a8f8e6ca539e4152, type: 2}'
    if (-not $quality.Contains($old)) { throw 'Expected original PC pipeline is absent.' }
    $quality = $quality.Replace($old, 'customRenderPipeline: {fileID: 11400000, guid: ca5b7ea101c75f645851495aea1b326c, type: 2}')
    [IO.File]::WriteAllText($qualityPath, $quality, [Text.UTF8Encoding]::new($false))
    # The local audit initializer is project-owned. Reuse the existing ordinary
    # sample guard, without changing the public build entry or product runtime.
    Copy-Item -LiteralPath "$saved/ComparisonHarness/RuntimeAuditEntry.cs" -Destination $auditPath
    & 'I:/Unity test/Start-Unity.ps1' -Batch -LogName 'Release75PublicBuild' `
        -ExecuteMethod 'HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build' `
        -ExtraArguments @('-buildTarget', 'StandaloneWindows64',
            '-hlgiScene', 'Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity',
            '-hlgiOutput', $output)
    if ($LASTEXITCODE -ne 0) { throw "Unity build exited $LASTEXITCODE. Preserve partial output and logs." }
}
finally {
    [IO.File]::WriteAllBytes($qualityPath, $qualityBytes)
    [IO.File]::WriteAllBytes($auditPath, $auditBytes)
    Write-Output "Restored project quality and audit initializer. Backup: $backup"
}
