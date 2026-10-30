$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$ownedRoot = [IO.Path]::GetFullPath("$project/Assets/SkinnedStoppedHistory01")
$output = 'I:/Unity test/Comparison/SkinnedStoppedHistory03'
$qualityPath = "$project/ProjectSettings/QualitySettings.asset"
$auditPath = "$project/Assets/ComparisonHarness/RuntimeAuditEntry.cs"
$rendererPath = "$project/Assets/UnifiedRelease74/Generated/Renderer.asset"
$featurePath = "$project/Assets/HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs"
$attempt = Join-Path $PSScriptRoot 'native-attempt03.json'
if ((Test-Path -LiteralPath $attempt) -or (Test-Path -LiteralPath $ownedRoot) -or
    (Test-Path -LiteralPath "$ownedRoot.meta") -or (Test-Path -LiteralPath $output)) { throw 'Preserve existing attempt and inputs.' }
if (Get-Process Unity,HybridLumenGIPlayer -ErrorAction SilentlyContinue) { throw 'An existing rendering process is active.' }
$restore = @{}
foreach ($path in @($qualityPath,$auditPath,$rendererPath,$featurePath)) { $restore[$path] = [IO.File]::ReadAllBytes($path) }
$backup = Join-Path $env:TEMP ('hlgi-skin-stopped-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
foreach ($path in $restore.Keys) { [IO.File]::WriteAllBytes((Join-Path $backup ([IO.Path]::GetFileName($path))),$restore[$path]) }
$nativeExit = $null
try {
    [IO.Directory]::CreateDirectory("$ownedRoot/Editor") | Out-Null
    [IO.Directory]::CreateDirectory("$ownedRoot/Resources") | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo 'LocalComparison/Review/moving-occluder-stage-review-01/instrumentation/prepared/Assets/ComparisonHarness/Resources/MovingOccluderIdentityCopy.compute') -Destination "$ownedRoot/Resources/MovingOccluderIdentityCopy.compute"
    foreach ($name in @('SkinStoppedHistoryUsage.cs','SkinStoppedHistoryTap.cs')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $ownedRoot $name)
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'SkinStoppedHistoryEditor.cs') -Destination "$ownedRoot/Editor/SkinStoppedHistoryEditor.cs"
    foreach ($name in @('HybridLumenGIReceiverDiscovery.cs','HybridLumenGIReceiverRegistry.cs','HybridLumenGIReceiverIdentityPass.cs','HybridLumenGIReceiverSkinPose.cs','HybridLumenGIReceiverSkinPose.cs.meta')) {
        Copy-Item -LiteralPath (Join-Path $repo "Runtime/$name") -Destination "$project/Assets/HybridLumenGI/Runtime/$name"
    }
    $featureText = [IO.File]::ReadAllText((Join-Path $repo 'Runtime/HybridLumenGIRendererFeature.cs'))
    $prepare = '                    state.receiverIdentityDraws=identityFrame.Draws.Count;state.receiverUnknownRectangles=identityFrame.UnknownRects.Count;'
    if (-not $featureText.Contains($prepare)) { throw 'Identity source hook missing.' }
    $featureText = $featureText.Replace($prepare,"                    SkinStoppedHistoryTap.Prepare(camera,identityFrame);`n"+$prepare)
    $dependency = '                    builder.UseBuffer(work.areaEmitters,AccessFlags.ReadWrite);'
    if (-not $featureText.Contains($dependency)) { throw 'Transport graph dependency hook missing.' }
    $featureText = $featureText.Replace($dependency,$dependency+"`n                    var skinCopy=SkinStoppedHistoryTap.CopyBufferFor(camera);if(skinCopy!=null)builder.UseBuffer(graph.ImportBuffer(skinCopy),AccessFlags.ReadWrite);")
    $record = '                using(d.frameTiming.Profile(cmd,"HLGI Temporal")) Dispatch(cmd,c,temporal,state);'
    if (-not $featureText.Contains($record)) { throw 'Temporal output hook missing.' }
    $featureText = $featureText.Replace($record,$record+"`n                SkinStoppedHistoryTap.Record(cmd,state.camera,(Texture)d.identityWrite,(Texture)d.momentsWrite,d.useIdentity);")
    [IO.File]::WriteAllText($featurePath,$featureText,[Text.UTF8Encoding]::new($false))
    $rendererText = [Text.Encoding]::UTF8.GetString($restore[$rendererPath])
    foreach ($setting in @(@('preferHardwareTracing','1'),@('raysPerPixel','2'),@('filterIterations','4'),@('receiverObjectHistory','1'))) {
        $pattern = '(?m)^    '+$setting[0]+': \d+(?=\r?$)'
        if ([regex]::Matches($rendererText,$pattern).Count -ne 1) { throw ('Expected one '+$setting[0]+' setting.') }
        $rendererText = [regex]::Replace($rendererText,$pattern,('    '+$setting[0]+': '+$setting[1]))
    }
    [IO.File]::WriteAllText($rendererPath,$rendererText,[Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath 'I:/Unity test/Comparison/Release74BuildArchive/Assets/ComparisonHarness/RuntimeAuditEntry.cs' -Destination $auditPath
    [ordered]@{ startedUtc=[DateTime]::UtcNow.ToString('o'); output=$output; backup=$backup;
        source='a09977c plus working-tree Skinned stopped-history candidate';
        sequence='240 requests: Mesh8 -> stoppedSkin -> deform after119 -> stop after127 -> drain after239';
        scope='Source-qualified native identity and moments for stopped Skin; no reference, performance, BakeMesh comparison or hashes.'
    } | ConvertTo-Json | Set-Content -LiteralPath $attempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -KeepRunning -LogName 'SkinnedStoppedHistory03' `
        -ExecuteMethod 'SkinStoppedHistoryEditor.Run' -ExtraArguments @('-skinStoppedHistoryOutput',$output)
    $nativeExit = $LASTEXITCODE
    [ordered]@{ exitCode=$nativeExit; endedUtc=[DateTime]::UtcNow.ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'native-exit03.json') -Encoding utf8
}
finally {
    if (Get-Process Unity -ErrorAction SilentlyContinue) { throw "Unity still owns temporary input; preserve backup $backup." }
    foreach ($path in $restore.Keys) { [IO.File]::WriteAllBytes($path,$restore[$path]) }
    if (Test-Path -LiteralPath $ownedRoot) {
        $resolved = (Resolve-Path -LiteralPath $ownedRoot).Path
        $expected = [IO.Path]::GetFullPath('I:/Unity test/Project/Assets/SkinnedStoppedHistory01')
        $retained = [IO.Path]::GetFullPath((Join-Path $backup 'UsageScripts'))
        if (-not $resolved.Equals($expected,[StringComparison]::OrdinalIgnoreCase) -or
            -not $retained.StartsWith([IO.Path]::GetFullPath($backup)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or
            (Test-Path -LiteralPath $retained)) { throw 'Unexpected retained-script move paths.' }
        Move-Item -LiteralPath $resolved -Destination $retained
        if (Test-Path -LiteralPath "$ownedRoot.meta") { Move-Item -LiteralPath "$ownedRoot.meta" -Destination "$retained.meta" }
    }
    Write-Output "Restored Feature observer, quality, renderer settings and initializer; retained temporary usage scripts outside Assets. Backup: $backup"
}
if ($null -ne $nativeExit) { exit $nativeExit }
