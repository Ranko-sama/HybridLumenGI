# 代理重新启用时接回替换后的 Collider

活动代理停用期间，原 Collider 可以销毁并由同对象的新组件替换。Release166 重新启用时用 CLR 空值判断补源，已销毁 Collider 的托管包装会挡住重新获取。修复使启用入口按 Unity 空值判断补源。

Unity 6000.0.85f1 的 Editor Play。两次使用相同的普通运行时启停、`Destroy` 和 `AddComponent`。初始 BoxCollider 按中心 3 发布，停用后代理退出。确认原组件实际销毁后，给同一对象加入中心为 6、X 半尺寸为 1 的新 BoxCollider。重新启用前后待校验标志均为零。[Release166 读数](baseline.json) · [修复版读数](fixed.json)

| 首次重新启用与准备 | Release166 | 修复版 |
| --- | --- | --- |
| 启用前 | Unity 判缓存引用为空，CLR 判非空，`GetComponent` 能取得替换组件 | 相同 |
| 正常启用后 | 沿用已失效的 Collider 引用 | 启用时已绑定新 Collider |
| 首次场景准备 | 退回中心 55，代理未发布 | 代理与场景槽中心均为 6，X 半尺寸为 1，当次发布 |

序列使用真实场景准备。初始通过公开接源接口绑定有效 Collider，停用后的替换不直接写入代理引用，也不额外调用刷新。两次观察均正常退出。证据限此 Collider 重新启用入口。普通 Player 画面和其他组件来源按原条件验收。
