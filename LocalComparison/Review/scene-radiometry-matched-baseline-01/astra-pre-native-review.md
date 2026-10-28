# GPT-6 Astra Max independent pre-native review

Existing requested guard /root/astra_guard reviewed the actual exporter, solver,
observer adapters, comparator and deployment plan. No additional agent was spawned.
All findings below were addressed before the only native launch, not after seeing
new product differences:

- Reject unexplained metallic/specular/occlusion texture keywords even if texture
  references are empty. Preserve inactive HDR emission raw, not a falsely converted
  interpreted value. Keep proxy source/tint/emission fields in runtime source hash.
  Reject point-light cookie and non-Realtime mode.
- Cache Ng is5+5-bit oct. A universal0.02 raw-normal tolerance would reject legitimate
  source-axis quantization. Independently encode/decode source triangle normal,
  check0.002 representation error, and preserve raw geometric discrepancy. GI Ng
  and Ns remain0.02. Tie rule is fixed nearest-even before capture.
- Compare source triangles' coplanarity with source normal, not quantized observation.
- Reject inconsistent source winding rather than reversing triangles to repair it.
- Scheduled flag is actual cache change.w, not prepared irradiance.a/sample count;
  compare against CPU scheduling mask. Unknown raw alpha is missing measurement,
  never measured black. Preserve raw/history/filtered alpha and skip invalid numeric
  differences or complete-window averages.
- Native acceptance includes known unresolved-retirement and D3D12 Unreleased
  signatures, not exit status alone.

Final guard conclusion: after the source-normal coplanarity fix, no remaining
specific blocker to the unique120frame run.103/119 gates precede advance/Finish
in normal Update; target inputs exclude radiance; rho/PDF and conservative tail
are consistent; deployment restoration is explicit. Do not add more fixtures.
After the run check source/receipts/exit, then execute fixed six-point integration.
Keep wide uncertainty or real failures open.

Preflight records: compile01 failed on two exporter API types, fixed in compile02;
math01 failed on an expected-value decimal typo, fixed in math02. math03 added
source-derived encoded-normal correspondence; math04 added winding rejection;
math05 checked differently rooted coplanar triangles with quantized Ng. All later
checks passed. Each failure/success was recorded for actual GPT6Pro review.
Unchanged HLSL/DXC/reference include hashes reuse previous preflight; no broad
shader matrix or second Unity process is authorized for this package.
