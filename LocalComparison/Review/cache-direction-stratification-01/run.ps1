$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$archive = 'I:/Unity test/Comparison/ValidationPackageV209/project-archive/Assets/ValidationPackageV201'
$ownedRoot = [IO.Path]::GetFullPath("$project/Assets/ValidationPackageV201")
$output = 'I:/Unity test/Comparison/CacheDirectionStratification01'
$sequencePath = "$project/Assets/HybridLumenGI/Runtime/HybridLumenGIValidationSequence.cs"
$qualityPath = "$project/ProjectSettings/QualitySettings.asset"
$attempt = Join-Path $PSScriptRoot 'attempt.json'
if ((Test-Path -LiteralPath $attempt) -or (Test-Path -LiteralPath $output) -or
    (Test-Path -LiteralPath $ownedRoot) -or (Test-Path -LiteralPath "$ownedRoot.meta")) {
    throw 'Preserve existing run or project inputs.'
}
if (Get-Process Unity,HybridLumenGIPlayer -ErrorAction SilentlyContinue) { throw 'An existing rendering process is active.' }
$sequenceBytes = [IO.File]::ReadAllBytes($sequencePath)
$qualityBytes = [IO.File]::ReadAllBytes($qualityPath)
$backup = Join-Path $env:TEMP ('hlgi-cache-direction-stratification-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
[IO.File]::WriteAllBytes((Join-Path $backup 'ValidationSequence.cs'), $sequenceBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'QualitySettings.asset'), $qualityBytes)
$shaderNames = @('HybridLumenGITransport.hlsl','HybridLumenGIEmissiveSampling.hlsl')
$shaderRoot = "$project/Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI"
$sourceRoot = Join-Path $PSScriptRoot '../../../Runtime/Resources/HybridLumenGI'
foreach ($name in $shaderNames) { Copy-Item -LiteralPath (Join-Path $shaderRoot $name) -Destination (Join-Path $backup $name) }
$nativeExit = $null
try {
    foreach ($name in $shaderNames) { Copy-Item -LiteralPath (Join-Path $sourceRoot $name) -Destination (Join-Path $shaderRoot $name) }
    Copy-Item -LiteralPath $archive -Destination $ownedRoot -Recurse
    Copy-Item -LiteralPath "$archive.meta" -Destination "$ownedRoot.meta"
    $hostPath = Join-Path $ownedRoot 'ValidationPackageV2Host.cs'
    $hostText = [IO.File]::ReadAllText($hostPath)
    $hostAnchor = '            string status = sequence.CaptureStatus;'
    if (-not $hostText.Contains($hostAnchor)) { throw 'Original host stop location missing.' }
    $hostText = $hostText.Replace($hostAnchor, "            if (sequence.RenderedFrames >= 210 && sequence.enabled) { sequence.enabled = false; }`n" + $hostAnchor)
    [IO.File]::WriteAllText($hostPath, $hostText, [Text.UTF8Encoding]::new($false))

    $editorPath = Join-Path $ownedRoot 'Editor/ValidationPackageV2Editor.cs'
    $editorText = [IO.File]::ReadAllText($editorPath)
    $editorText = $editorText.Replace('!Directory.Exists(Generated) && SystemInfo.graphicsDeviceType', 'Directory.Exists(Generated) && SystemInfo.graphicsDeviceType')
    $start = $editorText.IndexOf('            AssetDatabase.CreateFolder(Root, "Generated");')
    $end = $editorText.IndexOf('            SessionState.SetString(Key + "scene", scenePath);', $start)
    if ($start -lt 0 -or $end -le $start) { throw 'Original editor preparation block missing.' }
    $savedSceneBlock = @'
            string scenePath = Generated + "/Scenes/Run/Validation.unity";
            var pipeline = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(Generated + "/Pipeline.asset");
            Require(pipeline != null, "Saved physical scene pipeline is missing.");
            QualitySettings.renderPipeline = pipeline;
            var scene = EditorSceneManager.OpenScene(scenePath, OpenSceneMode.Single);
            var sequence = UnityEngine.Object.FindFirstObjectByType<HybridLumenGIValidationSequence>();
            Require(sequence != null, "Saved sequence is missing.");
            var sequenceSettings = new SerializedObject(sequence);
            var camera = sequenceSettings.FindProperty("targetCamera").objectReferenceValue as Camera;
            var feature = sequenceSettings.FindProperty("feature").objectReferenceValue as HybridLumenGIRendererFeature;
            Require(camera != null && feature != null, "Saved camera/feature binding is missing.");
            var featureSettings = new SerializedObject(feature);
            featureSettings.FindProperty("settings.debugView").enumValueIndex = (int)HybridLumenGIRendererFeature.DebugView.IndirectOnly;
            featureSettings.ApplyModifiedPropertiesWithoutUndo();
            sequenceSettings.FindProperty("runOnStart").boolValue = false;
            sequenceSettings.FindProperty("exportReferencePackage").boolValue = false;
            sequenceSettings.FindProperty("referenceSourcePackage").stringValue = "";
            sequenceSettings.FindProperty("outputRoot").stringValue = Path.Combine(output, "capture");
            sequenceSettings.FindProperty("runLabel").stringValue = "cache-direction-stratification-incomplete-prefix";
            sequenceSettings.ApplyModifiedPropertiesWithoutUndo();
            var hosts = UnityEngine.Object.FindObjectsByType<ValidationPackageV2Host>(FindObjectsSortMode.None);
            Require(hosts.Length == 1, "Exactly one saved host is required.");
            hosts[0].sequence = sequence; hosts[0].targetCamera = camera; hosts[0].receiptDirectory = output;
            EditorUtility.SetDirty(hosts[0]);
            EditorSceneManager.MarkSceneDirty(scene);
            Require(EditorSceneManager.SaveScene(scene), "Cannot save the temporary scene settings.");
            AssetDatabase.SaveAssets();

'@
    $editorText = $editorText.Substring(0, $start) + $savedSceneBlock + $editorText.Substring($end)
    [IO.File]::WriteAllText($editorPath, $editorText, [Text.UTF8Encoding]::new($false))

    # Stage the single cache-direction candidate and select existing ordinary images. The original 720-frame
    # completion/failed protocol remains unchanged.
    $sequenceText = [Text.Encoding]::UTF8.GetString($sequenceBytes)
    $captureAnchor = '                if (!IsCaptureFrame(logicalFrame, captureEvery)) return;'
    if (-not $sequenceText.Contains($captureAnchor)) { throw 'Original ordinary capture selection missing.' }
    $sequenceText = $sequenceText.Replace($captureAnchor,
        '                if (logicalFrame != 149 && logicalFrame != 179 && logicalFrame != 189 && logicalFrame != 209) return;')
    [IO.File]::WriteAllText($sequencePath, $sequenceText, [Text.UTF8Encoding]::new($false))
    [ordered]@{ startedUtc=[DateTime]::UtcNow.ToString('o'); source='Release87 plus uncommitted cache-direction stratification candidate; exact delta in candidate.patch';
        outgoingFrames=@(149,179,189,209); output=$output; quantity='Ordinary IndirectOnly outgoing contribution only';
        expectedCompletion='Original sequence and Editor result remain failed/incomplete after an intentional 210-frame prefix.';
        scope='One Unity process, same saved software scene0-209, four ordinary HDR frames only; no extra signals, reference, hashes or performance claim.'
    } | ConvertTo-Json | Set-Content -LiteralPath $attempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -KeepRunning -LogName 'CacheDirectionStratification01' `
        -ExecuteMethod 'ValidationPackageV2Editor.Run' -ExtraArguments @('-validationPackageOutput', $output)
    $nativeExit = $LASTEXITCODE
    [ordered]@{ exitCode=$nativeExit; endedUtc=[DateTime]::UtcNow.ToString('o');
        expectedExit=1; expectedReason='A deliberate 210-frame prefix does not satisfy the unchanged 720-frame/candidate-package completion gate. Inspect receipts to distinguish an earlier failure.'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'native-exit.json') -Encoding utf8
}
finally {
    if (Get-Process Unity -ErrorAction SilentlyContinue) { throw "Unity still owns the staged scene; preserve it and the backup at $backup until the process ends." }
    foreach ($name in $shaderNames) { Copy-Item -LiteralPath (Join-Path $backup $name) -Destination (Join-Path $shaderRoot $name) }
    [IO.File]::WriteAllBytes($sequencePath, $sequenceBytes)
    [IO.File]::WriteAllBytes($qualityPath, $qualityBytes)
    if (Test-Path -LiteralPath $ownedRoot) {
        $resolvedOwnedRoot = (Resolve-Path -LiteralPath $ownedRoot).Path
        $expectedOwnedRoot = [IO.Path]::GetFullPath('I:/Unity test/Project/Assets/ValidationPackageV201')
        if (-not $resolvedOwnedRoot.Equals($expectedOwnedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup target.' }
        Remove-Item -LiteralPath $resolvedOwnedRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath "$ownedRoot.meta") { Remove-Item -LiteralPath "$ownedRoot.meta" }
    Write-Output "Restored original shaders, capture source and quality settings; removed only the new scene copy. Backup: $backup"
}
if ($null -ne $nativeExit) { exit $nativeExit }
