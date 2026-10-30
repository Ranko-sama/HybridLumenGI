# 空场不再重复分配三角后端资源

原目标3／4、工作流8关闭一个具体成本缺口：逐帧资格扫描没有接纳任何三角实例时，直接撤销旧几何并走既有软件回退，不再创建空RTAS、分配六个dummy属性缓冲、上传后立即退休。原问题来自[Release85三轮普通使用](../release85-resource-cycles-01/result.md)的累计准备计数，源码确认了重复路径；不是由计数推定泄漏或真实GPU构建次数。

修改限于`HybridLumenGIHardwareBackend.Prepare`。空计划继续使用原退休队列，实际销毁前保留资源计账；旧几何变空时推进一次几何版本，连续空帧不重复推进。每帧仍重新判断资格，重新入场或材质重新受支持时，即使proxy revision未变也会重建。已发布但未接纳的对象继续计入fallback。硬件与精确软件共用这条准备路径，非空路径和光传输算法没有调整。

复用现有HardwareBackend实际源码编译夹具完成必要回归：冷空场重复调用不分配／预约；非空撤离后旧资源在退休完成前仍计账，连续空帧不新增分配／上传／退休；零准入预算不阻挡撤离；同revision恢复资格可重新准备。独立源码审阅未见阻断，Astra同意此范围，未新建观察器或证明体系。

首轮[harness-output.txt](harness-output.txt)保留失败：11处旧断言要求空计划也增加重建计数；新增硬件用例另两处复用了前一用例已耗尽构建配额的1700帧。仅将旧计数预期改为不重建、将新用例移到1800起始帧，产品修复未改。第二轮[harness-output-02.txt](harness-output-02.txt)退出0、无失败。夹具使用录制式Unity API和受控退休回调，不是原生GPU执行、显存或帧率测量。

源码00497b2已通过一次公开普通Release/None构建整合到[Release86](<I:/Unity test/Comparison/Builds/LocalRelease86/Start-LocalRelease.cmd>)：Unity PID16088／native exit0，0错误、19条warning，输出102076684字节；见[构建调用](build-attempt.json)、[退出结果](build-exit.json)和[Unity构建报告](<I:/Unity test/Comparison/Builds/LocalRelease86/build-result.json>)。沿用保存统一场景和Release85的本机DXR启动偏好，构建后恢复工程Renderer、Quality和初始化入口。该批处理完成了Unity导入／编译及Player构建，未另启动Player。

原三轮观察保持Release85来源和末次记录超过30秒的限制；不重跑三轮、画面或性能采集，不声称实测加速、完整G4或生产长时通过。
