# 定位 HLOD 光照初始化受阻的 chart 或 patch

此前，照明缓存读回已经能判断哪个必需 chart 缺少覆盖，或哪个有覆盖的 patch 样本年龄不足。结果只作为对象级就绪布尔值传递。作者在场景中看到替代项一直预热，却无法从已有日志找到该查哪张卡。

在 Unity 的 **Tools > Hybrid Lumen GI > Validation > Log Runtime Diagnostics**，或普通示例的 **F2** 日志中，查看相机的 `lastHlodCoverageBlock`。当 `observed=true`，记录给出已有回读的源工作帧、对象名／ID／修订、owner 内卡序号、当时的物理卡索引，以及适用时的局部 patch 索引。烘焙 charts 的 `cardOrdinal` 可与源资产中的 chart 数组对应。

| 回读结果 | 作者能据此判断的内容 |
| --- | --- |
| Required chart has no covered cache patch | 这个必需 chart 的全部缓存单元都已检查，全部为显式清空记录。可从投影大小与材质 alpha 覆盖着手。产生空覆盖的具体原因尚需看源资产。 |
| Covered patch below required sample age | 该 patch 有匹配的身份与覆盖，光照缓存尚在积累。 |
| Invalid cache entry or tag mismatch / Missing cache entry | 数据不满足该卡的读取条件，或读回不足以包含所需位置。 |
| Fallback owner has no covered cache patch | 六视图近似采用对象级非空判据，整组尚无可用覆盖。 |

该字段只代表一次匹配快照中观察到的首个阻断。整张卡或整个对象的原因用 `patch=-1`；对象级原因也用 `cardOrdinal=-1`。`observed=false` 时，应结合已有的预热、页就绪、GPU 读回等待与失败字段解读。记录不提供所有卡的覆盖图或整景表面积统计。

复用原有 CPU 回调检查，将实际读回处理器与已有录制替身配合。空的必需 chart 被定位到 owner 101、序号 1、物理卡 5；同为物理卡 5 的另一个案例被正确定位到序号 0 的 patch 3，已有匹配样本但年龄不足。过期卡布局不会报告旧 chart 的阻断或签发就绪票据。回读次数、原覆盖门槛与发布资格均沿用原实现。旧测试的 80 B 布局断言已对齐真实缓存的 96 B 步长，额外通道偏移为 80 B。[实际处理器](../../../Runtime/HybridLumenGIHlodReadback.cs) · [既有回调用例](../../../Tests/StandaloneHlodReadback/Program.cs.txt)

产品源码 `192afe9` 已整合到普通 Release100。Unity 6000.0.85f1 无图形编辑器完成 Windows x64／Mono／Release 构建，0 个错误、23 个警告，正常退出。下载包中 `Start-LocalRelease.cmd` 启动统一示例，`PictureComparison/index.html` 提供原有颜色及动态对照、Release99 白炉原始线性 EXR 和 V209 零漫反射材质画面。离线页面引用的图片与 EXR 均已随包交付。[Windows x64 下载](https://github.com/Ranko-sama/HybridLumenGI/releases/download/release100-demo/HybridLumenGI-Release100-Windows-x64.zip) · [发布记录](published-release.json)
