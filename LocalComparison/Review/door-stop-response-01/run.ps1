$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$archive = 'I:/Unity test/Comparison/ValidationPackageV209/project-archive/Assets/ValidationPackageV201'
$ownedRoot = [IO.Path]::GetFullPath("$project/Assets/ValidationPackageV201")
$output = 'I:/Unity test/Comparison/DoorStopResponse01'
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
$backup = Join-Path $env:TEMP ('hlgi-door-stop-response-' + [guid]::NewGuid().ToString('N'))
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
    $hostText = $hostText.Replace($hostAnchor, "            if (sequence.RenderedFrames >= 210 && sequence.enabled) { colorCapture?.Seal(); sequence.enabled = false; }`n" + $hostAnchor)
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
        if (began && frame != colorRequested && (frame == 179 || frame == 189 || frame == 209))
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
            sequenceSettings.FindProperty("runLabel").stringValue = "door-stop-current-product-incomplete-prefix";
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

    # The current product is staged separately and restored on exit. Only the existing ordinary image selection changes here. The original 720-frame
    # completion/failed protocol and all transport code remain unchanged.
    $sequenceText = [Text.Encoding]::UTF8.GetString($sequenceBytes)
    $captureAnchor = '                if (!IsCaptureFrame(logicalFrame, captureEvery)) return;'
    if (-not $sequenceText.Contains($captureAnchor)) { throw 'Original ordinary capture selection missing.' }
    $sequenceText = $sequenceText.Replace($captureAnchor,
        '                if (logicalFrame != 119 && logicalFrame != 149 && logicalFrame != 179 && logicalFrame != 189 && logicalFrame != 209) return;')
    [IO.File]::WriteAllText($sequencePath, $sequenceText, [Text.UTF8Encoding]::new($false))
    [ordered]@{ startedUtc=[DateTime]::UtcNow.ToString('o'); source='0181ef2 / Release83 product; current Scene and Kernels staged; existing Capture API and temporary ordinary capture selection';
        signalFrames=@(179,189,209); outgoingFrames=@(119,149,179,189,209); output=$output; quantity='Existing API filteredD and validity; ordinary IndirectOnly output separately retained';
        expectedCompletion='Original sequence and Editor result remain failed/incomplete after an intentional 210-frame prefix.';
        scope='One Unity process and existing Capture API; saved scene0-209; no source package, new integration, hash verification, steady-state or performance claim.'
    } | ConvertTo-Json | Set-Content -LiteralPath $attempt -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -KeepRunning -LogName 'DoorStopResponse01' `
        -ExecuteMethod 'ValidationPackageV2Editor.Run' -ExtraArguments @('-validationPackageOutput', $output)
    $nativeExit = $LASTEXITCODE
    [ordered]@{ exitCode=$nativeExit; endedUtc=[DateTime]::UtcNow.ToString('o');
        expectedExit=1; expectedReason='A deliberate 210-frame prefix does not satisfy the unchanged 720-frame/candidate-package completion gate. Inspect receipts to distinguish an earlier failure.'
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
