# 环境辐亮度输入

Renderer Feature 的 `environmentCubemap` 可显式指定静态环境光。默认空值继续使用 `environmentRadiance`，保留它原有的线性颜色转换；有效 Cubemap 替代常量环境，不与常量叠加。

输入必须是未编码的线性 `RGBAHalf` 或 `RGBAFloat` Cubemap。RGB 表示沿世界空间逃逸方向的入射辐亮度 Li，而非已经积分或预卷积的漫反射。两条间接光 miss 路径使用同一个 LOD0 采样函数，原采样权重计算 D=E/π，接收面反射率仍在原位置应用。这里不额外应用曝光、强度、gamma 或 π 系数。

调用方负责提供未经 RGBM 等编码、未经反射探针卷积的资产，并保证它在使用期间内容不变。格式检查只能检查存储格式，不能识别浮点像素中藏有的编码或推断来源。更换或清空引用会通过现有设置失效机制撤销旧历史与缓存准备状态；不支持静默原地修改 Cube 内容后自动跟踪变化。动态 RenderTexture、自动天空捕获和环境重要性采样不在此输入合同内。

不受支持的格式会记录警告并回退常量环境。空值使用引擎提供的黑色 Cube 作维度正确的绑定占位。输入资产及占位纹理由调用方或引擎持有，Feature 不复制或销毁它们。确定表面命中、未解决查询和零权重方向保留原行为；非有限 Cube 样本不能成为已知黑色或有效环境贡献。

该输入用于 HybridLumenGI 的间接漫反射传输，不改变相机天空背景或 URP 的环境光设置。使用 Additive 时，原 URP 光照仍保留；指定 Cube 不会自动关闭烘焙 GI、环境球谐或其他 GI。完整合成选择仍遵循[原生漫反射合成合同](NativeDiffuseComposition.md)。

[63有限验证](ReviewBrief-StaticHdrEnvironmentCubemap01.md)在真实 Unity DX12 compute 中检查了方向、常量能量、两条原始消费路径及未知控制，并检查真实设置序列化与原失效代码块。它没有执行完整 Feature/RenderGraph 的 Cube 场景渲染，也不证明任意天空的物理误差、方差、画质或性能。
