# 引导权重与接收面几何解耦

实际 CSTrace 前导验证发现：缓存引导为空时，把 `guidedSamplingWeight` 从 0 改为默认 0.35，采样方向、权重和 RNG 完全相同，却会改变射线起点及历史几何法线。原因是世界表面匹配与 Ng 精化被放在了引导开关内。

在中心属于水平面、邻居深度形成斜法线的固定反例中，起点从 `(0.005883496, 0.029417420, -0)` 变为 `(0, 0.029999999, 0)`。这会改变薄遮挡边缘的可见性条件，不能视为仅改变采样分布。

修复只有两行条件移动：可靠几何始终尝试原有世界匹配；仅缓存引导读取受权重开关控制。保留原匹配距离、法线门槛和 ray bias，与已有 TraceScreen 的几何精化方式一致。权重为 0 时，每个有效且有可靠几何的 GI 像素新增一次短可见性查询和 footprint 构建；未测量该增量的 GPU 时间。

唯一基线和唯一候选 WARP 均执行同一组 8 条固定输入。候选使四组开关对的起点／方向／权重／RNG／Geometry 前 48 字节逐位一致，默认 0.35 的四份完整 368 字节输出逐位保持；零权重不访问缓存，未匹配和无可靠深度的控制保持。基线首次分析因 aligned 控制的 `-0/+0` 字节不同而失败；原 FAIL 保留，另层只对该坐标作精确 IEEE 数值相等资格，没有改容差或重跑基线。

这是真实产品函数配合明确资源／世界查询适配器的定向验证，不是完整 DXR 场景或实机 RGB 改善证明。独立审查确认反例和候选控制；软件、精确软件、硬件三个完整 CSTrace 入口均以优化 DXC 编译通过，源码已采用。此项不宣布默认 guided 图像或整体动态质量验收。

产品提交 `13f31ec`，Unity 项目112个产品源已按哈希更新一致；这只说明部署字节，不追加原生图像结论。普通 Player 仍为 Release71／269241b。

依据：[范围和失败记录](../LocalComparison/Review/guiding-origin-coupling-01/result.md)、[基线资格](../LocalComparison/Review/guiding-origin-coupling-01/qualified-analysis.json)、[候选原分析](../LocalComparison/Review/guiding-origin-coupling-01/candidate/analysis.json)、[完整入口编译](../LocalComparison/Review/guiding-origin-coupling-01/compile/report.json)。
