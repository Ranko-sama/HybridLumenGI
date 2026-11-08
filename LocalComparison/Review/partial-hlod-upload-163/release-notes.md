# Release146 · 保持 HLOD 整组提交

已发布组的多件几何同时更新时，若原额度让部分成员延后，场景会在同步 GI 数据前撤回整组。完整的当前目标取得新回执后一起恢复。所有修改都能同帧上传时，正常的完整表示保持可用。

实际 Scene／BVH 的受控对照中，旧版留下两件可追踪的细节，修复后整组退出 BVH，随后三件一起恢复。Unity 资源及就绪回执由宿主提供，普通 Player 的画面和高速首显仍待实机验收。[对照与边界](https://github.com/Ranko-sama/HybridLumenGI/blob/30273804ec48c447ca6e07f8e47cec4a5ac4dc24/LocalComparison/Review/partial-hlod-upload-163/result.md)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，使用 Unity 6000.0.85f1 和 URP 17.0.4。完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/30273804ec48c447ca6e07f8e47cec4a5ac4dc24)
