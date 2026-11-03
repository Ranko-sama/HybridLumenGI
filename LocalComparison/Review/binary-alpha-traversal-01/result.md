# 二值裁剪：精确软件与实际 DXR 的前后命中

本次关闭 T2／G4 的一个有限材质子项：**已就绪、静态普通 Lit 二值 Point／无 mip alpha 中，透明前候选不会阻止射线命中已知后板，实心候选仍命中前板。** 两条精确路径分别符合源几何及纹理预期，没有产品源码改动，继续交付 Release122；整体 G1／G4、材质矩阵和普通 Player 图像不据此放行。

2026-11-04，Unity 6000.0.85f1、Direct3D12、RTX 2080 Ti，单次更正后的 Editor 观察正常退出并恢复原场景。入口调用当前产品的精确 Query：真实 MeshRenderer → Scene／SurfaceCache 材质准入 → HardwareBackend，软件 BVH 由该实际三角 provider 构建；材质走原始 MaterialSource、Batch 和纹理页上传。没有手造几何／UV／材质表，没有 SDF／解析回退，也没有卡片照明缓存参与。实际2个网格、2个实例、4个三角全部接纳；checker 页完整上传并经实际 metadata 回读 Ready 后，consumer 复用该页、无重传、无 unknown 材质行。

## 独立输入与结果

前板 z=0、xy=[-1,1]，红色；后板 z=1、xy=[-2,2]，蓝色。identity 变换、朝向 -Z、Cull Back、metallic=0，源 UV 按各自板尺寸线性映射。前板 linear RGBA32 8×8，白 RGB，alpha=(x+y)偶数为1、其余0；Point／Clamp／无 mip、cutoff=.5、alpha-test 开、作者 `_AlphaToMask=1`。这里是射线二值覆盖，不是 MSAA／A2C 的屏幕一致性。

固定射线都朝 +Z、maxT=4、点足迹、一般表面查询并解析真实命中材质。预期在运行前冻结；下列数值是两路径各自实际返回，而非两路径互相一致后推定正确。

| 来源与射线原点 | 预期／实际命中 | t | primitive | 源 UV | 源顺序 barycentrics |
| --- | --- | --- | --- | --- | --- |
| 绕前板 (1.5,-.375,-1) | 蓝后板，stableId=2 | 2 | 0 | (.875,.40625) | (.40625,.46875) |
| 穿透明 texel(1,2)，(-.625,-.375,-1) | 蓝后板，stableId=2 | 2 | 1 | (.34375,.40625) | (.0625,.34375) |
| 实心 texel(1,3)，(-.625,-.125,-1) | 红前板，stableId=1 | 1 | 1 | (.1875,.4375) | (.25,.1875) |

两路径实际 submesh=0、owner／geometry revision=3，flags=1471：具有有效三角、UV、几何／着色法线和已知命中材质，无 MATERIAL_UNKNOWN／QUERY_UNRESOLVED。蓝、蓝、红的实际漫反射主通道均为 0.9599999785423279，其余为零，与 dielectric 0.96 的预期一致；距离、UV、重心与冻结值一致。距离／UV／重心容差2e-6、RGB欧氏差2e-5，没有调阈值。输出保留整数身份，源网格、像素和实际结果见[更正原记录](corrected-result.json)。

## 准备失败与采用资格

第一次 `BinaryCoverage128` 的 HLSL 输出字段误用保留字 `triangle`，迟编译失败，kernel invalid，原数据全零，native1。该入口错误由主线程与子代理审阅漏过，**不是产品射线失败**；原记录的 actualSoftware／actualDxr 只是提交后盲置，也不能采用。原失败 JSON 原样保留为 [invalid-first-result.json](invalid-first-result.json)，不能因它写着 `failed` 而判产品不支持。原日志编译错误摘录见 [invalid-compile.txt](invalid-compile.txt)。

Astra Max 允许仅修正这项准备错误后进行一次同输入更正。字段改名，80B ABI、几何、材质、射线、期望与容差不变；更正入口分开记录提交与执行，读回后检查迟编译消息、运行期错误及 query-written 距离。本次更正无 compute 错误，软件与 DXR 均实际写回 t=2／2／1，并满足源身份、UV、材质要求；native0、场景恢复。两个原始输出和 setup 目录均保留在本机，不再补采。

## 适用边界与重放

- 仅限本次静态二值、Point／无 mip、正面 Cull Back、零足迹一般表面查询。没有关闭阴影逐候选、smoothness-alpha、法线贴图、mip／过滤、parallax、形变和 Cull 矩阵的全部验收。
- 直接产品 API 的候选遍历不等于 RendererFeature／Player 的同曝光图像；本次没有画面、响应时间、GPU 时间或显存结论。未知覆盖的保守处理也未被本次已知页替代。
- `_AlphaToMask=1` 在此是实际作者材质输入，不构成原生屏幕 A2C 或默认身份历史复用通过。
- [observation-source.zip](observation-source.zip) 保存执行过的更正 C#／compute、冻结条件及启动脚本；脚本使用固定独占输出目录，有意拒绝覆盖既有数据。原记录来源 `I:/Unity test/Comparison/BinaryCoverage128Corrected`，失败来源同目录下 `BinaryCoverage128`；两者各自 Setup 保存当次执行入口和退出码。

这次同时纠正 [DirectLighting](../../../Documentation/DirectLighting.md) 中过时的“CPU alpha 实例准入仍关闭”描述：当前代码已允许普通 Lit 二值裁剪，DXR 强制逐候选判定，已知透明继续遍历。没有发现需要另立产品修复的具体反例。

Astra Max 审查同意仅采用上述有限子项并收束，不扩写 Feature／Player、Cull 或阴影通过；独立只读核对也确认实际源几何、alpha、返回身份、UV／重心与执行资格吻合。下一阶段先明确剩余承诺的决策缺口，不按材质矩阵顺次增加运行。
