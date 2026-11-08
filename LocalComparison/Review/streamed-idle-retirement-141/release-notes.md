# Release125 · 最后一台相机停用后的流式资源回收

已绑定的 `HybridLumenGIStreamedRepresentation` 被明确停用或销毁时，旧版要等下一个渲染上下文才尝试撤回绑定。最后一台相机停用后，页引用可能一直保留。Release125 在下一次已确认的渲染循环外空闲边界检查该表示，撤回绑定并为此前的读者提交图形队列栅栏。栅栏报告完成后，页回收器才归还引用。普通距离卸载继续按相机消费者规则执行。

实际 C# 组件的 CPU 回归覆盖停用入口和退休协调器。最后一次相机提交之后没有新的渲染上下文，模拟栅栏仍能覆盖最后读者并完成票据。旧引用在票据完成前保持。实体 GPU 退休、生产负载和完整 G4／G5 仍按原计划验收。[资源生命周期说明](https://github.com/Ranko-sama/HybridLumenGI/blob/b1f3a9dbaf18518ab6843f8168ecf059a6f12b2f/Documentation/IndependentAssetPages.md#publication-and-lifetime)

普通 Windows x64 运行包从同版 Unity 工程 ZIP 的独立解压目录构建。编译可复用 Release124 的着色器缓存。示例沿用同一场景、资产页及离线画册，Unity 6000.0.85f1、URP 17.0.4。完整解压 Windows 附件后双击 `Start-LocalRelease.cmd`。源码与包随附 Apache-2.0 许可和第三方通知。
