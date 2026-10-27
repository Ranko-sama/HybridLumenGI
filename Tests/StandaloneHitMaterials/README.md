# Hit material evaluation execution test

Run `Tests/Validate-HitMaterials.ps1` using the existing Windows x64 VS2022,
Windows SDK DXC, Node, and fixed Unity Graphics include cache. No dependencies
are installed. `-IncludeRoot` selects the cache; its `Packages/` sources are copied
to a fresh TEMP directory and their hashes recorded. The development baseline is
Unity Graphics `feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53` (URP 17).

The harness includes the actual `HybridLumenGIHitMaterials.hlsl` evaluator and
`HybridLumenGIRayTextures.hlsl` sampler. The C++ host uploads real structured
metadata, source mip texels, and 240-byte material records through descriptor
tables, executes their DXIL on D3D12 WARP, and reads the results back. No material
or texture lookup function is replaced. Input/output and material ABI offsets
are checked against the actual compiler listing.

The independent JavaScript oracle evaluates weighted texture-image samples and
Lit material equations in double precision. Cases cover keyword combinations,
per-map LODs, Base/Detail ST order, parallax, metallic and specular map replacement
of constants, alpha and smoothness channels, occlusion, emission, normal scale,
detail RNM, proxy tint/emission, defaults, stale or unready assigned textures,
irrelevant missing textures, nonfinite dependencies, and deterministic randomized
inputs. The same tests run with RGorAG, RGB, and AG normal decoding. Unassigned
normal maps represent the platform's neutral bump default; assigned textures
are decoded using the selected compile-time encoding.

Coverage returns unknown conservatively as `covered=true`; known alpha rejection
uses only its dependencies. The material result returns the Lit BRDF diffuse
share before transport's energy cap, and leaves tangent-space normals unnormalized
until the caller applies the correct TBN. Specular/environment switches do not
change material F0 or diffuse reflectance. Alpha-discarded candidates are not
committed by this evaluator; the later ray traversal must honor coverage.

This validates standalone shader execution over supplied mip buffers. It does
not validate Unity importer/color uploads, source Texture.Load copies, real DXR
candidate/committed traversal, upstream ray footprint or TBN construction,
render-graph lifetime, native sampler bit parity, anisotropy, physical GPU timing,
or the final rendered image. Those are separate integration gates. WARP absence
is unavailable, never a pass. Failed runs remain in their original TEMP folders.
