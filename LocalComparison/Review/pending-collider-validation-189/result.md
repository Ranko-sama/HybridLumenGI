# 待校验代理重新获取同对象 Collider

Release164 在待校验入口用 CLR 空值判断补接 Collider。Unity 已判空的缓存引用仍可能有托管包装，因此新 Collider 可被 `GetComponent` 找到时，场景准备仍可能沿用没有 Collider 时的边界。修复使该处补源使用 Unity 空值比较。

Unity 6000.0.85f1。使用真实场景准备和同一条 Editor Play 序列。活动代理最初在世界 x=55，没有 Collider，距离上限为 10。用普通组件添加入口给同对象加入中心在世界 x=2 的 BoxCollider。随后通过 `SerializedObject` 只改粗糙度，以正常方式触发校验。整个序列没有写入私有源引用，也没有额外调用刷新。[Release164 读数](baseline.json) · [修复版读数](fixed.json)

| 观察 | Release164 | 修复版 |
| --- | --- | --- |
| 新组件查找与校验 | 找到同对象 Collider，Unity 判缓存为空，CLR 判非空，待校验标志为 1 | 相同 |
| 下一次场景准备 | 待校验标志归零，缓存仍为空 | 待校验标志归零，实际绑定新组件 |
| 场景边界与发布 | 代理中心仍为 55，未发布 | 代理和场景槽中心均为 2，当次发布 |

两次均完成观察并正常退出。证据覆盖活动代理在下一次场景准备消费待校验时的 Collider 补源。重新启用、Renderer 替换和画面效果各有独立条件。
