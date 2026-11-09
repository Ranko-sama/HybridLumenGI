# Release174 动态图卡捕获材质复用

普通 Lit 的 `_BaseMap` 可以绑定 RenderTexture。即使 CPU 观察到的配置相同，图卡仍需重新捕获这张贴图的实时内容。Release173 把不可复用的图卡内容也判成捕获材质配置变化，因此在下一次 `Prepare` 销毁并重建同配置的捕获材质。Release174 分开这两个决策。来源签名或逐槽快照变化时仍走材质替换，动态内容独立触发图卡失效并等待原捕获额度。[SurfaceCache](../../../Runtime/HybridLumenGISurfaceCache.cs) · [来源快照](../../../Runtime/HybridLumenGIMaterialSource.cs)

复用 `ExactMaterialObservations`，用相同输入分别编译 Release173 和 Release174 的实际 SurfaceCache、MaterialSource 与捕获接线。Unity 对象和命令使用现有录制替身。普通 Lit 单槽只使用一张图卡，零额度帧夹在两次可捕获帧之间。

| 观察 | Release173 | Release174 |
| --- | --- | --- |
| 同一 RenderTexture、同配置，首次到下一次捕获 | 使用不同的捕获 Material | 使用同一个捕获 Material |
| 零捕获额度 | 图卡进入新代次且未就绪，待捕获 1 张 | 同左 |
| 恢复捕获额度 | 实际记录再次捕获，继续绑定原 RenderTexture，历史资格拒绝 | 同左 |
| `_Metallic` 改为 0.625 | 新 Material 使用当前值，旧 Material 走销毁 | 同左 |
| 换回静态纹理，再送入无效 MPB | 恢复静态来源资格。无效来源撤销图卡 | 同左 |

初次对照发现旧录制替身缺少后来接入的 Shadowmask 和场景 HLOD 接口。只为无烘焙光照、无 HLOD 输入补齐接口后，两版使用同一替身。旧版预期失败的首次进程退出超时，随后让同一断言正常返回失败码。Release173 仅在最后的相同配置复用断言失败，Release174 通过本用例。[定向用例](../../../Tests/StandaloneSurfaceCache/Program.cs.txt)

采用范围为 CPU 捕获材质配置与对象生命周期。此对照确认录制使用实时纹理引用，并保留动态图卡的重新捕获、就绪拒绝及配额。原生像素、帧时间和全阶段时间预算各自验收。
