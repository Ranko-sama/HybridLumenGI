# First native attempt failed before camera movement

The single DX12 Editor Play process exited 1 after one complete request. It never
reached the prescribed moving frames and produced zero previews. Both the first
execution audit and first temporal analysis retain failure. No TAA correspondence,
disocclusion, output quality or timing result is accepted from this attempt.

Unity reported undeclared identity inputs/types in `CameraMotionTaaCopy.hlsl`
while compiling the ordinary `CSUpdateCache` and `CSTrace` entries. The observer
include was appended to each whole compute asset, but only its own kernel pragma
enabled `HLGI_RECEIVER_IDENTITY`. Other entries still parsed the observer function
without those declarations. The three observer-only DXC checks could not detect
this omitted configuration. This is a temporary observer integration error, not a
demonstrated product temporal defect.

The original scene, 48-frame contract, 264 points, 12+45-vector ABI, math sources,
first frozen staging and first compiler results remain unchanged. The pre-native
nearest-candidate sidecar is also preserved: it addressed the separate Halton
half-pixel ambiguity without changing the GPU observer or output thresholds.

The `finally` restoration completed. All 112 product files match the current
13f31ec product source, all nine staged files were archived byte-for-byte, and
the temporary `Assets/CameraMotionTaa01` root was removed. See
`failure-restoration-audit.json`, `execution-receipt.json`, `analysis-first.json`
and the original `unity.log`.

The correction belongs to a new `camera-motion-taa-response-02` package. It will
isolate identity-dependent observer declarations and check both identity-on and
identity-off complete entries before any new native attempt. This package's
failure is not overwritten or reclassified.
