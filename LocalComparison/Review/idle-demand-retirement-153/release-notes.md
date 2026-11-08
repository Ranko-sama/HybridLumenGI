# Release136 · 最后一次渲染之后的页需求撤回

启用中的分页绑定撤回需求后，即使没有后续渲染上下文，也可在已证实的空闲帧尾进入退休。有效消费者继续持有页面。消费者稍后放行时，待撤回的绑定会再检查，解绑后等已提交的栅栏完成再归还租约。重新发出的手动需求会保护仍绑定的页组。

真实 AssetBundle 的 DX12 Editor 对照中，Release135 在最后一次相机请求后撤回需求，受控消费者退出后仍持有两份页引用。Release136 在绑定保持启用、无新上下文的条件下，等待实际消费者注册表放行并提交空闲栅栏。栅栏通过后，页引用、退休租约、包、驻留及在途账目归零。普通 Player、多组、高速冷入和正式性能分别验收。[原生对照与适用范围](https://github.com/Ranko-sama/HybridLumenGI/blob/2d48446e485ee8cc85373bc5955a590e889c9272/LocalComparison/Review/idle-demand-retirement-153/result.md)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，沿用 Release135 着色器缓存。使用 Unity 6000.0.85f1 和 URP 17.0.4，完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/2d48446e485ee8cc85373bc5955a590e889c9272)
