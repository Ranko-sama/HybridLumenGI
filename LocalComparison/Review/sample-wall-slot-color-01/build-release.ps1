$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$output = 'I:/Unity test/Comparison/Builds/LocalRelease98'
$checkRoot = "$project/Assets/HLGIWallColorBuildCheck"
if (Test-Path -LiteralPath $checkRoot) { throw 'Preserve an existing Editor check directory.' }
$qualityPath = "$project/ProjectSettings/QualitySettings.asset"
$auditPath = "$project/Assets/ComparisonHarness/RuntimeAuditEntry.cs"
$rendererPath = "$project/Assets/UnifiedRelease74/Generated/Renderer.asset"
$attempt = Join-Path $PSScriptRoot 'release-build-attempt.json'
if ((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath $attempt)) {
    throw 'Preserve existing build output and attempt.'
}
if (Get-Process Unity,HybridLumenGIPlayer -ErrorAction SilentlyContinue) {
    throw 'An existing rendering process is active.'
}
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$product = 'Runtime/HybridLumenGIUnifiedSampleInteraction.cs'
$installed = Join-Path "$project/Assets/HybridLumenGI" $product
$installedText = [IO.File]::ReadAllText($installed).Replace("`r`n", "`n").TrimEnd()
$oldText = ((git -C $repo show "3de97f4:$product") -join "`n").TrimEnd()
$newText = [IO.File]::ReadAllText((Join-Path $repo $product)).Replace("`r`n", "`n").TrimEnd()
if ($installedText -cne $oldText -and $installedText -cne $newText) { throw 'Preserve an independently modified Unity project source.' }
Copy-Item -LiteralPath (Join-Path $repo $product) -Destination $installed
$qualityBytes = [IO.File]::ReadAllBytes($qualityPath)
$auditBytes = [IO.File]::ReadAllBytes($auditPath)
$rendererBytes = [IO.File]::ReadAllBytes($rendererPath)
$backup = Join-Path $env:TEMP ('hlgi-wall-color-build-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
[IO.File]::WriteAllBytes((Join-Path $backup 'QualitySettings.asset'), $qualityBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'RuntimeAuditEntry.cs'), $auditBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'Renderer.asset'), $rendererBytes)
$nativeExit = $null
try {
    [IO.Directory]::CreateDirectory((Join-Path $checkRoot 'Editor')) | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'WallColorBuildCheck.cs') -Destination (Join-Path $checkRoot 'Editor/WallColorBuildCheck.cs')
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
        scope = 'Native per-slot and inherited wall color switch/restore using the ordinary interaction, followed by the ordinary Release/None build in the same headless Editor.'
        backup = $backup
    } | ConvertTo-Json | Set-Content -LiteralPath $attempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -LogName 'LocalRelease98Build' `
        -ExecuteMethod 'WallColorBuildCheck.Run' `
        -ExtraArguments @('-nographics', '-buildTarget', 'StandaloneWindows64', '-hlgiScene', 'Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity', '-hlgiOutput', $output)
    $nativeExit = $LASTEXITCODE
    [ordered]@{ exitCode = $nativeExit; endedUtc = [DateTime]::UtcNow.ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'release-build-exit.json') -Encoding utf8
}
finally {
    if (Get-Process Unity -ErrorAction SilentlyContinue) { throw "Unity still owns the project. Preserve backup at $backup until it exits." }
    [IO.File]::WriteAllBytes($qualityPath, $qualityBytes)
    [IO.File]::WriteAllBytes($auditPath, $auditBytes)
    [IO.File]::WriteAllBytes($rendererPath, $rendererBytes)
    $checkedRoot = [IO.Path]::GetFullPath($checkRoot)
    $assetsRoot = [IO.Path]::GetFullPath((Join-Path $project 'Assets')) + [IO.Path]::DirectorySeparatorChar
    if (-not $checkedRoot.StartsWith($assetsRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Check directory escaped project Assets.' }
    if (Test-Path -LiteralPath $checkedRoot) { Move-Item -LiteralPath $checkedRoot -Destination (Join-Path $backup 'EditorCheck') }
    if (Test-Path -LiteralPath ($checkedRoot+'.meta')) { Move-Item -LiteralPath ($checkedRoot+'.meta') -Destination (Join-Path $backup 'EditorCheck.meta') }
    Write-Output "Restored quality settings, sample Renderer and existing initializer. Backup: $backup"
}
if ($null -ne $nativeExit) { exit $nativeExit }
