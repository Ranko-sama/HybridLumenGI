# 降低预算后，小网格能否恢复精确软件追踪？

此修复已整合到 Release121。普通 Windows x64 Player 从同版工程 ZIP 的独立解压目录构建，场景为 `NeutralThreeRooms.unity`，Release／None，0 个错误、6 条警告。下述运行读数来自 Unity Editor Play。[运行包及可编辑工程](https://github.com/Ranko-sama/HybridLumenGI/releases/tag/release121-demo)

同一台相机先以 64 MiB 软件几何预算渲染一个 10,000 三角形的平面，再将网格换成相同外形的两个三角形，同时把预算降到 1 MiB。普通 URP Lit 材质、Renderer、GI Proxy、相机和软件后端偏好保持一致。旧版在降预算后的 48 次渲染中一直使用 SDF／解析回退。修复后，第三次低预算渲染已为新网格录制精确软件追踪，此后保持到窗口结束。

| 同一相机的状态 | 旧版软件几何计账 | 修复后软件几何计账 | 修复后录制的后端 |
| --- | ---: | ---: | --- |
| 10,000 三角形，最后一个高预算帧 | 3,200,416 B | 3,200,416 B | 精确软件 |
| 2 三角形，第一个低预算帧 | 3,200,416 B | 3,200,416 B，均等待安全退休 | SDF／解析回退 |
| 第三个低预算帧 | 1,279,968 B | 1,056 B | 精确软件，2 个叶、3 个节点 |
| 第 48 个低预算帧 | 1,279,968 B | 1,056 B | 精确软件 |

旧 BVH 的节点和叶单独就占 1,279,968 B。原代码先从预算扣除这些容量，再尝试准备新网格的属性。属性准入失败时不会进入后续 BVH 替换步骤。修复在这次失败时将旧 BVH 交给现有栅栏退休流程。旧读者结束后，小网格的属性占 832 B，BVH 占 224 B。两个缓冲的实际尺寸与新网格相符。[选取的原生记录](comparison.json)

**后端报告。** 统一示例按 4 或 5 时，F2 与面板会等目标相机针对这次请求录制传输命令。软件测量的末帧先记录了精确软件。保持同一帧，连续请求 DXR、再请求软件，中间没有提交相机渲染。在两次读取中，上一条软件记录均正确标明不匹配新请求。本次观察验证了请求与录制的关联；真实 DXR 的往返端点和硬件资源释放另有普通 Player 记录。[同帧切换读数](comparison.json) · [普通后端往返](../disabled-dxr-retirement-01/result.md)

**适用范围。** Unity 6000.0.85f1，URP 17.0.4，Windows D3D12，RTX 2080 Ti。旧版来自 `515c97c`。两程均在 Editor Play 使用相同的私有 Renderer Feature，固定 128×72 相机，连续完成 50 次渲染上下文并恢复工程设置。最初一次观察在选中目标 Feature 前即结束，未得到 GI 样本，未用于比较。这里测到的是精确软件命令录制及其逻辑资源字节。恢复帧数取决于栅栏进度；该数值不代表驱动总显存、整景帧率或图像误差。[完整旧版记录](<I:/Unity test/Comparison/SoftwareBudget121BaselineAttempt2/observation.json>) · [完整修复后记录](<I:/Unity test/Comparison/SoftwareBudget121CandidateAttempt2/observation.json>)
