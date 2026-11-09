# Release175 代理接回同对象的新 Renderer

旧 Renderer 被 `Destroy` 后，代理字段可以保留一个 Unity 判空的托管包装。Release174 的待校验和重新启用用 CLR 空值判断补源，形变组件却已能通过 `GetComponent` 找到同对象的新 Skin。Release175 使两个代理入口都按 Unity 的空值判断补源。[实现](../../../Runtime/HybridLumenGIProxy.cs)

Unity 6000.0.85f1 Editor Play。两次从同一 Release174 工程执行同输入，候选仅替换代理源码。两个对象从旧 MeshRenderer 开始，运行时 `Destroy` 后通过 `AddComponent` 装入新 Skin。观察器直接驱动现有自动 `BakeMesh` 和快照发布回调，两份新 Mesh、SDF 和 charts 均实际发布后，第一件对象通过 `SerializedObject` 编辑粗糙度触发待校验，第二件对象正常重新启用。整个替换过程不写私有来源字段或调用 `SetSources`。[旧版原始记录](baseline.json) · [修复版原始记录](fixed.json)

| 入口 | Release174 | Release175 |
| --- | --- | --- |
| 待校验后首次场景准备 | 已发布的代理继续使用 Collider，中心 X 为 −5 | 当前 Renderer、Mesh、SDF 和 charts 均匹配新快照，中心 X 为 3 |
| 重新启用后首次场景准备 | 已发布的代理继续使用 Collider，中心 X 为 15 | 当前 Renderer、Mesh、SDF 和 charts 均匹配新快照，中心 X 为 23 |

两次均正常退出。待校验入口在场景准备前有一份请求，处理后归零。重新启用入口没有待校验请求。采用范围是自动接源、真实快照发布以及实际 Scene 对这份快照的使用。观察器没有提交相机渲染，原生射线命中、可见画面和形变延迟仍按原条件验收。旧 Renderer 销毁且无新来源时的 Collider 后备有独立实机依据。[Collider 后备](../destroyed-renderer-fallback-190/result.md) · [既有蒙皮命中范围](../native-skinned-hit-175/result.md)
