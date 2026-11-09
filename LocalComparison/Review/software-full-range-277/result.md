# 精确软件全距查询候选的固定近景成本

Release227 的精确软件路径在全覆盖时仍先查近段。近段未命中时经过全局 SDF 跳空，再查同一 BVH 的远段。候选仅在 `HLGI_SOFTWARE_TRIANGLES`、`_HLGI_ExactCoversPublished != 0` 且最大距离有限时，将 `TraceSceneQuery` 的 `detailLimit` 设为 `maxT`。其余查询继续使用原范围。候选仅进入隔离工程。

| 固定近景 | Release227 | 全距候选 |
| --- | ---: | ---: |
| GI 三段逐源合计中位 | 44.604 ms | 42.667 ms |
| GI 合计 p95 | **45.465 ms** | **43.860 ms** |
| GI 合计 p99 | 45.885 ms | 44.258 ms |
| Transport p95 | 45.244 ms | 43.644 ms |
| 进程 local 有限采样峰值 | 553.074 MiB | 550.574 MiB |
| 进程 nonlocal 有限采样峰值 | 279.789 MiB | 277.789 MiB |

p95 降幅为 **3.53%**，低于事前 15% 采用门槛。中位降幅 1.937 ms 超过两窗块中位极差的最大值 0.213 ms，p99 同时降低，两窗 local 峰值均在 1 GiB 内。按原规则结束候选，继续交付 Release227。远段命中及覆盖的语义对照只在成本过门后需要，本轮据此收束。软件 25 ms 时间缺口仍开放。[读数与判定](result.json)

两侧分别从同一 Release227 工程独立解压构建。Unity 6000.0.85f1、RTX 2080 Ti、DX12 普通 Win64 Player，960×540／GI480×270、2 射线、4 级滤波，反馈关闭。原保存场景近段 12、方向距离 50、全局 SDF 启用。两窗均为 20 个已发布对象由精确软件几何接管、3 个近景细节完整可见，使用同一 512 源帧 GPU 和显存窗口。两次启动前 GPU 占用单次读数均为 1%，两个进程均退出 0。观察器历史范围字符串仍写 Release195，本次版本由同源构建与退出回执确定。[基线本机原始窗口](<I:/Unity test/Comparison/SoftwareFullRange277/run>) · [候选本机原始窗口](<I:/Unity test/Comparison/SoftwareFullRange277Fixed/run>)

适用范围为上述固定负载的 GI 队列时间和同窗进程显存。Gather 内各路径、其他负载及应用 Present 各自验收。[已有 Gather 分项](../software-transport-cost-259/result.md)
