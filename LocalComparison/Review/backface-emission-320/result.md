# 普通 Lit 发光面的正反面精确命中

原计划第 9 节／T2 的一个代表子项通过。在 Release254 同源工程中复用实际软件 BVH 和 DXR 查询。输入为单位变换的同一双槽网格，两个四边形源法线均为 −Z。`z=0` 的红色发光面使用 Cull Back，`z=1` 的蓝色发光面使用 Cull Off。两种普通 Lit 材质均为不透明、零漫反射，发光来自 `_EmissionColor`。每面各有一条正面和一条背面射线，两条背面射线各自避开另一面的干扰。[Release254 同源工程](../feature-disable-retirement-317/delivery.json)

| 固定输入 | 精确软件 BVH | 实际 DXR |
| --- | --- | --- |
| Cull Back 正面 | 命中槽 0，线性 Le = (1, 0, 0) | 相同 |
| Cull Back 背面 | 未命中，flags = 0 | 相同 |
| Cull Off 正面 | 命中槽 1，线性 Le = (0, 0, 1) | 相同 |
| Cull Off 背面 | 命中槽 1，线性 Le = (0, 0, 1) | 相同 |

命中均核对实际源实例、三角、法线、面向和材质有效标记。两后端均取得已知原材质，实际回退数量为零。测试在 Unity 6000.0.85f1、DX12、RTX 2080 Ti 上正常退出。采用限该静态输入的精确命中及源发光值，面积采样、双面着色法线、图卡和最终照明继续各自验收。退出日志仍有一条 Unity D3D12 的 1 MiB scratch buffer 提示，归因未定，资源寿命另按 G4／G5 验收。[原始读回](result.json) · [本机运行与退出回执](<I:/Unity test/Comparison/BackfaceEmission320>)
