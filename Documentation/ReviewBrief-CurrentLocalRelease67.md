# 当前源码本机 Release 与静态 HDR 环境整合（67）

目标是让当前已接受产品源码成为可用本机入口，并让静态 HDR Cube 经过真实 Renderer Feature。原四项目标、十条工作流继续开放；本轮关闭版本落后与完整环境输入整合缺口，不新增算法完成项，不代表整体动态质量或生产验收。

## 采用方案与来源

- 产品来源 `2fefc097b36084e05e88653d8dff8466caf9d513`。Unity 原部署7190c28的112份产品文件已核对，四份差异先备份再更新；没有本轮产品修改。更新后的产品部署保留。
- 独立 Astra 先判断应收束累计Surface36/51/52/65/66投入、转当前可用版本；Pro67随后读取原提案并批准唯一整合方案。原中性RGBAHalf草案在任何编译／Unity执行前，被正式计划替换为63的原六面RGBAFloat输入。
- 输入固定2×2、线性RGBAFloat、无mip、Bilinear/Clamp、alpha1。+X/-X/+Y/-Y/+Z/-Z RGB分别为 `(1,.125,.25)`、`(.5,2,.25)`、`(.5,.25,3)`、`(4,.25,.5)`、`(.25,5,.5)`、`(.25,.5,6)`；不是目标天空或物理真值，不根据图像调整。
- 复用Functional/colorView、640×360、Final、Additive。实际capture.feature指向Renderer.asset，GUID `1346d23e59037cd489d53c8e5b594ba4`、localID5043623260922118210。唯一构建进程生成静态资产并保存绑定后，才冻结BuildReport输入；Player借用构建内静态Cube，不运行时创建／销毁。
- 根执行层独占部署、Unity、构建、运行和恢复；两个并行lane分别准备输入身份／资产片段和编译／来源分析路由。既有采集、导航和产品helpers保持不变；仅包内薄接线。

## 有限执行合同

一次既有托管预检（runtime＋Editor）、一次Windows x64/Mono/DX12/Linear Release/None构建，输出独立LocalRelease67。一次可见Player使用既有`-localReleaseFinalImage120`：120个目标相机帧，末帧logical119保存一组RGBA32F/EXR/固定映射PNG，再正常退出。原采集目标首帧固定，停止条件和读取语义不改。构建期间临时harness、Renderer、Cube/meta和旧include覆盖全部恢复；旧Release58保留。

默认启动器不带有限参数，保留既有常驻窗口与WASD/QE/方向键/R/Escape代码。本轮实际运行有限HDR分支，不声称重新实测了键盘互动。仅新增现有结果收据中的一次CPU Cube配置与产品准入检查，不增加GPU探针；合法配置和完整渲染执行不能证明每条miss实际采样或量化环境贡献。

首次预检、构建、运行或资格失败保留证据后停止，由具体整合阻断决定是否修复。不得自动补帧、重跑、调曝光／亮度、扩测试矩阵或放宽门槛。成功时交一次集中复核。当前没有性能、峰值显存、长时、物理真值或完整动态质量验收声明。

## 当前结果

单次runtime／Editor托管预检均exit0。唯一Unity6000.0.85f1 Release/None构建成功，23条构建警告保留；112产品源、5临时接线、189产物以及真实Renderer/Cube/meta构建依赖首判通过。临时文件全部恢复，当前产品部署保留。

唯一DX12/RTX2080Ti Player完成120目标相机帧，GI公开进度1/60/120，末段22硬件mesh、132readycards；native exit0、无watchdog、errors0。运行时实际Cube非空、RGBAFloat/linear/2×2/no mip/Bilinear/Clamp，原产品准入成立，日志无常量回退警告。首帧等待101.249秒，属于本次实际使用限制，未测定原因或建立性能资格。

logical119／engine120取得640×360末帧RGBA32F、EXR与固定映射PNG，尺寸、有限值、文件身份和首次分析通过。PNG SHA256 `063b14c30b77492aae39dca0ab356233b44a5c04250fa767582da86010454401`。执行层已打开实际PNG：红色左墙、蓝色分块右墙、浅紫地面、白色前柱、红绿柱和后方暗块清楚可辨，部分边缘和阴影存在颗粒／阶梯状表现；这些视觉观察不是物理正确、动态稳定或“理想效果”认证。环境输入发生变化，不能把与54的亮度差称为算法改善。

本轮无失败、重跑、补帧或事后调参。旧66的逐位FAIL及显式数值资格仍原样保留，与本次整合结论分开。Astra及实际Pro67已有限采用并批准本地提交；Pro读取287–291及实际PNG。67设为新本机入口，58保留回退。下一步仅处理独立发现的HLOD近场冷启动容量回退缺口，不追加67运行。

证据目录：`LocalComparison/Review/current-local-release-67`；正式计划 `gpt6-pro-plan.txt`，独立初判 `proposal.txt`，原部署备份 `deployment/`，临时接线与源清单 `instrumentation/`。
