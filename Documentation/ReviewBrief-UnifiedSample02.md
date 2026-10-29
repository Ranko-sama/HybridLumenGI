# 同场景分页、HLOD 与后端切换

已关闭原计划工作流 8 的一个实际使用缺口：同一场景、同一相机能从冷加载进入完整细节组，切到 aggregate，切换软件/DXR 偏好，停用后释放，再次加载并离开后释放。首轮独立核验通过，未出现部分可见组或重叠组，两个释放阶段的页面引用和页面计账归零。

实现使用现有分页、HLOD 发布与 GPU 退休链。新增只读发布查询、后端偏好入口、可调用的资源页导出器和普通示例控制器。aggregate 保留原三角形和材质槽，减少 renderer 数量，不是网格简化。构建器保存独立运行场景，作者场景的字节保持不变。

适用范围是单相机、三个简单静态接收体组成的组；其余物体仍为常驻。实际运行包含软件与 CPU 诊断报告的 DXR 后端，未逐射线证明硬件执行。页面计账不是总显存，用户已退出游戏但 GPU 负载未测，不作性能结论。整景颜色误差、动态拖影与多反弹收敛需要独立画面对照，本包没有替代这些结论。

首次尝试在 Player API 编译时发现来源导出直接访问 Editor 专有的 `Light.lightmapBakeType`。现改为项目已有的 `HybridLumenGILights.GetBakeType`，保留 Editor 语义并支持 Player。失败保留在 unified-sample-01，修复后 native 02 完成整合。

证据：[独立核验](../LocalComparison/Review/unified-sample-02/run-verification-first.json)、[运行来源](../LocalComparison/Review/unified-sample-02/source-freeze.json)、[使用与限制](../LocalComparison/Implementation/UnifiedSample/SAMPLE.md)。普通用户入口暂仍是 [Release73](ReviewBrief-CurrentLocalRelease73.md)，下一步将这套统一示例与交互操作整合为可运行版本。
