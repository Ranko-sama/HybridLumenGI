# 精确软件复用胜出候选的覆盖判断

精确软件 BVH 在选择最近三角时已经判断过材质覆盖。提交阶段现在沿用胜出候选的已知位。该位随胜出三角更新，透明候选继续跳过，最近未知候选仍使结果未知。距离、同距次序、Cull、完整材质和面积光覆盖标志都按原规则处理。DXR 继续验证其独立提交的候选。[软件遍历](../../../Runtime/Resources/HybridLumenGI/HybridLumenGISoftwareTriangleBvh.hlsl) · [完整材质求值](../../../Runtime/Resources/HybridLumenGI/HybridLumenGIExactMesh.hlsl)

| 960×540 固定近景 | Release195 | 复用覆盖结果 |
| --- | ---: | ---: |
| GI 合计中位 | 48.534 ms | **45.006 ms** |
| GI 合计 p95 | 50.005 ms | **45.887 ms** |
| GI 合计 p99 | 50.545 ms | **46.349 ms** |
| Transport p95 | 49.804 ms | **45.683 ms** |
| 进程 local 有限采样峰值 | 576.637 MiB | 549.574 MiB |
| 进程 nonlocal 有限采样峰值 | 281.664 MiB | 278.789 MiB |

同一设备和保存场景，半分辨率 GI、2 射线、4 级滤波、反馈关闭。两个窗口各有 512 个完整配对的 GPU 源帧，同窗采样进程显存。20 个已发布对象都由精确软件接管，原 3 个近景成员完整可见。候选只覆盖两份 HLSL，观察器和其余输入沿用基线。中位节省 3.528 ms，约 **7.27%**，大于两侧各自 128 帧块中位极差的最大值 0.501 ms，p95 和 p99 同时降低。Astra Max 按事前条件同意采用。[事前条件](contract.md) · [软件基线](../software-budget-230/result.md) · [逐源统计](result.json) · [采用判定](decision.json)

采用范围为这处重复覆盖的消除和实际近景时间收益。软件 GI p95 仍高于 25 ms，local 在 1 GiB 以内。显存差属于有限窗口采样。应用 Present、其他软件负载、画质与完整 G4／G5 各按原条件验收。[候选构建回执](build-exit.json) · [Player 退出回执](native-exit.json)
