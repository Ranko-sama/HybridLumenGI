$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$archive = 'I:/Unity test/Comparison/ValidationPackageV209/project-archive/Assets/ValidationPackageV201'
$ownedRoot = [IO.Path]::GetFullPath("$project/Assets/ValidationPackageV201")
$output = 'I:/Unity test/Comparison/LocalRecolorResponse01'
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
$kernelPath = "$project/Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl"
$kernelBytes = [IO.File]::ReadAllBytes($kernelPath)
$sceneSourcePath = "$project/Assets/HybridLumenGI/Runtime/HybridLumenGIScene.cs"
$sceneSourceBytes = [IO.File]::ReadAllBytes($sceneSourcePath)
$backup = Join-Path $env:TEMP ('hlgi-local-recolor-response-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
[IO.File]::WriteAllBytes((Join-Path $backup 'ValidationSequence.cs'), $sequenceBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'QualitySettings.asset'), $qualityBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'HybridLumenGIKernels.hlsl'), $kernelBytes)
[IO.File]::WriteAllBytes((Join-Path $backup 'HybridLumenGIScene.cs'), $sceneSourceBytes)
$nativeExit = $null
try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../../../Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl') -Destination $kernelPath
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../../../Runtime/HybridLumenGIScene.cs') -Destination $sceneSourcePath
    Copy-Item -LiteralPath $archive -Destination $ownedRoot -Recurse
    Copy-Item -LiteralPath "$archive.meta" -Destination "$ownedRoot.meta"
    $hostPath = Join-Path $ownedRoot 'ValidationPackageV2Host.cs'
    $hostText = [IO.File]::ReadAllText($hostPath)
    $hostAnchor = '            string status = sequence.CaptureStatus;'
    if (-not $hostText.Contains($hostAnchor)) { throw 'Original host stop location missing.' }
    $hostText = $hostText.Replace($hostAnchor, "            if (sequence.RenderedFrames >= 240 && sequence.enabled) { colorCapture?.Seal(); sequence.enabled = false; }`n" + $hostAnchor)
    $hostText = $hostText.Replace('    private bool began, finished;', '    private bool began, finished;
    private int colorRequested = -1;
    private HybridLumenGIValidationCapture.Session colorCapture;')
    $cameraAnchor = '    private void BeginCamera(ScriptableRenderContext context, Camera camera) { if (ReferenceEquals(camera, targetCamera)) Observe("begin-camera"); }'
    if (-not $hostText.Contains($cameraAnchor)) { throw 'Original begin-camera hook missing.' }
    $cameraHook = @'
    private void BeginCamera(ScriptableRenderContext context, Camera camera)
    {
        if (!ReferenceEquals(camera, targetCamera)) return;
        int frame = sequence.RenderedFrames;
        if (began && frame != colorRequested && (frame == 119 || frame == 150 || frame == 179 || frame == 239))
        { colorCapture.Request(frame, Time.frameCount); colorRequested = frame; }
        Observe("begin-camera");
    }
'@
    $hostText = $hostText.Replace($cameraAnchor, $cameraHook)
    $hostText = $hostText.Replace('began = true; sequence.BeginCapture();',
        'began = true; colorCapture = HybridLumenGIValidationCapture.Begin(targetCamera, observedFeature, Path.Combine(receiptDirectory, "signals")); sequence.BeginCapture();')
    $hostText = $hostText.Replace('if (!sequence.ReferenceCaptureDrained) return;',
        'if (!sequence.ReferenceCaptureDrained || (colorCapture != null && !colorCapture.IsDrained)) return;')
    $hostText = $hostText.Replace('{ RenderPipelineManager.beginCameraRendering -= BeginCamera;',
        '{ colorCapture?.Close(); RenderPipelineManager.beginCameraRendering -= BeginCamera;')
    $recolorHook = @'
    [Serializable] private sealed class LocalRecolorEvent
    {
        public int afterRenderedLogicalFrame, engineFrame;
        public int firstAffectedLogicalFrame = 120;
        public string renderer, operation = "Renderer.SetPropertyBlock / _BaseColor; ordinary C-key operation";
        public Color previousEffectiveColor, requestedColor, readBackMpbColor;
    }
    private Renderer recolorWall;
    private MaterialPropertyBlock recolorOriginal;
    private bool recolored;
    private void ApplyLocalRecolor()
    {
        if (recolored || sequence.RenderedFrames != 120) return;
        int count = 0;
        foreach (var candidate in UnityEngine.Object.FindObjectsByType<MeshRenderer>(FindObjectsSortMode.None))
            if (candidate.name == "Red wall") { recolorWall = candidate; count++; }
        if (count != 1 || recolorWall.sharedMaterials.Length != 1)
            throw new InvalidOperationException("Expected one ordinary single-material Red wall");
        int baseColor = Shader.PropertyToID("_BaseColor");
        recolorOriginal = new MaterialPropertyBlock(); recolorWall.GetPropertyBlock(recolorOriginal);
        Color before = recolorOriginal.HasProperty(baseColor) ? recolorOriginal.GetColor(baseColor) : recolorWall.sharedMaterial.GetColor(baseColor);
        var changed = new MaterialPropertyBlock(); recolorWall.GetPropertyBlock(changed);
        var blue = new Color(.05f, .15f, .8f, 1);
        changed.SetColor(baseColor, blue); recolorWall.SetPropertyBlock(changed);
        var observed = new MaterialPropertyBlock(); recolorWall.GetPropertyBlock(observed);
        File.WriteAllText(Path.Combine(receiptDirectory, "local-recolor-event.json"), JsonUtility.ToJson(new LocalRecolorEvent {
            afterRenderedLogicalFrame = sequence.RenderedFrames - 1, engineFrame = Time.frameCount,
            renderer = recolorWall.name, previousEffectiveColor = before, requestedColor = blue,
            readBackMpbColor = observed.GetColor(baseColor) }, true));
        recolored = true;
    }
'@
    $hostText = $hostText.Replace('    private bool began, finished;', $recolorHook + "`n    private bool began, finished;")
    # Sequence.Update (-500) renders before Host.Update (1000). Apply after the
    # 119 receipt, before the next Update renders logical120.
    $hostText = $hostText.Replace($hostAnchor, "            ApplyLocalRecolor();`n" + $hostAnchor)
    $hostText = $hostText.Replace('{ colorCapture?.Close(); RenderPipelineManager.beginCameraRendering -= BeginCamera;',
        '{ if (recolorWall && recolorOriginal != null) recolorWall.SetPropertyBlock(recolorOriginal); colorCapture?.Close(); RenderPipelineManager.beginCameraRendering -= BeginCamera;')
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
            sequenceSettings.FindProperty("runLabel").stringValue = "local-recolor-static-door-incomplete-prefix";
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

    # The current product is staged separately and restored on exit. Temporary
    # image selection, fixed door and one Host MPB event are the only scenario changes. The original 720-frame
    # completion/failed protocol and all transport code remain unchanged.
    $sequenceText = [Text.Encoding]::UTF8.GetString($sequenceBytes)
    $captureAnchor = '                if (!IsCaptureFrame(logicalFrame, captureEvery)) return;'
    if (-not $sequenceText.Contains($captureAnchor)) { throw 'Original ordinary capture selection missing.' }
    $sequenceText = $sequenceText.Replace($captureAnchor,
        '                if (logicalFrame != 119 && logicalFrame != 120 && logicalFrame != 150 && logicalFrame != 179 && logicalFrame != 239) return;')
    $doorAnchor = '            door.ApplyFrame(logicalFrame);'
    if (-not $sequenceText.Contains($doorAnchor)) { throw 'Original door action missing.' }
    $sequenceText = $sequenceText.Replace($doorAnchor, '            door.ApplyFrame(0); // Temporary local-recolor observation: no motion event.')
    [IO.File]::WriteAllText($sequencePath, $sequenceText, [Text.UTF8Encoding]::new($false))
    [ordered]@{ startedUtc=[DateTime]::UtcNow.ToString('o'); source='0181ef2 / Release83 product; current Scene and Kernels staged; existing Capture API and temporary ordinary capture selection';
        signalFrames=@(119,150,179,239); outgoingFrames=@(119,120,150,179,239); output=$output; quantity='Existing API filteredD and validity; ordinary IndirectOnly output separately retained';
        expectedCompletion='Original sequence and Editor result remain failed/incomplete after 240 frames with static door and one local MPB event.';
        scope='One Unity process and existing Capture API; saved scene with fixed door and local recolor at120; not the original720 timeline; no source package, new reference, hash verification, steady-state or performance claim.'
    } | ConvertTo-Json | Set-Content -LiteralPath $attempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -KeepRunning -LogName 'LocalRecolorResponse01' `
        -ExecuteMethod 'ValidationPackageV2Editor.Run' -ExtraArguments @('-validationPackageOutput', $output)
    $nativeExit = $LASTEXITCODE
    [ordered]@{ exitCode=$nativeExit; endedUtc=[DateTime]::UtcNow.ToString('o');
        expectedExit=1; expectedReason='A deliberate 240-frame static-door recolor observation does not satisfy the unchanged720 completion gate or its original motion timeline. Inspect receipts to distinguish an earlier failure.'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'native-exit.json') -Encoding utf8
}
finally {
    if (Get-Process Unity -ErrorAction SilentlyContinue) { throw "Unity still owns the staged scene; preserve it and the backup at $backup until the process ends." }
    [IO.File]::WriteAllBytes($kernelPath, $kernelBytes)
    [IO.File]::WriteAllBytes($sceneSourcePath, $sceneSourceBytes)
    [IO.File]::WriteAllBytes($sequencePath, $sequenceBytes)
    [IO.File]::WriteAllBytes($qualityPath, $qualityBytes)
    if (Test-Path -LiteralPath $ownedRoot) {
        $resolvedOwnedRoot = (Resolve-Path -LiteralPath $ownedRoot).Path
        $expectedOwnedRoot = [IO.Path]::GetFullPath('I:/Unity test/Project/Assets/ValidationPackageV201')
        if (-not $resolvedOwnedRoot.Equals($expectedOwnedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup target.' }
        Remove-Item -LiteralPath $resolvedOwnedRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath "$ownedRoot.meta") { Remove-Item -LiteralPath "$ownedRoot.meta" }
    Write-Output "Restored original capture source and quality settings; removed only the new scene copy. Backup: $backup"
}
if ($null -ne $nativeExit) { exit $nativeExit }
