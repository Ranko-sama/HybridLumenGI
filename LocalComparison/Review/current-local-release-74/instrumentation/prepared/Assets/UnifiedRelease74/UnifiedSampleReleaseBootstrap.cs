using System;
using HybridLumenGI;
using UnityEngine;

// The ordinary executable has no automatic capture. Explicit verification is opt-in.
[DefaultExecutionOrder(-30000)]
public sealed class UnifiedSampleReleaseBootstrap : MonoBehaviour
{
    void Awake()
    {
        string[] args = Environment.GetCommandLineArgs();
        if (Array.IndexOf(args, "-unifiedSampleVerify") < 0) return;
        try
        {
            int at = Array.IndexOf(args, "-unifiedSampleOutput");
            if (at < 0 || at + 1 >= args.Length) throw new ArgumentException("Missing verification output.");
            var interaction = UnityEngine.Object.FindFirstObjectByType<HybridLumenGIUnifiedSampleInteraction>();
            if (interaction) interaction.enabled = false;
            var host = UnityEngine.Object.FindFirstObjectByType<UnifiedSampleHost>(FindObjectsInactive.Include);
            if (!host) throw new InvalidOperationException("Dormant verification Host is missing.");
            host.PrepareRuntimeVerification(args[at + 1]);
        }
        catch (Exception error) { Debug.LogException(error); Application.Quit(1); }
    }
}
