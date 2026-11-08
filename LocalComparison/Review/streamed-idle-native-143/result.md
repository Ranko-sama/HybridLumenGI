# 最后一次相机提交后的原生页回收

Release126 同源工程在固定 GoFar 机位完成一次空闲退休观察。最后一次相机开始时，已绑定的完整粗根具有提交资格。相机请求和渲染上下文正常返回后，停用该流式绑定组件并停止相机请求。此后到排空端点，所有相机的新 `beginContextRendering` 和 `endContextRendering` 均为零。[Release126 工程来源](../streamed-group-visibility-142/delivery.json) · [原始账目与票据](result.json)

| 状态 | 引擎帧 | Ready 页 | 消费引用 | 待退休租约 | 包字节 | 驻留估算字节 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 最后一次请求返回 | 43 | 8 | 6 | 0 | 122,484 | 294,697 |
| 显式停用，绑定仍在 | 43 | 8 | 6 | 0 | 122,484 | 294,697 |
| 空闲票据已提交，Renderer 与网格已解绑 | 44 | 8 | 6 | 6 | 122,484 | 294,697 |
| 同一栅栏通过，原生页操作已排空 | 59 | 0 | 0 | 0 | 0 | 0 |

实际票据来自该粗根第 1 代绑定。`requiresContext=false`、`submitted=true`、`submissionUnknown=false`，同一票据随后经真实 `fence.passed` 完成。最终全部页为 `Unloaded`，在途 I/O 和原生操作均为零。Unity 退出码为 0，原场景和管线设置已恢复。执行入口与退出记录保留于本机 `I:/Unity test/Comparison/LastCameraIdle143Setup`，日志为 `I:/Unity test/Logs/LastCameraIdle143.log`。

本次环境为 Unity 6000.0.85f1、Direct3D12、RTX 2080 Ti，普通统一示例的固定 960×540 相机请求，最后一次录制报告 DXR。Astra Max 同意采用一个已绑定粗根在最后一次相机上下文之后的真实空闲退休及页排空结果。最后相机记录的是提交资格，具体资源的在飞读取、普通 Player、多组回收及驱动显存仍按原条件验收。游戏共载期间只核对状态，表中引擎帧仅用于说明先后顺序。
