# Finite input qualification and color comparison

The original decoder failed its fixed world-space floor heuristic: 18 of the 27
receivers have reconstructed `abs(y)` above `64*float32_epsilon*worldScale`.
That first failure is retained. `decode_sampler.py`, `reference.py`,
`compare_native.py`, the physical source contract and all color thresholds remain
unchanged. The captured depth, origin, normals and directions remain unchanged.

An independent, input-only analysis found the ideal floor depth from the actual
VP differs from sampled depth by about `1.45e-8` to `3.97e-8`. Reconstructing the
actual depth with the actual invVP in double precision explains the receiver
height; the remaining GPU reconstruction discrepancy is at most `1.27e-7`
world units. `graphicsFormat=None` reports a depth-only target, not a D24 format.
The archived renderer/default Windows URP depth path uses `D32_SFloat_S8_UInt`.
No D24 quantization assumption enters qualification.

The separate qualifier computes the floor's screen-space depth plane by exact
rational inversion of the captured float32 VP. Direct3D snaps final raster
vertices to an eight-bit subpixel grid and interpolates using those snapped
positions. Its permitted float-to-fixed error gives a source bound of
`0.6/256` pixel per coordinate. For the depth plane `Z(x,y)=a*x+b*y+c`, convex
barycentric interpolation therefore changes depth by at most
`(abs(a)+abs(b))*0.6/256`. Clipping-created vertices lie on the same plane, so
the argument does not assume only the original unclipped triangles.
See [Direct3D 11.3 sections 3.2.4.1 and 3.4.1](https://microsoft.github.io/DirectX-Specs/d3d/archive/D3D11_3_FunctionalSpec.htm).

The resulting bound is `8.221721834327168e-8` for this capture. All 27 depths
lie in the source-derived interval. The qualifier also propagates the actual
depth through the actual invVP using exact rational interval endpoints and
outward float32 operation rounding with a one-ULP allowance. All reconstructed
receivers lie inside those intervals. It reuses every original identity, normal,
ray, bias, camera and target-neighborhood check; only the failed floor heuristic
is replaced by the completed raster-aware qualification, with an adapter hash.

This is an input-source consistency check. It does not claim to exhaust every
permitted forward projection or clipping implementation error, or establish
snapping as the only possible source of the measured depth difference. The
coefficient comes from the API precision rule and camera plane, not from the
measured discrepancy or GI RGB.

With that explicit qualification, the unchanged finite rectangle oracle and
unchanged half-storage intervals pass all 27 native color groups. The 216 rays
contain 47 independent rectangle hits; group hit counts cover zero through four.
The result rejects an extra pi divisor, swapped source channels, and unknown
measurements. A representative two-hit group expects `[.12,.06,.03]` and stores
`[.1199951171875,.05999755859375,.029998779296875]` after RGBAHalf narrowing.

The independent expected file was written before the comparator first opened
the product raw RGB. The 112 product files, eight observer files, extracted
sampler functions, actual scene geometry/MPBs/light/settings and completed
hardware-ready receipt matched their sources. There was no additional GPU run.
This result is conditional single-bounce raw `E/pi` consistency; it does not
certify default multi-bounce transport or final-image quality.

Evidence:

- `native/rays-native-qualified.json`: unchanged inputs and qualification.
- `native/finite-reference-qualified.json`: independent finite expected values.
- `native/finite-comparison-qualified.json`: source closure, per-group results,
  negative controls and hashes.
- Raw SHA256: `6ef6ffd15849aac4ee5cecf55f7c9a46beab4492588485fd415a7784dc8d4cd4`.
- Expected SHA256: `a5a4854c2414b9bcf72dd874f7b6cc420324ab9932d7d5b31724d0c179cf13be`.
