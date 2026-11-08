# Release139 · 资源页启动顺序

考虑等待时间的组优先级现在会传到实际页启动和它的依赖。已在飞的依赖继续由原操作持有。纯预取依赖保留低优先级，普通请求有机会先启动。

实际 CPU 调度器的受控对照中，新高优先请求反复来去时，旧版的持续请求在 65 步内未启动。修复后它在第 61 步启动并随后达到 Ready。两层预取依赖和普通请求竞争时，普通请求按原优先级先启动。适用范围限于受控 I/O 下的排序与继承。[前后对照](https://github.com/Ranko-sama/HybridLumenGI/blob/53070c4b37c3267044c84d482d2988bd4bcf3de1/LocalComparison/Review/streamed-page-priority-156/result.md)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建。使用 Unity 6000.0.85f1 和 URP 17.0.4，完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/53070c4b37c3267044c84d482d2988bd4bcf3de1)
