# 普通 Player 的 1919×1079 边缘覆盖

Release190 的产品源码 `a1271c1d` 在 Unity 6000.0.85f1／URP 17.0.4、RTX 2080 Ti 和 DX12 的普通 Win64 Release／None Player 中渲染保存的统一示例。观察包只在可编辑工程的独立解压目录加入取图入口。相机固定俯视现有房间地板，地板覆盖整个视野。相机实际输出是 1919×1079 的 RenderTexture，桌面窗口为 640×360。使用内置 Confidence 视图，原图像素保留了有效 GI 的置信度信号。

| 稳定端点 | URP 渲染比例 | 实际相机渲染尺寸 | 实际 GI 尺寸 | 原图尺寸 | 四边有信号像素 | 原图 |
| --- | ---: | --- | --- | --- | ---: | --- |
| 引擎帧 35 | 1.0 | 1919×1079 | 819×460 | 1919×1079 | 5,992／5,992 | [原图](scale-1.png) |
| 引擎帧 43 | 0.5 | 959×539 | 479×269 | 1919×1079 | 5,992／5,992 | [原图](scale-0.5.png) |

两个端点实际使用 DXR，四条最外边均没有空行、空列或黑边像素。边缘置信度显示字节分别为 173–220 和 172–220。屏幕计算按向上取整的工作组录制，Gather、Temporal 和 Filter 的像素入口按实际 GI 尺寸截断余线程。普通 Player 正常退出。日志保留启动时的 D3D12 info queue 查询提示 `0x80004002` 和 URP 点光阴影图集降采样提示。[计算录制](../../../Runtime/HybridLumenGIRendererFeature.cs) · [屏幕核函数](../../../Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl) · [原始读数](result.json) · [Player 日志](player.log) · [退出记录](native-exit.json)

采用范围是这台机器、固定地板和两种稳定比例下的最终相机输出边缘。显示交换链、比例切换当帧的历史、画质、耗时和 GPU 验证层诊断分别验收。原同 GI 尺寸 resize 子项保持其原裁决。[此前 resize 观察](../resize-history-136/result.md)
