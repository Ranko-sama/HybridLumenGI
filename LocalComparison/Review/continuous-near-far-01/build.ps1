param([switch]$ColdCrossing)
$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$name = if ($ColdCrossing) { 'LocalRelease103ColdCrossing01' } else { 'LocalRelease90ContinuousNearFar01' }
$output = "I:/Unity test/Comparison/Builds/$name"
$record = if ($ColdCrossing) { Join-Path $PSScriptRoot '../cold-crossing-01' } else { $PSScriptRoot }
$sceneName = if ($ColdCrossing) { 'ConnectedRooms.unity' } else { 'UnifiedSample.unity' }
$scene = "Assets/UnifiedRelease74/Generated/Variant/$sceneName"
$qualityPath = "$project/ProjectSettings/QualitySettings.asset"
$auditPath = "$project/Assets/ComparisonHarness/RuntimeAuditEntry.cs"
$rendererPath = "$project/Assets/UnifiedRelease74/Generated/Renderer.asset"
$attempt = Join-Path $record 'build-attempt.json'
if ((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath $attempt)) {
    throw 'Preserve existing build output and attempt.'
}
if (Get-Process Unity,HybridLumenGIPlayer -ErrorAction SilentlyContinue) {
    throw 'An existing rendering process is active.'
}
$qualityBytes = [IO.File]::ReadAllBytes($qualityPath)
$auditBytes = [IO.File]::ReadAllBytes($auditPath)
$rendererBytes = [IO.File]::ReadAllBytes($rendererPath)
$backup = Join-Path $env:TEMP ('hlgi-continuous-near-far-build-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
[IO.File]::WriteAllBytes((Join-Path $backup 'QualitySettings.asset'), $qualityBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'RuntimeAuditEntry.cs'), $auditBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'Renderer.asset'), $rendererBytes)
$sceneSetupPath = "$project/Library/LastSceneManagerSetup.txt"
if (Test-Path -LiteralPath $sceneSetupPath) { Copy-Item -LiteralPath $sceneSetupPath -Destination $backup }
$observer = "$project/Assets/ComparisonHarness/ContinuousNearFar.cs"
$observerSource = Join-Path $PSScriptRoot 'ContinuousNearFar.cs'
if ((Test-Path -LiteralPath $observer) -or (Test-Path -LiteralPath "$observer.meta")) { throw 'Preserve existing observer staging.' }
if (-not (Test-Path -LiteralPath $observerSource)) { throw 'Observer source is missing.' }
$nativeExit = $null
try {
    $rendererText = [Text.Encoding]::UTF8.GetString($rendererBytes)
    $preference = '    preferHardwareTracing: 0'
    if ([regex]::Matches($rendererText, [regex]::Escape($preference)).Count -ne 1) { throw 'Expected one software sample preference.' }
    $rendererText = $rendererText.Replace($preference, '    preferHardwareTracing: 1')
    $raysPattern = '(?m)^    raysPerPixel: 1(?=\r?$)'
    if ([regex]::Matches($rendererText, $raysPattern).Count -ne 1) { throw 'Expected exactly one raysPerPixel: 1 setting.' }
    $rendererText = [regex]::Replace($rendererText, $raysPattern, '    raysPerPixel: 2')
    if ($ColdCrossing) {
        $filter = '(?m)^    filterIterations: 3(?=\r?$)'
        if ([regex]::Matches($rendererText,$filter).Count -ne 1) { throw 'Expected the saved filter setting.' }
        $rendererText = [regex]::Replace($rendererText,$filter,'    filterIterations: 4')
    }
    [IO.File]::WriteAllText($rendererPath, $rendererText, [Text.UTF8Encoding]::new($false))
    $qualityText = [Text.Encoding]::UTF8.GetString($qualityBytes)
    $oldPipeline = 'c4904ab5031e93c4a8f8e6ca539e4152'
    $samplePipeline = 'ca5b7ea101c75f645851495aea1b326c'
    if (-not $qualityText.Contains($oldPipeline)) { throw 'Expected original PC pipeline setting is missing.' }
    $qualityText = $qualityText.Replace($oldPipeline, $samplePipeline)
    [IO.File]::WriteAllText($qualityPath, $qualityText, [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath 'I:/Unity test/Comparison/Release74BuildArchive/Assets/ComparisonHarness/RuntimeAuditEntry.cs' -Destination $auditPath
    Copy-Item -LiteralPath $observerSource -Destination $observer
    [ordered]@{
        startedUtc = [DateTime]::UtcNow.ToString('o')
        source = (git -C (Join-Path $PSScriptRoot '../../..') rev-parse HEAD).Trim()
        scene = $scene
        output = $output
        localOverrides = @{ raysPerPixel = 2; preferHardwareTracing = $true }; observer = $observerSource
        scope = if ($ColdCrossing) { 'Release103 cold outside/near/outside, 20 units/s, immediate reversal, filter4, one round trip. CPU submission, publication and page state.' } else { 'Release90 hot near/far, 20 units/s, ten round trips. CPU submission, publication and page state.' }
        backup = $backup
    } | ConvertTo-Json | Set-Content -LiteralPath $attempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -LogName ($name + 'Build') `
        -ExecuteMethod 'HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build' `
        -ExtraArguments @('-buildTarget', 'StandaloneWindows64', '-hlgiScene', $scene, '-hlgiOutput', $output)
    $nativeExit = $LASTEXITCODE
    [ordered]@{ exitCode = $nativeExit; endedUtc = [DateTime]::UtcNow.ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $record 'build-exit.json') -Encoding utf8
}
finally {
    if (Get-Process Unity -ErrorAction SilentlyContinue) { throw "Unity still owns the project. Preserve backup at $backup until it exits." }
    [IO.File]::WriteAllBytes($qualityPath, $qualityBytes)
    [IO.File]::WriteAllBytes($auditPath, $auditBytes)
    [IO.File]::WriteAllBytes($rendererPath, $rendererBytes)
    if (Test-Path -LiteralPath "$backup/LastSceneManagerSetup.txt") { Copy-Item -LiteralPath "$backup/LastSceneManagerSetup.txt" -Destination $sceneSetupPath }
    # Only the two fresh observer files owned by this script are removed.
    Remove-Item -LiteralPath $observer -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "$observer.meta" -ErrorAction SilentlyContinue
    Write-Output "Restored quality settings, sample Renderer, initializer and observer staging. Backup: $backup"
}
if ($null -ne $nativeExit) { exit $nativeExit }
