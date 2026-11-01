# HybridLumenGI Release98 · Windows x64 实验性演示

完整解压 `HybridLumenGI-Release98-Windows-x64.zip`，打开其中的 `HybridLumenGI-Release98-Windows-x64` 文件夹。

- 双击 `Start-LocalRelease.cmd` 启动统一示例。运行所需的 Unity Player、Mono、D3D12、插件和分页资产均在包内。升级时请解压到新目录。
- 双击 `PictureComparison\index.html` 离线查看画面对照。五张 PNG 在页面的相对目录中，请保留整个 `PictureComparison` 文件夹。页内带 ↗ 的原始记录链接需要联网和仓库访问权限。

## 操作

先点击 Player 窗口，使其接收键盘输入。

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

按 C 将红墙改为蓝色，再按一次恢复。Release98 也支持启动时已有独立材质槽覆盖的静态墙。例如槽 0 单独设置了金属度，换色时金属度会保留，恢复时该槽取回原来的属性块。没有独立覆盖的槽继续继承 Renderer 级设置。L 恢复各灯原来的开关状态，关灯后发光面仍会照亮场景。门停止形变后，异步 GI 快照可能需要数帧追上。

## 阅读对照

`PictureComparison\index.html` 汇集四项结果。静止颜色用 Release93 第 119 帧与独立 CPU 漫反射参考比较。换色、关灯和开灯恢复使用各自事件前后的观测，门运动使用同曝光的 3 级与 4 级空间滤波版本对照。各节标有 Release78 至 Release93 的实际采集版本、采样帧、接收区域、测量量和局限。Release98 本次用无图形设备的 Unity 编辑器检查真实 Renderer 上的换色与恢复，同一进程完成普通 Player 构建，0 个错误、23 条警告。

## 运行环境与来源

本机目标环境为 Unity 6000.0.85f1、URP 17.0.4、Windows x64、Mono、DX12、Linear，开发设备为 RTX 2080 Ti。默认启动 960×540，GI 为半分辨率，每像素 2 条射线、4 级空间滤波，优先 DXR。面板显示实际后端，GPU 计时、预算反馈及进程显存观察默认关闭。`Memory` 开启进程采样，`Measure only` 开启 GI 计时，`Apply feedback` 应用用户输入的正数目标。

本机目标为 960×540／30 FPS、GI 三段合计 p95 ≤ 25 ms、进程 local 显存采样峰值 ≤ 1 GiB。性能与颜色依据保留各自原运行的配置和适用范围。G0 本机基线已锁定，G1–G5 仍开放。

产品源码为 `183d2fb8a7d13f4b07046575a3fba160bba55fba`。包内 `build-result.json` 记录普通构建信息，启动日志位于解压文件夹的上一级 `LocalRelease98.log`。原生插件通知和许可正文见 `Documentation\NativeGpuTimingThirdPartyNotices.md` 与 `Documentation\Licenses\Unity-Companion-License.txt`。[项目首页](https://github.com/Ranko-sama/HybridLumenGI)
