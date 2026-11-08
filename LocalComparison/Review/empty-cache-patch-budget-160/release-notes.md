# Release143 · 让已确认的空格释放照明更新名额

世界缓存调度现在沿用已有 HLOD 回读。完整的当前回读确认同一图卡的空格后，调度把对应名额留给其他合格格子。来源或图卡变化会撤销该判断，覆盖格继续使用原就绪和公平规则。

实际 C# 读回与调度对照中，相同两格额度由一空一实变为两个覆盖格，其中包含尚未取得可信样本的格子。回调由宿主提供，旧代次、整卡全零与截短数据均不获排除资格。该项覆盖逻辑配额，实际 GPU 时间和高速冷入首显另行验收。[同额度对照](https://github.com/Ranko-sama/HybridLumenGI/blob/50f69cf5673081b508aa8d937ed245a71cae0042/LocalComparison/Review/empty-cache-patch-budget-160/result.md)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，使用 Unity 6000.0.85f1 和 URP 17.0.4。完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/50f69cf5673081b508aa8d937ed245a71cae0042)
