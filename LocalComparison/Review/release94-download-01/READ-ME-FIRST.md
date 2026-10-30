# HybridLumenGI Release94 — Windows x64 实验性演示

解压整个文件夹，双击 `Start-LocalRelease.cmd`。无需安装Unity编辑器。请保留exe旁的所有数据、MonoBleedingEdge、D3D12与插件目录，不要只复制exe。

本包复用已构建的普通Release94：Unity6000.0.85f1／URP17.0.4、Windows x64／Mono／DX12／Linear。启动为960×540、半分辨率GI、2 rays/pixel、4级空间滤波，优先DXR；计时、预算反馈和显存采样默认关闭。实际后端以面板为准。开发机为RTX2080Ti；其他硬件未完成验收。

| 操作 | 按键 |
| --- | --- |
| 平移／升降／转向 | WASD／Q、E／方向键 |
| 近景／远景／离开分页范围 | 1或R／2／3 |
| 软件／DXR偏好 | 4／5 |
| 墙面换色／灯光开关／门运动 | C／L／M |
| 形变启停／网格与骨骼切换 | 空格／K |
| 分页组释放与重载 | B |
| 状态写入日志 | F2 |
| 隐藏面板／退出 | F1／Esc |

先点击Player窗口再使用快捷键。Memory按钮可开启本进程local／nonlocal显存采样；GPU time / update budget内的Measure only只开启计时，Apply feedback才启用反馈。日志位于解压文件夹的上一级 `LocalRelease94.log`。关灯保留自发光；形变GI快照异步，停止后光照可能继续追赶；形变不修改物理碰撞体。

Release94新增普通骨骼停稳后的历史累计，真正骨变化仍拒绝旧历史。后续运动短历史候选没有采用，不在此二进制内。原四项目标、十条工作流与G0–G5尚未整体验收，这不是生产稳定版。

当前画质边界：颜色估计仍来自93的有限两个ROI与近似参考，非整景真值；换色／关灯多跳残留仍开放；92四个动停时点未见新增持续旧门轮廓，但不证明全过程无拖影；没有统一的正确颜色收敛帧数。起始目标为960×540／30FPS、GI三个区间合计p95≤25ms、进程local采样峰值≤1GiB；93有限窗口满足GI／显存门槛，不代表94完整动态负载验收。

源码和详细结果：https://github.com/Ranko-sama/HybridLumenGI

二进制产品来源为`65c36ef`，普通构建及整合记录为`e296750`。本下载包只增加操作说明和既有第三方通知，没有重建或修改Player。包括完整StreamingAssets，部分历史生成页保留；只排除标注DoNotShip的Burst调试目录。第三方通知见 `Documentation/NativeGpuTimingThirdPartyNotices.md` 及其相对路径许可正文。
