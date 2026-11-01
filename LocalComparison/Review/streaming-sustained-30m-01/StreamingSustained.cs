using System;
using System.IO;
using HybridLumenGI;
using UnityEngine;

// Local measurement build only. Drive the ordinary buttons' public methods and
// save the existing sample ledger at each endpoint. No rendering or extra queries.
[DefaultExecutionOrder(30000)]
public sealed class StreamingSustained : MonoBehaviour
{
    private const int DwellSeconds = 30, Endpoints = 60;
    private HybridLumenGIUnifiedSample sample;
    private string output;
    private double warmStarted, started, next;
    private int endpoint, enteredFrame, lastWorkFrame = -1;
    private bool finished;

    [Serializable] private sealed class Row
    {
        public int endpoint, enteredFrame;
        public double elapsedSeconds;
        public string phase;
        public HybridLumenGIUnifiedSample.Ledger ledger;
    }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    private static void Install()
    {
        var args = Environment.GetCommandLineArgs();
        int index = Array.IndexOf(args, "-hlgiStreamingSoak");
        if (index < 0) return;
        try
        {
            if (index + 1 >= args.Length || !Path.IsPathRooted(args[index + 1]) || Directory.Exists(args[index + 1]))
                throw new InvalidOperationException("A fresh absolute output directory is required.");
            var samples = FindObjectsByType<HybridLumenGIUnifiedSample>(FindObjectsSortMode.None);
            if (samples.Length != 1 || samples[0].gameObject.scene.path != "Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity")
                throw new InvalidOperationException("Expected the saved unified sample.");
            var driver = new GameObject("Fixed streaming route").AddComponent<StreamingSustained>();
            driver.sample = samples[0];
            driver.output = args[index + 1];
            Directory.CreateDirectory(driver.output);
            var input = driver.sample.GetComponent<HybridLumenGIUnifiedSampleInteraction>();
            if (input) input.enabled = false;
            driver.sample.ShowControls = false;
            driver.sample.MeasureVideoMemory = true;
            Application.runInBackground = true;
            Application.targetFrameRate = 30;
            driver.sample.GoNear();
            driver.enteredFrame = Time.frameCount;
            driver.warmStarted = Time.realtimeSinceStartupAsDouble;
        }
        catch (Exception e) { Debug.LogException(e); Application.Quit(1); }
    }

    private void LateUpdate()
    {
        double now = Time.realtimeSinceStartupAsDouble;
        if (finished || now < next) return;
        try
        {
            var ledger = sample.CaptureLedger();
            bool outside = endpoint % 2 == 1;
            bool settled = outside
                ? ledger.requestedRepresentation == "none" && ledger.availableRepresentation == "none" &&
                  ledger.visibleMembers == 0 && ledger.boundMembers == 0 && ledger.pagesReady == 0 &&
                  ledger.pageConsumerReferences == 0 && ledger.pageBundleBytes == 0 && ledger.pageResidentBytes == 0
                : ledger.requestedRepresentation == "details" && ledger.availableRepresentation == "details" &&
                  ledger.status == "complete details published" && ledger.visibleMembers == 3 && ledger.boundMembers == 4 &&
                  ledger.publicationEngineFrame >= enteredFrame && ledger.pageResidentBytes > 0 && ledger.pageConsumerReferences > 0;
            settled &= ledger.requestEngineFrame >= enteredFrame && ledger.pagesLoading == 0 && ledger.pagesReleasing == 0 &&
                ledger.pagesFailed == 0 && ledger.pageIoBytesInFlight == 0 && ledger.pageActiveOperations == 0 &&
                ledger.pageRetiringLeases == 0 && ledger.cameraGi != null && ledger.cameraGi.frame > lastWorkFrame;
            if (!outside) settled &= ledger.actualBackend == "DXR";
            bool warmExpired = endpoint == 0 && now - warmStarted >= 180;
            if (endpoint == 0 && !settled && !warmExpired) { next = now + 1; return; }
            if (endpoint == 0)
            {
                started = now;
                Debug.Log($"HLGI streaming route: {Application.unityVersion}, {SystemInfo.graphicsDeviceName}, " +
                    $"{SystemInfo.graphicsDeviceType}, {Screen.width}x{Screen.height}, requested FPS {Application.targetFrameRate}, " +
                    $"vSync {QualitySettings.vSyncCount}");
                if (Screen.width != 960 || Screen.height != 540 || ledger.requestedMeasureGpuCost || ledger.requestedAdaptiveGpuBudget)
                    throw new InvalidOperationException("Expected the 960x540 sample with timing and feedback off.");
            }
            var row = new Row { endpoint = endpoint, enteredFrame = enteredFrame, elapsedSeconds = now - started,
                phase = outside ? "outside" : (endpoint == 0 ? "initial-near" : "near"), ledger = ledger };
            File.AppendAllText(Path.Combine(output, "endpoints.jsonl"), JsonUtility.ToJson(row) + "\n");
            if (warmExpired) throw new InvalidOperationException("Initial readiness exceeded the 180-second warm-up window.");
            if (!settled || now - started >= (endpoint + 1) * DwellSeconds ||
                ledger.retirementFailed != 0 || ledger.retirementUnknownSubmissions != 0 || ledger.retirementSubmissionUncertain)
                throw new InvalidOperationException("Endpoint incomplete at " + endpoint + ". Inspect its saved ledger.");
            lastWorkFrame = ledger.cameraGi.frame;
            if (endpoint == Endpoints) { finished = true; Application.Quit(0); return; }
            endpoint++;
            enteredFrame = Time.frameCount;
            if (endpoint % 2 == 1) sample.Leave(); else sample.GoNear();
            next = started + endpoint * DwellSeconds;
        }
        catch (Exception e) { finished = true; Debug.LogException(e); Application.Quit(1); }
    }
}
