$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$output = 'I:/Unity test/Comparison/Builds/LocalRelease100StreamingSustained30m01'
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
$driver = "$project/Assets/ComparisonHarness/StreamingSustained.cs"
if ((Test-Path -LiteralPath $driver) -or (Test-Path -LiteralPath ($driver+'.meta'))) { throw 'Preserve existing project driver.' }
$qualityBytes = [IO.File]::ReadAllBytes($qualityPath)
$auditBytes = [IO.File]::ReadAllBytes($auditPath)
$rendererBytes = [IO.File]::ReadAllBytes($rendererPath)
$backup = Join-Path $env:TEMP ('hlgi-streaming-sustained-build-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
[IO.File]::WriteAllBytes((Join-Path $backup 'QualitySettings.asset'), $qualityBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'RuntimeAuditEntry.cs'), $auditBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'Renderer.asset'), $rendererBytes)
$nativeExit = $null
try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'StreamingSustained.cs') -Destination $driver
    $rendererText = [Text.Encoding]::UTF8.GetString($rendererBytes)
    foreach ($setting in @(@('preferHardwareTracing','1'),@('raysPerPixel','2'),@('filterIterations','4'))) {
        $pattern = '(?m)^    '+$setting[0]+': \d+(?=\r?$)'
        if ([regex]::Matches($rendererText,$pattern).Count -ne 1) { throw ('Expected one '+$setting[0]+' setting.') }
        $rendererText = [regex]::Replace($rendererText,$pattern,('    '+$setting[0]+': '+$setting[1]))
    }
    $identityPattern = '(?m)^    receiverObjectHistory: 1(?=\r?$)'
    if ([regex]::Matches($rendererText,$identityPattern).Count -ne 1) { throw 'Expected existing receiverObjectHistory: 1; do not silently change source-history configuration.' }
    [IO.File]::WriteAllText($rendererPath, $rendererText, [Text.UTF8Encoding]::new($false))
    $qualityText = [Text.Encoding]::UTF8.GetString($qualityBytes)
    $oldPipeline = 'c4904ab5031e93c4a8f8e6ca539e4152'
    $samplePipeline = 'ca5b7ea101c75f645851495aea1b326c'
    if (-not $qualityText.Contains($oldPipeline)) { throw 'Expected original PC pipeline setting is missing.' }
    $qualityText = $qualityText.Replace($oldPipeline, $samplePipeline)
    [IO.File]::WriteAllText($qualityPath, $qualityText, [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath 'I:/Unity test/Comparison/Release74BuildArchive/Assets/ComparisonHarness/RuntimeAuditEntry.cs' -Destination $auditPath
    [ordered]@{
        startedUtc = [DateTime]::UtcNow.ToString('o')
        source = (git -C (Join-Path $PSScriptRoot '../../..') rev-parse HEAD).Trim()
        scene = 'Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity'
        output = $output
        localOverrides = @{ raysPerPixel = 2; filterIterations = 4; preferHardwareTracing = $true }
        preservedReceiverObjectHistory = $true
        scope = 'Release100 product, with a temporary driver calling public Near/Leave and sampling the ordinary ledger during a 30-minute streaming route.'
        backup = $backup
    } | ConvertTo-Json | Set-Content -LiteralPath $attempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -LogName 'LocalRelease100StreamingSustained30m01Build' `
        -ExecuteMethod 'HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build' `
        -ExtraArguments @('-nographics', '-buildTarget', 'StandaloneWindows64', '-hlgiScene', 'Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity', '-hlgiOutput', $output)
    $nativeExit = $LASTEXITCODE
    [ordered]@{ exitCode = $nativeExit; endedUtc = [DateTime]::UtcNow.ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'build-exit.json') -Encoding utf8
}
finally {
    if (Get-Process Unity -ErrorAction SilentlyContinue) { throw "Unity still owns the project. Preserve backup at $backup until it exits." }
    [IO.File]::WriteAllBytes($qualityPath, $qualityBytes)
    [IO.File]::WriteAllBytes($auditPath, $auditBytes)
    [IO.File]::WriteAllBytes($rendererPath, $rendererBytes)
    if (Test-Path -LiteralPath $driver) { Move-Item -LiteralPath $driver -Destination (Join-Path $backup 'StreamingSustained.cs') }
    if (Test-Path -LiteralPath ($driver+'.meta')) { Move-Item -LiteralPath ($driver+'.meta') -Destination (Join-Path $backup 'StreamingSustained.cs.meta') }
    Write-Output "Restored quality settings, sample Renderer and existing initializer. Backup: $backup"
}
if ($null -ne $nativeExit) { exit $nativeExit }
