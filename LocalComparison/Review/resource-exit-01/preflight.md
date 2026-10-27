# Read-only resource-exit preflight

No runtime change or new Unity test has been made for this investigation yet. These are source observations, not attribution of the warning.

- Both denoise-03 scene logs report 10 Persistent allocations and 10 unreleased D3D12 buffers at process exit. Native buffer names are generic (`Buffer-16-...`), not sufficient to identify the owner.
- HybridLumenGIResourceRetirement.Retire adds a pending ticket and owned destroy callback. EndContext first polls prior tickets, then appends/submits a fence for pending tickets. No other code polls its owned list. There is no no-camera/editor-idle/shutdown hook in this class.
- Thus two separate paths need evidence: a submitted fence that later passes without another polling context; and a ticket added after the final context that has never been submitted. Neither permits unconditional release merely because the frame count advanced.
- RendererFeature.CameraState.Dispose retires software geometry buffers. HardwareBackend.Dispose retires six optional attribute buffers plus an RTAS. Do not assume these equal the ten reported allocations. RayTexturePool, HitMaterialPass and ReceiverIdentityPass have their own retained ownership and completion checks.
- Existing AssetPageRetirementPump.Update only pumps streamed representation/page work. This is a possible existing integration point if ownership evidence requires a runtime idle pump; it is not itself evidence that the other queues drained.
- ComparisonCapture.Finish calls EditorApplication.Exit directly during Play. Normal Play exit must be distinguished from this harness path before calling the symptom a product shutdown leak.
- Installed com.unity.collections@88d5bf65ce66/Unity.Collections.Editor/CLILeakDetectionSwitcher.cs supports process environment UNITY_JOBS_NATIVE_LEAK_DETECTION_MODE=2, setting NativeLeakDetectionMode.EnabledWithStackTrace in InitializeOnLoadMethod. This can collect allocation provenance without modifying product algorithms or global Editor preferences.

Relevant API contracts checked against official Unity 6 documentation:

- https://docs.unity3d.com/cn/6000.0/ScriptReference/Graphics.CreateGraphicsFence.html : the fence follows previously sent drawing/dispatch/copy work, including immediately executed command buffers.
- https://docs.unity3d.com/ja/6000.0/ScriptReference/Rendering.ScriptableRenderContext.ExecuteCommandBuffer.html : recording in a ScriptableRenderContext is scheduled; actual execution occurs upon Submit.
- https://docs.unity3d.com/cn/current/ScriptReference/Graphics.WaitOnAsyncGraphicsFence.html : this API returns immediately on the CPU; it cannot by itself prove CPU-safe destruction.

Await Pro's finite diagnosis/fix plan before adding another execution matrix. Preserve all logs and fail-closed ownership behavior on unsupported or failed fences.
