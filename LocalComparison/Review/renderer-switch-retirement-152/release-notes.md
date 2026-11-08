# Release135 · 相机切换 Renderer 后的资源页退休

活动 Base 相机改用另一个 URP Renderer 时，原 Renderer 保存的 GI 状态会退出该相机的分页保留判断。仍使用旧 Renderer 的相机可以继续持有完整页组。最后一个有效消费者离开后先解绑，最终上下文栅栏完成后再归还租约。

同一实际 AssetBundle 对照使用两台自动渲染的 Base 相机，两台依次从含 Hybrid Lumen GI 的 Renderer 切到无该 Feature 的 Renderer。Release134 在最后一次切换后继续保留两份页租约。Release135 保留仍使用旧 Renderer 的第二视图。最后一台切走后，网格解绑、两份租约进入退休，随后页引用、驻留、包和在途账目归零。该结果覆盖单个分页组的 DX12 Editor 序列。普通 Player、多组压力、高速冷入和正式性能预算分别验收。[原生对照与适用范围](https://github.com/Ranko-sama/HybridLumenGI/blob/4525a92bd835e7f1fc73daf26d9d5a3d95342a20/LocalComparison/Review/renderer-switch-retirement-152/result.md)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，沿用 Release134 着色器缓存。使用 Unity 6000.0.85f1 和 URP 17.0.4，完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/4525a92bd835e7f1fc73daf26d9d5a3d95342a20)
