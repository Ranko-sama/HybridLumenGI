# HybridLumenGI Release99 · Windows x64 实验性演示

完整解压 `HybridLumenGI-Release99-Windows-x64.zip`，打开其中的 `HybridLumenGI-Release99-Windows-x64` 文件夹。

- 双击 `Start-LocalRelease.cmd` 启动统一示例。Unity Player、Mono、D3D12、插件和分页资产都随包提供。升级时请解压到新目录。
- 双击 `PictureComparison\index.html` 离线看画面对照。五张原图位于页面的相对目录中，请保留整个 `PictureComparison` 文件夹。页内带 ↗ 的原始记录链接需要联网和仓库访问权限。

## 操作

先点击 Player 窗口使其接收键盘输入。

| 操作 | 按键 |
| --- | --- |
| 平移、升降、转向 | WASD、Q/E、方向键 |
| 近景、远景、离开分页范围 | 1 或 R、2、3 |
| 请求软件追踪、请求 DXR | 4、5 |
| 红墙换色、灯开关、门运动 | C、L、M |
| 形变启停、网格与骨骼切换 | 空格、K |
| 分页组释放与重载 | B |
| 将当前状态写入日志 | F2 |
| 隐藏面板、退出 | F1、Esc |

按 C 将红墙改为蓝色，再按一次恢复。已有独立材质槽覆盖的静态墙也支持换色，金属度等其他属性得以保留。L 恢复各灯原来的开关状态，关灯后发光面仍会照亮场景。门停止形变后，异步 GI 快照可能需要数帧追上。

## 这次改变了什么

Release99 调整了世界缓存的更新次序。当已发布的墙面发生材质变化、每帧预算只够更新部分缓存时，追踪距离内的接收面获得更高优先级。固定 CPU 调度对照有四个就绪的更新项和三个名额。两种情况下都更新了最久未服务项和墙面，第三个名额从远处接收面转给近处接收面。

`PictureComparison\index.html` 沿用 Release98 随包提供的四项画面对照。静止颜色与独立 CPU 参考的比较来自 Release93 第 119 帧。换色、关灯、开灯恢复以及门运动与停止均标有各自的采样帧、测量量和局限。五图采集于 Release78 至 Release93。本次调度对照衡量的是更新名额，颜色误差与恢复时间仍以页内注明版本的测量为准。

## 运行环境与来源

本机环境为 Unity 6000.0.85f1、URP 17.0.4、Windows x64、Mono、DX12、Linear，开发设备为 RTX 2080 Ti。默认启动 960×540，GI 为半分辨率、每像素 2 条射线、4 级空间滤波，优先 DXR。面板显示实际后端。

GPU 计时、预算反馈及进程显存观察默认关闭。`Memory` 开启进程采样，`Measure only` 开启 GI 计时，`Apply feedback` 应用用户输入的正数目标。面板提示已修正，更改这些控制会重置计时与反馈，同时保留光照历史。

本机目标为 960×540／30 FPS、GI 三段合计 p95 ≤ 25 ms、进程 local 显存采样峰值 ≤ 1 GiB。G0 本机基线已锁定，G1–G5 仍开放。

产品源码为 `e20759384555c918e1a91b48665082cbe9a0942c`。包内 `build-result.json` 记录普通构建信息，启动日志位于解压文件夹的上一级 `LocalRelease99.log`。原生插件通知和许可正文见 `Documentation\NativeGpuTimingThirdPartyNotices.md` 与 `Documentation\Licenses\Unity-Companion-License.txt`。[项目首页](https://github.com/Ranko-sama/HybridLumenGI)
