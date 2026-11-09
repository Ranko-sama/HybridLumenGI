# Base 与 Overlay 同栈的 GI 历史

Release190 同源代码 `a1271c1d` 在 Unity 6000.0.85f1／URP 17.0.4 的 DX12 Editor Play 中复用已保存的双网格场景。用 URP `StandardRequest` 走实际相机栈。Base 固定俯视地板，相机输出和 GI 均为 128×64。对照帧和叠加帧使用同一 Base、目标、Renderer 和地板输入。紫色标记只在 Overlay 的图层上绘制。

| 引擎帧 | Base 工作帧 | 实际后端 | 相机栈 | 标记中心 RGB | Base 地板 16 个 GPU 历史长度 | GI 相机状态 |
| ---: | ---: | --- | --- | --- | --- | --- |
| 20 | 18 | DXR | Base | 171／171／171 | 全部 16 | 1，Base |
| 21 | 19 | DXR | Base 与 Overlay | 255／0／255 | 全部 16 | 1，Base |

实际 Overlay 完成回调和输出中的紫色标记均在帧 21。该帧的相机状态仍来自同一 Base 实例，缓存代次为 5。固定地板区域使用相同的 4×4 GI 纹素，直接读回实际提交后的 moments 纹理。采用范围是这个真实同栈的 Base 历史隔离和原生 Overlay 绘制。[Base 原图](base.png) · [叠加原图](stack.png) · [实际读数](result.json)

Unity 正常退出。退出过程中有一份等待退休的资源，随后空闲栅栏完成，末次日志的已拥有和待退休计数均为零。原独立双 Base 切镜记录分别保留。普通 Player、其他叠加配置、Frame Debugger 记录与完整 G3 分别验收。[Unity 退出](native-exit.json) · [实机日志](<I:/Unity test/Logs/StackHistory221.log>) · [双 Base 切镜](../multi-camera-history-01/result.md)
