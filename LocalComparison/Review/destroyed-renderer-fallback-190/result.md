# 销毁 Renderer 后的 Collider 后备

Release165 的活动代理缓存了已销毁 MeshRenderer 的托管包装。该包装在 Unity 中判空，仍能通过 C# 类型检查。正常场景准备尝试读取它的边界，导致当前相机的准备中断。修复把已失效的来源归一为空，边界、Shadowmask 和场景下游都使用有效 Renderer 查询。

Unity 6000.0.85f1、DX12 Editor，单 Game Base 相机显式提交 128×64 目标。场景有两个实际 DXR 精确对象和一张活动 Shadowmask。受影响代理同时有一个有效的偏心 BoxCollider。首次提交后正常调用 `Destroy`，等原 Renderer 的销毁实际生效，再提交同一台相机。两版均确认组件已移除、托管包装仍非空、Collider 仍有效。[Release165 读数](baseline.json) · [修复版读数](fixed.json)

| 观察 | Release165 | 修复版 |
| --- | --- | --- |
| 帧 4，原 Renderer 有效 | 同一相机实际录制 DXR，两个对象均是精确成员，受影响对象中心为 2 | 相同 |
| 帧 5，Renderer 已销毁 | `Scene.Prepare` 读取已销毁对象的 `bounds` 时抛出 `MissingReferenceException`，传输记录停在帧 4 | 当前准备和传输记录均为帧 5，后端仍为 DXR |
| 帧 5，Collider 与另一对象 | 当前准备中断 | 受影响对象按 Collider 发布，场景槽和 BVH 中心均为 6，X 半尺寸为 0.75。另一对象继续是精确成员。 |

修复版该次提交的 Shadowmask 数据有效，受影响对象的代理来源和场景 Renderer 查询均返回 CLR 空引用。实际精确成员和后备成员各一个，分别核对到原对象。两次观察都正常退出，旧版异常记录保留。

证据覆盖已绑定 Renderer 销毁后，现有 Collider 后备和同一相机故障隔离。重新启用、自动绑定新 Renderer、像素效果及其他平台分别按原条件验收。
