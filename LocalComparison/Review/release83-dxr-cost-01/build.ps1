param(
    [string]$Output = 'I:/Unity test/Comparison/Builds/LocalRelease83DxrCost01',
    [string]$LogName = 'LocalRelease83DxrCost01Build'
)
$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$output = [IO.Path]::GetFullPath($Output)
$observer = "$project/Assets/ComparisonHarness/UnifiedSampleGpuCost.cs"
$observerSource = Join-Path $PSScriptRoot 'UnifiedSampleGpuCost.cs'
if ((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath $observer) -or (Test-Path -LiteralPath "$observer.meta")) {
    throw 'Preserve existing output or observer source.'
}
if (Get-Process Unity -ErrorAction SilentlyContinue) { throw 'An existing Unity process owns the project.' }
if (-not (Test-Path -LiteralPath $observerSource)) { throw 'Measurement observer is not ready.' }
$qualityPath = "$project/ProjectSettings/QualitySettings.asset"
$auditPath = "$project/Assets/ComparisonHarness/RuntimeAuditEntry.cs"
$qualityBytes = [IO.File]::ReadAllBytes($qualityPath)
$auditBytes = [IO.File]::ReadAllBytes($auditPath)
$backup = Join-Path $env:TEMP ('hlgi-release83-dxr-cost-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
[IO.File]::WriteAllBytes((Join-Path $backup 'QualitySettings.asset'), $qualityBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'RuntimeAuditEntry.cs'), $auditBytes)
try {
    Copy-Item -LiteralPath $observerSource -Destination $observer
    $quality = [Text.Encoding]::UTF8.GetString($qualityBytes)
    $old = 'customRenderPipeline: {fileID: 11400000, guid: c4904ab5031e93c4a8f8e6ca539e4152, type: 2}'
    if (-not $quality.Contains($old)) { throw 'Expected original PC pipeline is absent.' }
    $quality = $quality.Replace($old, 'customRenderPipeline: {fileID: 11400000, guid: ca5b7ea101c75f645851495aea1b326c, type: 2}')
    [IO.File]::WriteAllText($qualityPath, $quality, [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath 'I:/Unity test/Comparison/Release74BuildArchive/Assets/ComparisonHarness/RuntimeAuditEntry.cs' -Destination $auditPath
    & 'I:/Unity test/Start-Unity.ps1' -Batch -LogName $LogName `
        -ExecuteMethod 'HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build' `
        -ExtraArguments @('-buildTarget', 'StandaloneWindows64',
            '-hlgiScene', 'Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity',
            '-hlgiOutput', $output)
    if ($LASTEXITCODE -ne 0) { throw "Build exited $LASTEXITCODE; preserve logs and partial output." }
}
finally {
    if (Get-Process Unity -ErrorAction SilentlyContinue) { throw "Unity still owns this project; preserve the temporary observer and backup at $backup." }
    [IO.File]::WriteAllBytes($qualityPath, $qualityBytes)
    [IO.File]::WriteAllBytes($auditPath, $auditBytes)
    # Only the two fresh observer files owned by this script are removed.
    Remove-Item -LiteralPath $observer -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "$observer.meta" -ErrorAction SilentlyContinue
    Write-Output "Restored project settings, initializer and observer staging. Backup: $backup"
}
