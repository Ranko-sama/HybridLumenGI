# HybridLumenGI Release95 — Windows x64 实验性演示

完整解压后双击 `Start-LocalRelease.cmd`，无需Unity编辑器。保留exe旁全部Data、MonoBleedingEdge、D3D12和插件目录；升级时解压到新目录。

Unity6000.0.85f1／URP17.0.4、Windows x64／Mono／DX12／Linear。启动为960×540、半分辨率GI、2 rays/pixel、4级空间滤波，优先DXR。计时、预算反馈和显存采样默认关闭。开发机RTX2080Ti，其他设备未完成验收，实际后端以面板为准。

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

先点击Player窗口。Memory按钮开启本进程显存采样；GPU面板的Measure only只开启计时，Apply feedback才启用反馈。日志为解压目录上一级的 `LocalRelease95.log`。关灯保留自发光；异步形变快照可能在停止后继续追赶，不修改物理碰撞体。

Release95修复高反射率材质的screen/world直接反弹不一致：物理rho保留[0,1]，0.98只限制递归缓存反馈。后者仍是有偏近似；本次有限函数检查和普通构建不代表整景颜色、运动或成本重新验收。保留94普通骨骼停稳历史、92的filter4、88的2ray和93遍历优化；已撤回的骨骼运动短历史候选不在包内。

G0本机基线已锁定，G1–G5仍开放。颜色估计保留93两个ROI及近似参考来源；换色／关灯多跳残留、完整运动拖影和精确收敛时间仍待完成。目标960×540／30FPS、GI三区间合计p95≤25ms、进程local有限采样峰值≤1GiB；93有限窗口满足两预算门槛，不代表95动态负载验收。CI暂缓。

二进制产品来源 `1503738`，详细普通构建记录见包内 `build-result.json`。源码及适用范围：https://github.com/Ranko-sama/HybridLumenGI

完整StreamingAssets随包保留，仅排除标注DoNotShip的Burst调试目录。原生插件第三方通知见 `Documentation/NativeGpuTimingThirdPartyNotices.md` 与相对路径许可正文。
