"""Adapt the existing saved-scene runner; leave product transport unchanged."""
from pathlib import Path

HERE = Path(__file__).resolve().parent
source = (HERE.parent / "rigid-pose-history-01/run.ps1").read_text(encoding="utf-8-sig")
source = "\n".join(line for line in source.splitlines() if not any(token in line for token in
    ("$sceneSourcePath", "$sceneSourceBytes"))) + "\n"
source = source.replace("RigidPoseHistory01", "MultiCameraHistory01").replace("hlgi-rigid-pose-history-", "hlgi-multi-camera-history-")
source = source.replace("RenderedFrames >= 240", "RenderedFrames >= 105")
source = source.replace("colorCapture?.Seal(); sequence.enabled = false;", "colorCapture?.Seal(); secondaryCapture?.Seal(); sequence.enabled = false;")
source = source.replace("frame == 239", "(frame == 95 || frame == 104)")
source = source.replace("logicalFrame != 239", "logicalFrame != 95 && logicalFrame != 104")
source = source.replace("rigid-pose-history-product-incomplete-prefix", "multi-camera-history-incomplete-prefix")
source = source.replace("0181ef2; only Scene product change from Release82; ordinary uninstrumented shaders; existing Capture API",
    "Release83 / product0181ef2; no product transport edit; existing Capture API with one session per Base camera")
source = source.replace("frames=@(239)", "frames=@('A95','B95','B103','A104')")
source = source.replace("240-frame", "105-frame").replace("scene0-239", "scene0-104")
source = source.replace("# The product Scene change is staged separately and restored on exit.", "# Product transport is unchanged.")

# Add host-only behavior after the ordinary hook substitutions have completed.
anchor = '    [IO.File]::WriteAllText($hostPath, $hostText, [Text.UTF8Encoding]::new($false))'
if source.count(anchor) != 1:
    raise RuntimeError("Expected one existing host write")
extra = r'''
    $hostText = $hostText.Replace('sequence.BeginCapture();', 'sequence.BeginCapture(); InitializeSecondary();')
    $hostText = $hostText.Replace('            if (sequence.RenderedFrames >= 105',
        '            if (began && sequence.enabled) RenderSecondary();' + "`n" + '            if (sequence.RenderedFrames >= 105')
    $hostText = $hostText.Replace('!colorCapture.IsDrained)) return;',
        '!colorCapture.IsDrained) || (secondaryCapture != null && !secondaryCapture.IsDrained)) return;')
    $hostText = $hostText.Replace('colorCapture?.Close(); RenderPipelineManager',
        'colorCapture?.Close(); secondaryCapture?.Close(); if (secondaryCamera != null) Destroy(secondaryCamera.gameObject); if (secondaryOutput != null) { secondaryOutput.Release(); Destroy(secondaryOutput); } RenderPipelineManager')
    $hostText = $hostText.Replace('        if (targetCamera != null) targetCamera.enabled = false;',
        '        if (targetCamera != null) targetCamera.enabled = false; if (secondaryCamera != null) secondaryCamera.enabled = false;')
    $hostText = $hostText.Replace('public int renderedFrames;', 'public int renderedFrames, secondaryRenderedFrames;')
    $hostText = $hostText.Replace('renderedFrames = sequence.RenderedFrames,',
        'renderedFrames = sequence.RenderedFrames, secondaryRenderedFrames = lastSecondaryFrame + 1,')
    $secondaryMethods = @'
    private Camera secondaryCamera;
    private RenderTexture secondaryOutput;
    private HybridLumenGIValidationCapture.Session secondaryCapture;
    private int lastSecondaryFrame = -1, lastSecondaryEngine = -1, lastSecondaryGi = -1;
    [Serializable] private sealed class PairInfo
    {
        public int primaryCamera, secondaryCamera, primaryTarget, secondaryTarget, feature;
        public string primaryType, secondaryType;
        public bool sameRenderer;
    }
    [Serializable] private sealed class SecondaryFrame
    {
        public int logicalFrame, engineFrame, giFrame;
        public Vector3 position;
        public Quaternion rotation;
        public bool hardwareBackend;
    }
    private void InitializeSecondary()
    {
        if (targetCamera.targetTexture == null) throw new InvalidOperationException("Primary target missing.");
        secondaryCamera = Instantiate(targetCamera.gameObject).GetComponent<Camera>();
        secondaryCamera.name = "Validation Camera B";
        secondaryCamera.tag = "Untagged";
        secondaryCamera.enabled = false;
        secondaryOutput = new RenderTexture(targetCamera.targetTexture.descriptor) { name = "HLGI camera B HDR" };
        if (!secondaryOutput.Create()) throw new InvalidOperationException("Camera B target creation failed.");
        secondaryCamera.targetTexture = secondaryOutput;
        var a = targetCamera.GetComponent<UnityEngine.Rendering.Universal.UniversalAdditionalCameraData>();
        var b = secondaryCamera.GetComponent<UnityEngine.Rendering.Universal.UniversalAdditionalCameraData>();
        if (a == null || b == null || a.renderType != UnityEngine.Rendering.Universal.CameraRenderType.Base ||
            b.renderType != UnityEngine.Rendering.Universal.CameraRenderType.Base || !ReferenceEquals(a.scriptableRenderer, b.scriptableRenderer))
            throw new InvalidOperationException("Two Base cameras must use the same existing renderer.");
        var pair = new PairInfo { primaryCamera = targetCamera.GetInstanceID(), secondaryCamera = secondaryCamera.GetInstanceID(),
            primaryTarget = targetCamera.targetTexture.GetInstanceID(), secondaryTarget = secondaryOutput.GetInstanceID(),
            feature = observedFeature.GetInstanceID(), primaryType = a.renderType.ToString(), secondaryType = b.renderType.ToString(), sameRenderer = true };
        File.WriteAllText(Path.Combine(receiptDirectory, "camera-pair.json"), JsonUtility.ToJson(pair, true));
        secondaryCapture = HybridLumenGIValidationCapture.Begin(secondaryCamera, observedFeature, Path.Combine(receiptDirectory, "signals-B"));
    }
    private void RenderSecondary()
    {
        int frame = sequence.RenderedFrames - 1;
        if (frame < 0 || frame == lastSecondaryFrame) return;
        if (secondaryCamera == null || frame != lastSecondaryFrame + 1 ||
            (lastSecondaryEngine >= 0 && Time.frameCount != lastSecondaryEngine + 1))
            throw new InvalidOperationException("Camera B skipped or repeated a frame; stop this run.");
        secondaryCamera.transform.SetPositionAndRotation(targetCamera.transform.position +
            (frame >= 103 ? targetCamera.transform.forward * 4f : Vector3.zero), targetCamera.transform.rotation);
        if (frame == 95 || frame == 103) secondaryCapture.Request(frame, Time.frameCount);
        var request = new RenderPipeline.StandardRequest { destination = secondaryOutput };
        if (!RenderPipeline.SupportsRenderRequest(secondaryCamera, request))
            throw new InvalidOperationException("Camera B StandardRequest unsupported.");
        RenderPipeline.SubmitRenderRequest(secondaryCamera, request);
        HybridLumenGIRendererFeature.CameraDiagnostics match = null;
        foreach (var d in observedFeature.GetDiagnostics())
            if (d.camera == secondaryCamera.name) { if (match != null) throw new InvalidOperationException("Ambiguous camera B diagnostics."); match = d; }
        if (match == null || match.frame <= lastSecondaryGi || (lastSecondaryGi >= 0 && match.frame != lastSecondaryGi + 1))
            throw new InvalidOperationException("Camera B GI did not advance exactly once.");
        lastSecondaryFrame = frame; lastSecondaryEngine = Time.frameCount; lastSecondaryGi = match.frame;
        var receipt = new SecondaryFrame { logicalFrame = frame, engineFrame = Time.frameCount, giFrame = match.frame,
            position = secondaryCamera.transform.position, rotation = secondaryCamera.transform.rotation, hardwareBackend = match.hardwareBackend };
        File.AppendAllText(Path.Combine(receiptDirectory, "secondary-frames.jsonl"), JsonUtility.ToJson(receipt) + "\n");
        Observe("after-secondary");
    }
'@
    $insert = $hostText.IndexOf('    private float started;')
    if ($insert -lt 0) { throw 'Existing host field insertion anchor missing.' }
    $hostText = $hostText.Insert($insert, $secondaryMethods + "`n")
'''
source = source.replace(anchor, extra + "\n" + anchor)
output = HERE / "run.ps1"
if output.exists():
    raise RuntimeError("Preserve existing run script")
output.write_text(source, encoding="utf-8")
print("Prepared existing-run adaptation for A95/B95/B103/A104. Unity not started.")
