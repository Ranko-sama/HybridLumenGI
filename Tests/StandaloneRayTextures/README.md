Run `Tests/Validate-RayTextures.ps1` with existing Windows x64 VS2022/CMake, DXC and Node. It builds in a unique TEMP directory and installs nothing. Exit 2 means D3D12 WARP is unavailable, not a pass.

The test executes the actual `HybridLumenGIRayTextures.hlsl` sampler as DXIL on WARP. Descriptor-backed structured buffers provide real metadata and texel element counts; output is copied after a fence. An independent double oracle treats source mips as periodic/reflected images and sums nearest/tent-kernel samples.

The 36,934 cases include all three filters and 16 per-axis wrap combinations, nine fixed layouts, 64 random rectangular NPOT layouts and mip tails, 8,192 random UV/LOD queries, large/negative UVs, endpoints, nearest-mip ties, truncated chains, first-resident-mip clamping, stale handles and invalid metadata/data. Alpha zero is a known sample when data are valid; unknown returns false with zero output. The 64-byte metadata and source texels contain no material/chart approximation or second gamma conversion.

This establishes explicit isotropic LOD sampling only. Point/bilinear mip selection is `floor(clampedLOD + 0.5)`; trilinear blends adjacent levels. The stored anisotropy setting is intentionally unused. It does not establish native sampler bit parity, texture-copy/sRGB behavior, Unity streaming or resource retirement, DXR alpha acceptance, or physical-GPU performance.

Unity enum values were checked in UnityCsReference commit `1c2d7db69c060103b6dc087af725442d1efaef9c`, `Runtime/Export/Graphics/GraphicsEnums.cs`: Repeat 0, Clamp 1, Mirror 2, MirrorOnce 3. This test uses independent sampler code and no copied Unity source.

The current PowerShell 7 run passed 110,802 checks. The additional 720 cases exercise integer-bit RGBA16F pairs, odd rows, single-column layouts, mip tails and signed/HDR/subnormal half values against a quantized independent oracle. Buffer stride stays 16 bytes; the descriptor retains logical texel count while capacity checks use physical paired elements. This does not remove the stated isotropic-only limitation.
