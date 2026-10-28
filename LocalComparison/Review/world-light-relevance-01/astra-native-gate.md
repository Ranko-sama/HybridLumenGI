# Astra pre-native gate — world-light-relevance-01

Reviewed on 2026-10-28, after candidate deployment/preparation and before installation, the unique build, or the unique Player attempt. This review read source, the actual prepared files, existing logs and hashes. It did not execute a compiler, test fixture, Unity, the Player, or the result analyzer.

**Decision: retain this finite harness and proceed to the authorized single build, then the single visible DXR run only if the build/source gate passes. No concrete prebuild blocker was found.** The limit remains 64 target-camera frames, one final light-buffer readback, and no second attempt or extended warmup if coverage fails.

At the review boundary, `instrumentation/installed.json`, `build-attempt.json`, and `native-window/attempt.json` were absent. All 111 manifest product sources matched both the workspace and the deployed product, and all five prepared files matched their manifest hashes. Instrumentation manifest SHA256: `757F250541353ADFF1D0F14927057B7F81EBF01397510E867D591C82D79BA4A7`.

The earlier implementation-review prerequisite has an observed result now: `capture-bounds-tests.log` reports 19,995 assertions in 13 existing actual-source SurfaceCache scenarios. The added assertions check disabled/force-hidden explicit-mesh bounds versus stale renderer bounds, frozen getter values after live transform mutation, and absent-slot rejection. The logged runtime SHA256 matches the reviewed SurfaceCache source, `3EBC2B40B59D333516630710D915E804B3DFC4BE09685E9773F016382AC94584`. This remains adapter evidence, not native capture or GPU coverage.

The prepared execution path is appropriately limited:

- RuntimeAuditEntry configures the existing Functional scene before Start, disables RuntimeAuditProbe, and retains only one initial deformation RequestCapture. No scene regeneration, streaming setup, original mixed-event sequence, or image capture is introduced.
- Three new ordinary point lights are assigned their roles in actual InstanceID discovery order. Existing lights are disabled. The input freezes the new roles, native packed bytes, capacity two, mode enabled, fixed camera/door and target point. Subsequent Apply calls check the same three inputs and bypass the original door/light/camera/timing actions.
- The current fixed Green wall source is a cube; the chosen local X-minus face-center expression matches the declared target. The relevant light is one unit from that point with range ten. This proves an intended range intersection; the package does not use it as a brightness, visibility or energy oracle.
- Existing ComparisonCapture provides the consecutive target-camera receipts. Its original final-frame branch closes at the following Update; the prepared branch disables the camera before waiting and does not re-enable it during restoration. The analyzer requires logical receipts 0 through 63, consecutive engine frames, zero captures/errors and one final binding receipt. Its explicit handling of `incomplete-probe` is consistent with the existing harness reserving `completed` for 720 frames; it is not a frame-count exemption.

The final receipt is attached to the relevant actual commands:

- The hook is in ExecuteTransport, after possible exact-backend/material fallback, after `_HLGI_LightCount` is set from `d.lightCount`, and after the same `state.lights` buffer has been bound to CSUpdateCache and CSTrace. The recorded hardware flag is the post-fallback Work flag.
- The hook receives the actual Work frame and inverse matrix, reads the current state's recorded selection/domain, and copies the same prepared traversal/capture bounds used by the product. It makes no new ray, shader dispatch, depth observation or additional geometry discovery.
- Only logical 63 may enqueue the readback. A duplicate binding fails the fixture. It requests the complete existing 32-by-80-byte light buffer on the existing command buffer. Pending responsibility is reserved before recording that request; exceptions are retained and cannot become a completed receipt.
- The close path waits for recorded requests outside camera rendering, then requires exactly one binding and completed readback with pending zero. Close errors are recorded while the original capture cleanup and failure exit continue. No observer-owned GPU allocation is introduced.

The analyzer's acceptance claims are bounded correctly. It compares the first active 80 bytes against the relevant light's native packed record and requires an active count of one. The remaining 31 records are not treated as initialized or valid. `boundCount` is explicitly the actual C# binding argument, not a GPU constant-buffer readback. The range oracle independently evaluates distance to the recorded domain and verifies the target intersection; finite screen samples corroborate the recorded matrix, while the reviewed interval implementation supplies the all-pixel argument. Every recorded prepared world extent must be contained. These checks establish admission and upload for this input, not GPU radiance consumption or whole-scene quality.

Build/run provenance uses the existing bounded mechanisms: one attempt marker and fresh output directory, actual build inputs matched to the five prepared files plus product manifest, restored temporary sources, complete built-product inventory checked before and after the Player, ordinary visible-window launch without batchmode, and the existing native log signatures/accounting. Relevant native failures remain blockers; generic UTP aggregate statistics are not newly promoted into a leak investigation. The build uses a Development/Mono Windows Player; no Release or additional-platform claim follows.

Reviewed harness SHA256 values:

| File | SHA256 |
|---|---|
| WorldLightRelevanceMode.cs | 4837C92BBC1FBA952406671EA7AD7194C7776D98CA9D1A9CE40D3569E4FAD57D |
| prepare-world-light-relevance.py | 940E3B1C8A3601EE8BD08AEB53E6BBBBE7B2C93280AB2F5249AF42ED267ED1F6 |
| analyze-world-light-relevance.py | E18D395A90C12A3F3D3842C24CC1EAF4E8E9F6329D3D7CE4C26C64EF6D394F98 |
| build-world-light-relevance.ps1 | 6A23D9070AA2AD3D8D006D8F1C293DF1CD9CAC56E79AC298D3AE8B6AEC89DEED |
| run-world-light-relevance.ps1 | AB57328455167F110AF941E4DD17DB36FC29742ECF6E9F912693661A2B874178 |
| capture-bounds-tests.log | D3D6CD8BA6B206157846F4D581B6E7905F520F91D6C3D987E53FF99961BD82A4 |

No additional fixture, shader compilation matrix, native comparison, image capture, timing run or lifecycle instrumentation is requested by this gate. A real build/run failure must retain the attempted evidence and return to review rather than be converted into permission to retry.
