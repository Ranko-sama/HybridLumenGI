$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$output = 'I:/Unity test/Comparison/Builds/LocalRelease90DxrBaseline01'
$qualityPath = "$project/ProjectSettings/QualitySettings.asset"
$auditPath = "$project/Assets/ComparisonHarness/RuntimeAuditEntry.cs"
$rendererPath = "$project/Assets/UnifiedRelease74/Generated/Renderer.asset"
$attempt = Join-Path $PSScriptRoot 'build-attempt.json'
if ((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath $attempt)) {
    throw 'Preserve existing build output and attempt.'
}
if (Get-Process Unity,HybridLumenGIPlayer -ErrorAction SilentlyContinue) {
    throw 'An existing rendering process is active.'
}
$qualityBytes = [IO.File]::ReadAllBytes($qualityPath)
$auditBytes = [IO.File]::ReadAllBytes($auditPath)
$rendererBytes = [IO.File]::ReadAllBytes($rendererPath)
$backup = Join-Path $env:TEMP ('hlgi-release90-dxr-baseline-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
[IO.File]::WriteAllBytes((Join-Path $backup 'QualitySettings.asset'), $qualityBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'RuntimeAuditEntry.cs'), $auditBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'Renderer.asset'), $rendererBytes)
$observer = "$project/Assets/ComparisonHarness/UnifiedSampleGpuCost.cs"
$observerSource = Join-Path $PSScriptRoot '../release83-dxr-cost-01/UnifiedSampleGpuCost.cs'
if ((Test-Path -LiteralPath $observer) -or (Test-Path -LiteralPath "$observer.meta")) { throw 'Preserve existing observer staging.' }
$nativeExit = $null
try {
    $rendererText = [Text.Encoding]::UTF8.GetString($rendererBytes)
    $preference = '    preferHardwareTracing: 0'
    if ([regex]::Matches($rendererText, [regex]::Escape($preference)).Count -ne 1) { throw 'Expected one software sample preference.' }
    # The unchanged measurement observer switches the authored software preference to DXR before its fixed window.
    $raysPattern = '(?m)^    raysPerPixel: 1(?=\r?$)'
    if ([regex]::Matches($rendererText, $raysPattern).Count -ne 1) { throw 'Expected exactly one raysPerPixel: 1 setting.' }
    $rendererText = [regex]::Replace($rendererText, $raysPattern, '    raysPerPixel: 2')
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
        scene = 'Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity'
        output = $output
        localOverrides = @{ raysPerPixel = 2; runtimeObserverRequestsDxr = $true; measureOnly = $true; adaptive = $false }; observer = $observerSource
        scope = 'One measurement Release/None build of current Release90 product; unchanged existing 512-source-frame observer; saved sample 2ray/DXR/960x540 half GI, measurement only, feedback off. Ordinary Release90 unchanged.'
        backup = $backup
    } | ConvertTo-Json | Set-Content -LiteralPath $attempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -LogName 'LocalRelease90DxrBaseline01Build' `
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
    [IO.File]::WriteAllBytes($rendererPath, $rendererBytes)
    # Only the two fresh observer files owned by this script are removed.
    Remove-Item -LiteralPath $observer -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "$observer.meta" -ErrorAction SilentlyContinue
    Write-Output "Restored quality settings, sample Renderer, initializer and observer staging. Backup: $backup"
}
if ($null -ne $nativeExit) { exit $nativeExit }
