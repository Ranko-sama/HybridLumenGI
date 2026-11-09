# 普通 Lit 逐材质阴影通道

原第 9 节要求精确阴影查询遵守受支持材质的投影语义。按 Release194 源码，两个后端会应用 Renderer 投影策略、层、Cull 和覆盖，逐材质 `ShadowCaster` 开关未传入候选判断。Release195 捕获材质通道状态。关闭时将通过记录与绑定校验的阴影候选视为已知无覆盖，并把状态变化纳入既有阴影覆盖比较。普通表面查询独立应用材质的表面覆盖规则。[Unity 6 的材质通道 API](https://docs.unity.com/en-us/engine/6000.0/script-reference/unityengine/material/setshaderpassenabled)

实机观测使用 Unity 6000.0.85f1、Direct3D 12 和 RTX 2080 Ti。在同一 `MeshRenderer` 上使用两个普通 URP Lit 子网格，近板红、远板蓝，均为 `Cull Back`。只切换近板材质通道，Renderer 的投影模式始终为 `On`，几何版本固定。独立解压 Release194 工程后覆盖候选产品源码，在实际软件 BVH 和 DXR 批次中读取精确阴影和表面查询。

| 近板 `ShadowCaster` | 软件 BVH 阴影 | DXR 阴影 | 两后端普通表面 |
| --- | --- | --- | --- |
| 默认开启 | 近板，`t=1` | 近板，`t=1` | 近板，`t=1`，线性 RGB 约 `(0.96, 0, 0)` |
| 关闭 | 远板，`t=2` | 远板，`t=2` | 近板，`t=1`，线性 RGB 约 `(0.96, 0, 0)` |
| 重新开启 | 近板，`t=1` | 近板，`t=1` | 近板，`t=1`，线性 RGB 约 `(0.96, 0, 0)` |

关闭和重新开启都改变阴影覆盖比较的结果，恢复状态与初始覆盖一致。读回的材质均已解析，场景恢复后进程退出码为 0。Astra Max 同意在普通 Lit 的精确阴影资格与变化判断范围内采用。远处接收面的缓存刷新、像素恢复和收敛时间仍属 G3 验收。SDF／解析近似和自定义 shader 另按各自支持范围处理。[实际读数](result.json) · [进程回执](native-exit.json) · [直接光合同](../../../Documentation/DirectLighting.md)

DX12 Editor 退出时报告一项 1 MiB 的 `D3D12ScratchBufferInternal` 仍未释放。该资源的归属和寿命仍需单独判定。
