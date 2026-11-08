# 精确材质的足迹 LOD 与 mip 偏移次序

原 T2 的共用采样合同按驻留范围选择 mip。Release147 先把正常正足迹的 LOD 夹在纹理尺寸范围，采样时再加 `mipMapBias`。这会让正偏移把本应留在首级的足迹移到下一级，也会让负偏移提前离开末级。修复把有限原始 LOD 交给现有采样器，先加偏移，再按实际驻留 mip 夹取。零半径、恒定 UV 与近切线分支沿用原定义。[Direct3D LOD 计算顺序](https://microsoft.github.io/DirectX-Specs/d3d/archive/D3D11_3_FunctionalSpec.htm#LODCalculations)

实际 `CSHardwareMaterialsCoverage` 使用单位 XY 三角、对应 UV、垂直射线、4×4 完整 BaseMap 和已启用的 alpha-test。三个 mip 的 alpha 分别为 1、0、1，阈值为 0.5。已指定 BaseMap，因此覆盖判定依赖实际纹理采样。两版使用同一二进制输入及本机发行工程的 URP 17.0.4 着色器头文件，独立预期来自原有数值投影和纹素采样 oracle。

| 足迹直径与偏移 | 预期 mip | Release147 `known / covered` | 修复后 `known / covered` |
| --- | ---: | --- | --- |
| 1/4 纹素，+1 | 0 | 1 / 0 | 1 / 1 |
| 16 纹素，−1 | 2 | 1 / 0 | 1 / 1 |
| 零半径，+1 | 1 | 1 / 0 | 1 / 0 |

两侧覆盖入口均在 D3D12 WARP 上取得完整读回。完整材质入口的旧、候选 DXIL 均编译成功。旧版完整入口在围栏等待上限结束时未得到输出，完整颜色仍缺执行结果。本次结论覆盖实际共用材质采样链上的覆盖决定。Unity 贴图上传、物理 GPU、DXR 遍历和画面效果继续分别验收。[现有覆盖入口](../../../Tests/StandaloneHardwareMaterials/HardwareMaterialsHarness.hlsl) · [独立预期与固定输入](../../../Tests/StandaloneHardwareMaterials/HardwareMaterialsOracle.mjs)
