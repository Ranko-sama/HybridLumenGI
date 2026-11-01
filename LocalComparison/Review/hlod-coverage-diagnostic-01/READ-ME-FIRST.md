# HybridLumenGI Release100 · Windows x64 实验性演示

完整解压 `HybridLumenGI-Release100-Windows-x64.zip`，打开其中的 `HybridLumenGI-Release100-Windows-x64` 文件夹。

- 双击 `Start-LocalRelease.cmd` 启动统一示例。Unity Player、Mono、D3D12、插件和分页资产都随包提供。升级时请解压到新目录。
- 双击 `PictureComparison\index.html` 离线看画面对照。请保留整个 `PictureComparison` 文件夹。页面按相对路径显示七张原始 PNG，并提供白炉的线性 HDR 文件 `PictureComparison\white-furnace-ordinary-01\frame-0000.exr`，可用支持 OpenEXR 的图像工具打开。页内带 ↗ 的记录链接需要联网和仓库访问权限。

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

C 切换红墙与蓝墙，再按一次恢复原材质覆盖。L 恢复各灯原来的开关状态，关灯后发光面仍会照亮场景。门停止形变后，异步 GI 快照可能需要数帧追上。

## 查看 HLOD 预热状态

当替代表示仍在预热时，按 F2，打开解压文件夹上一级的 `LocalRelease100.log`，搜索 `lastHlodCoverageBlock`。在 Unity 编辑器运行示例时，也可通过 **Tools > Hybrid Lumen GI > Validation > Log Runtime Diagnostics** 输出相机诊断。

`observed=true` 时，`sourceWorkFrame` 给出这次 GPU 读回对应的 GI 工作帧。用 `ownerName`、`ownerId`、`cardOrdinal` 和 `physicalCard` 定位对象及卡片，再看 `reason`。

- `Required chart has no covered cache patch` 表示这张必需 chart 的缓存块中没有找到可用覆盖。此时 `patch=-1`，原因指向整张卡。
- `Covered patch below required sample age` 表示已有覆盖，但指定 `patch` 的采样年龄仍不足以发布替代表示。

记录给出最近回读中能归属到当前来源的首个阻断项。若 `observed=false`，需结合 `hlodReadbackPending`、读回失败计数和预热状态判断进度。卡片的表面积覆盖率和光照收敛程度仍需其他证据。

## 阅读画面对照

原有五张图说明静止颜色误差、换色与关灯残留、门运动以及开灯恢复，各节标有 Release78 至 Release93 的实际采集版本。本包另收录两项 G1 结果。Release99 白炉在普通 Feature 的间接出射图上测得中央 64×64 像素平均 RGB 约为 `(0.99902347, 0.99902347, 0.99902347)`，理论值为 `(1,1,1)`。V209 的零漫反射对照保留了第 119 帧全金属与黑色接收面上的原生相机颜色，298／473 个内部样点的合成前后 RGB 最大绝对差均为 0。旧版独立画面对照附件仍含原来的五张图。

## 运行环境与来源

本机环境为 Unity 6000.0.85f1、URP 17.0.4、Windows x64、Mono、DX12、Linear，开发设备为 RTX 2080 Ti。默认启动 960×540，GI 为半分辨率、每像素 2 条射线、4 级空间滤波，优先 DXR。面板显示实际后端。

GPU 计时、预算反馈及进程显存观察默认关闭。`Memory` 开启进程采样，`Measure only` 开启 GI 计时，`Apply feedback` 应用用户输入的正数目标。更改这些控制会重置计时与反馈，同时保留光照历史。本机目标为 960×540／30 FPS、GI 三段合计 p95 ≤ 25 ms、进程 local 显存采样峰值 ≤ 1 GiB。G0 本机基线已锁定，G1–G5 仍开放。

产品源码为 `192afe9f83412097fb9efb2e7adbeb6e6fd62474`。包内 `build-result.json` 记录普通构建信息。原生插件通知和许可正文见 `Documentation\NativeGpuTimingThirdPartyNotices.md` 与 `Documentation\Licenses\Unity-Companion-License.txt`。[项目首页](https://github.com/Ranko-sama/HybridLumenGI)
