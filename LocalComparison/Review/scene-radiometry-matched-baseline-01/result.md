# Iteration16: real first native failure before Play

Unity6000.0.85f1 / DX12 / RTX2080Ti process30572 exited1. The actual C# sources
compiled/imported and source Build exported the real20 meshes/6 materials into
run/reference-scene.json. Dependencies then called PackageInfo.FindForAssetPath
for Packages/manifest.json and threw "Unresolved package input". That file is
project configuration, not an asset inside a Unity package. This exporter bug
was missed by both local preflight and the independent pre-native review.

The exception occurred before source-freeze.json and EnterPlaymode. Therefore:
- native attempts1; target-camera frames0; new PNG/HDR captures0;
- prospectiveSourceClosure=false; targetSurfaceCorrespondenceVerified=false;
- productObservationValid=false; integrationExecuted=false;
- referenceEstimateQualified=false; comparisonConclusive=false;
- nativeExitAccepted=false; historicalSourceClosure=false.

This is not evidence of a GI rendering defect. Do not compare the partial new
source with historical RGB or historical targets. No six-point reference was run.
No second native attempt was made. The earlier real360frame/9PNG+HDR evidence
remains in scene-lightoff-chain-02 with its original failed startup qualification.

The launcher restored all42 tracked deployed files; restoration.json records
byte-for-byte checks. New helper/scene metadata was archived then removed.
There is no Unity process left. Executed source and pre-native interface hashes
are preserved under instrumentation/prepared and pre-native-inputs.json.

Minimal candidate repair: LocalComparison/Harness/SceneRadiometryExport.cs now
classifies exactly Packages/manifest.json and Packages/packages-lock.json as
project-owned paths before applying package-asset resolution. The actual Resolve
method passed a small non-Unity compiled probe: both real project manifests bypass
PackageInfo, known package root/file resolve, unknown package still fails. The first
probe runner hit a GBK stdout/BOM printing error before executing the probe; its log
is preserved and the runner now uses explicit UTF8. The repair has NOT been
installed or run in Unity. The archived prepared/executed exporter remains the
failing version. No Runtime code change, no tuning, no new fixture matrix.

Submit this real failure and candidate to actual GPT6Pro. Any subsequent launch
needs a new reviewed bounded package and retains this failed attempt. Independent
guard review is requested specifically to prevent another input-only/test loop.
