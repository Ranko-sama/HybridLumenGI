# 颜色反弹可信性与动态历史上限

2026-10-29，产品基线 `78618e1`。按用户要求，两条子代理分别实现并验证，第三条只读审查反例、原始数据和改动，主代理负责整合。全程未使用 Codex with ChatGPT。完整原计划与生产验收仍开放。

## 产品改动

**缓存连接的未知覆盖。** `HLGICachedSurface` 原来只拒绝 `QUERY_UNRESOLVED`。普通可见性查询使用 `resolveMaterial=false`，但三角形的 alpha/覆盖或命中来源不确定仍会产生 `MATERIAL_UNKNOWN`。原代码把这种命中当成已证明遮挡，丢弃该 tap，再将剩余红色或蓝色重新归一化成可信结果。现在使用现有 `HLGIHitMaterialKnown` 谓词，同时拒绝这两种未知状态，沿用完整缓存清零及 `known=false` 的返回路径。确定遮挡仍可排除 tap；零权重 tap 不查询。数值消费者沿用原未知传播规则。

**变化帧的最大历史限制。** 两个 temporal 入口共用的表达式原来在 reactive 帧直接采用上限2，覆盖合法的 `maxHistory=1`。从有效旧历史长度1开始，变化帧因此混入一半旧颜色并输出长度2。现在变化帧采用 `min(2, _HLGI_MaxHistory)`，同时满足变化响应与用户设置的上限。未改未知当前测量的保留策略、滤波、置信度或阈值。

产品修改仅为 Transport 的一个判定及注释、Kernels 的一条限龄表达式。没有新资源、曝光/增益调整或场景修改。

## 采用依据

颜色线执行实际缓存插值、命中谓词、committed material 分类及 `CachedIrradiance` / `ProxyRadiance` 消费函数，场景与材质桥接等外部依赖显式适配。唯一基线/候选 WARP 对照的8项固定输入全部符合预期：首 tap 未知时旧版返回可信蓝 `(0,0,2)`，已有红色累积后未知时旧版返回可信红 `(4,0,0)`；候选均返回未知。三项变化用例完整80字节缓存清零，消费者撤销可信数值；五项保持控制的完整368字节输出逐位不变。见[颜色线结果](../LocalComparison/Review/cache-visibility-material-unknown-01/result.md)及[候选原始分析](../LocalComparison/Review/cache-visibility-material-unknown-01/candidate/analysis.json)。

动态线从合法 `maxHistory=1`、旧长度1、旧RGB=1、当前RGB=1.03125开始，两入口旧输出均为1.015625/长度2，候选均为精确当前色1.03125/长度1。固定静态几何与显式半格式存储适配中的六项保持控制逐位一致。实际配对只执行四次DXC编译、四次WARP调用，没有GPU重跑。见[动态线结果](../LocalComparison/Review/temporal-reactive-history-limit-01/result.txt)。

动态线保留两处执行事实：首次启动的相对目录错误在数值执行前修正；首次结果分析在未变化的 `maxHistory=32` 未知测量恢复控制上失败。原分析没有落实适配器的半精度向零转换，将实际1.009765625与未量化均值比较。依据[微软浮点转换规则](https://learn.microsoft.com/en-us/windows/win32/direct3d10/d3d10-graphics-programming-guide-resources-data-conversion)，独立整数位模型对同批输入和读回作精确RTZ补判，14行/339项通过；未放宽矩容差或修改产品、输入、原oracle与FAIL。八份原始证据前后哈希相同。见[独立补判](../LocalComparison/Review/temporal-reactive-history-limit-01/qualification/result.json)。

独立子代理重新读取原始二进制、核对当前产品哈希和补判输入来源，两项均无阻断，建议采用。整合源码的8个完整入口均以DXC `-O3` 编译通过：软件SDF、精确软件三角和硬件适配三后端各自的 `CSUpdateCache` / `CSTrace`，以及共享的 `CSTemporal` / `CSTemporalIdentity`。编译前后源码和固定Unity includes哈希一致，见[整合编译报告](../LocalComparison/Review/parallel-color-dynamics-02/compile/report.json)。

## 来源与范围

- Transport 候选 SHA256：`1621a7688f9157c1169016d259168c4c7462c6695522bea1c9d0ba57b7fe2255`。
- Kernels 候选 SHA256：`36f561edd634ddf3d629b06e847ead631ad6b44eaa6b2039ab658a4c422d1850`。
- WARP证明的是这些实际函数在固定输入下的控制流与数值；完整入口DXC编译不等于Unity导入或实体DXR执行。
- 本轮未部署Unity、构建Player或修改Release69。它仍是 `50b63c3` 产品源码加冻结示例接线的既有运行基线，不能当成已包含本轮修复。

这两项修复消除了可复现的可信状态与历史限制错误，不声明整体颜色反弹物理正确或动态画质通过。下一步继续依据实际问题选择最小改动；不因本轮有限通过而重开已收束的材质、移动门或性能矩阵。
