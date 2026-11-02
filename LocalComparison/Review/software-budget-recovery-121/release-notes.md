**小场景现在能在降低预算后恢复精确软件追踪。** 实机对照中，同一相机从 10,000 个三角形切换到 2 个三角形，软件几何预算由 64 MiB 降为 1 MiB。旧版在随后 48 个渲染回调中一直使用近似几何。修复后，第 3 个低预算回调已使用新网格的精确软件路径，属性和 BVH 合计 1,056 B。栅栏完成前的旧资源仍正常计账。[预算恢复读数及范围](https://github.com/Ranko-sama/HybridLumenGI/blob/e1e00d8ffe59c44206b17124948ed84b55b33a71/LocalComparison/Review/software-budget-recovery-121/result.md)

**统一示例的后端切换。** 按 **4** 请求软件，按 **5** 请求 DXR。面板和 **F2** 日志区分请求与目标相机实际录制的后端，等候新请求生效时会说明原因。

本版也整合了非均匀缩放后的折面图卡修复。X 轴压缩到 0.1 后，共用图卡的两片三角形都能取回自己的材质，第二片捕获法线与源法线的点积从 −0.99923 恢复为 +0.99732。[折面与倾斜单平面对照](https://github.com/Ranko-sama/HybridLumenGI/blob/e1e00d8ffe59c44206b17124948ed84b55b33a71/LocalComparison/Review/folded-chart-facing-01/result.md)

完整解压 Windows 包，双击 `Start-LocalRelease.cmd`。按 **M** 启停灰门，按 **F5** 查看间接光。门运动使用此前采用的 2 条射线、4 级空间滤波。离线打开 `PictureComparison/index.html` 可看已有的同曝光运动、换色和关灯对照。
