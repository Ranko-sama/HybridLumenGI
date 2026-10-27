# Hardware surface frame and texture footprint

Run `Tests/Validate-HardwareSurface.ps1`. The runner compiles the actual runtime `HybridLumenGIHardwareSurface.hlsl` and normal helper into DXIL, executes on D3D12 WARP, reads the result buffer and compares against independent double precision geometry calculations. The binary input is 400 bytes and output is 96 bytes; DXIL listings check the layout. Every run retains before/after source hashes, command logs, shader listings, native host, fixture, readback and oracle results in a unique TEMP directory.

The current fixture contains 790 cases: nonuniform scales, shear, mirrored transforms, varying vertex normals/tangents, perspective and constant per-vertex view directions, normal-map reconstruction, arbitrary rectangular texture dimensions, UV tiling/flipping, projected cone radii, invalid input and degenerate geometry. The footprint oracle projects a ray-perpendicular disk to the triangle, solves barycentric coordinates using a Gram system, then maximizes texel-space diameter over 2,048 directions. It does not copy the shader's UV-gradient/covariance eigenvalue implementation.

The runtime normal-map basis follows URP's vertex-normalized N/T interpolation and fragment bitangent construction. Parallax is different: the stock Lit variant calculates each vertex's tangent-space viewing direction and interpolates those three vectors. The caller supplies three world-space vertex viewing directions, normally origin minus each transformed vertex for perspective queries, or the same direction for an orthographic view. The explicit regression has normals Z/Y, tangents X/Z and equal weights; all three resulting view components must equal `1/sqrt(3)`.

Earlier 788-case reports used the wrong fragment-stage parallax view construction. Their passing result did not establish URP parity; the independent review found a missing variant condition in both implementation and oracle. Those reports remain historical evidence, superseded by the 790-case fixture. The added grazing-angle case also checks a UV transform that eliminates the only varying coordinate: its LOD remains zero.

This is **not** Unity execution, DXR candidate traversal, native imported-mesh binding, image acceptance or a physical-GPU performance result. The helper requires world-space ray-cone radius at the hit. Propagating that radius/spread through the complete transport pipeline is separate integration work; the test does not claim it is connected.

References used to check operation order:

- [URP LitForwardPass, fixed Graphics commit](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl)
- [Vertex normal inputs, same commit](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl)
- [Parallax mapping, same commit](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl)
- [Improved Shader and Texture Level of Detail Using Ray Cones](https://research.nvidia.com/publication/2021-04_improved-shader-and-texture-level-detail-using-ray-cones). The implementation explicitly defines its radius and uses diameter `2*radius`; it does not reproduce or claim the paper's complete transport-cone update scheme.
