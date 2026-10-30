# HybridLumenGI Release96 — Windows x64 实验性演示

完整解压后双击 `Start-LocalRelease.cmd`，无需Unity编辑器。保留exe旁全部Data、MonoBleedingEdge、D3D12与插件目录，升级时解压到新目录。

Unity6000.0.85f1／URP17.0.4、Windows x64／Mono／DX12／Linear。启动960×540、半分辨率GI、2ray、4级空间滤波，优先DXR；计时、反馈和显存采样默认关闭。开发机RTX2080Ti，其他设备未完成验收，实际后端以面板为准。

| 操作 | 按键 |
| --- | --- |
| 平移／升降／转向 | WASD／Q、E／方向键 |
| 近景／远景／离开分页范围 | 1或R／2／3 |
| 软件／DXR偏好 | 4／5 |
| 墙面换色／灯开关／门运动 | C／L／M |
| 形变启停／网格与骨骼切换 | 空格／K |
| 分页组释放与重载 | B |
| 状态写入日志 | F2 |
| 隐藏面板／退出 | F1／Esc |

先点击Player窗口。Memory开启本进程显存采样；GPU面板的Measure only仅开启计时，Apply feedback才应用目标并启用反馈。Release96使这些监测／反馈配置独立刷新计时与控制器，不再单独撤销世界缓存、屏幕历史或HLOD就绪；物理／质量等其他配置仍按原规则失效。目标毫秒不是整应用GPU或硬截止保证。

日志在解压目录上一级 `LocalRelease96.log`。关灯保留自发光；异步形变快照可能在停止后继续追赶，不修改物理碰撞体。保留95的高反射率直接反弹一致性修复、94骨骼停稳历史，以及既有filter4／2ray／DXR配置。0.98递归反馈限制仍是有偏近似；已撤回的骨骼运动短历史候选未进入产品。

G0本机基线已锁定，G1–G5仍开放。96只新增实际Unity Settings配置检查与普通构建，没有新的Player、画面或成本观察。颜色估计仍来自93有限ROI及近似参考；多跳残留、完整运动拖影和精确收敛时间未完成。目标960×540／30FPS、GI三区间合计p95≤25ms、进程local有限采样峰值≤1GiB；93有限窗口满足两个预算门槛，不代表96动态负载验收。CI暂缓。

二进制产品来源 `171e6fc`，构建信息见包内 `build-result.json`。源码及完整边界：https://github.com/Ranko-sama/HybridLumenGI

完整StreamingAssets随包保留，仅排除Burst的DoNotShip目录。原生插件第三方通知见 `Documentation/NativeGpuTimingThirdPartyNotices.md` 及相对路径许可正文。
