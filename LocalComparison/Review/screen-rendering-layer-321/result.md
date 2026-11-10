# 屏幕与世界表面按已知 Rendering Layer 匹配

原计划 T2／第 9 节的同源匹配修复。普通 Lit 前板没有世界代理时，短探针可能命中相隔 0.01 m、法线相同的后板。Release254 在两板 GameObject 层相同时仍允许匹配，即使两端的 Rendering Layer 遮罩已知且不同。屏幕出射会借用后板的世界缓存，接收点也可能借用其引导。[此前 GameObject 层修复](../screen-world-layer-308/result.md) · [屏幕匹配源码](../../../Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl)

修复让两个屏幕入口都传入捕获的整数策略。世界策略标记遮罩是否来自真实 Renderer。两端遮罩可比较且不同时，探针匹配失败，屏幕自身出射继续参与。零遮罩是有效输入，无 Renderer 代理的默认遮罩仍作为原照明后备。[世界策略源码](../../../Runtime/HybridLumenGIScene.cs)

复用第 308 项的 D3D12 WARP 入口，执行实际匹配函数和 `TraceScreen`，固定屏幕交点、探针命中、直接光与缓存输入。三组 GameObject 层位均为 2，出射为线性 RGB。

| 屏幕／世界策略 | Release254 出射 | 修复后出射 | 缓存读取，旧 → 新 |
| --- | --- | --- | --- |
| 真实遮罩 8／0，前后板相隔 0.01 m | (0.25, 0.50, 0) | (0.25, 0, 0) | 1 → 0 |
| 真实遮罩均为 8，同一表面 | (0.25, 0.50, 0) | (0.25, 0.50, 0) | 1 → 1 |
| 屏幕遮罩 8，无 Renderer 世界代理使用默认 1 | (0.25, 0.50, 0) | (0.25, 0.50, 0) | 1 → 1 |

三组屏幕命中均有效，距离均为 1。实际 C# Scene 驻留宿主也核对了策略上传、零遮罩与无 Renderer 默认值。修复已进入 Release255。采用范围为同源匹配与受控出射，整景画质和原生 GPU 成本继续按原条件验收。[WARP 读回](result.json) · [策略上传用例](../../../Tests/StandaloneBvh/SceneProgram.cs.txt) · [同源交付](delivery.json)
