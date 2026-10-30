# 高反射率直接反弹的路径一致性

2026-10-31，基线128a62b。关闭原目标1／工作流2、7中一处具体材质合同差异，不关闭完整G1。

普通Lit的specular=0白材质及合法detail增亮可产生rho=1。旧Surface捕获保留[0,1]，TraceScreen直接项使用真实rho；真实UV命中也保留该值，但ProxyRadiance把直接项与递归反馈一起夹到0.98。相同已知直接入射、反馈关闭时，世界路径的反射比屏幕路径低2%。这不是卡片精度或当前示例整景误差的归因。

修复把物理材质值与递归限制分开：card写入／读取及CPU常量材质保留[0,1]，world直接项使用真实rho；screen/world的缓存项均用min(rho,0.98)，total与nonAnalytic保持相同反馈系数。既有unknown、零漫反射发光早退、来源资格、采样、历史、资源和ABI保持。0.98高阶反馈仍有偏，不声称取消能量近似。

独立审查确认实际UV／screen调用链及此前65决策不阻止该分离。Astra同意这一有限修复及必要验证上限。复用已有WARP宿主与真实函数提取，检查高rho反馈关闭／开启、普通rho、零rho及unknown direct/cache；[结果](output/result.json)通过，依赖调用门保持。固定rho=(1,.99,.96)、Ddirect=(2,4,8)、Le=(.125,.25,.5)的反馈关闭输入中，旧world为(2.085,4.17,8.18)，修复后与screen同为(2.125,4.21,8.18)。同时有缓存时，两条路径采用相同反馈上限，非解析来源分量也匹配预期。

这是实际HLSL函数在固定材质／入射量替身上的结果，不是Unity遍历、光栅、整景颜色、运动或成本验收。mask只观察依赖调用集合，不单独证明次数／顺序；源码差异没有移动这些调用。拆分乘加可能产生末位舍入差异，不承诺一般低rho逐位不变。未新建宿主、哈希校验、参数扫描、图像采集或完整shader矩阵。独立最终复核无阻断，既有93图像／预算结果保留原来源。

## 普通交付

源码`1503738431bc06a84300285dc8f8c6ded263a53c`已整合[Release95](<I:/Unity test/Comparison/Builds/LocalRelease95/Start-LocalRelease.cmd>)。唯一普通Release／None构建成功，Unity PID24868、native exit0，0 errors／23 warnings保留；既有Renderer、QualitySettings及初始化入口在退出后恢复。保存场景、2ray／filter4／DXR、receiverObjectHistory及默认关闭的计时／反馈保持，没有新Player运行或观察器。

Astra同意有限采用及沿用既有包装发布流程。完整运行依赖、StreamingAssets和许可随包保留，仅排除Burst的DoNotShip目录。约39.4MB的[Windows演示包](https://github.com/Ranko-sama/HybridLumenGI/releases/tag/release95-demo)已发布至授权私有仓库，API确认prerelease及uploaded资产；[发布记录](published-release.json)与[包记录](package-result.json)保留。仅关闭此G1路径差异及本次发布整合，不把构建或上传等同整景／生产验收。
