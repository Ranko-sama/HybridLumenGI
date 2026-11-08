# 镜像网格的子网格剔除与远层命中

关闭原计划第 9 节、T2／G4 的一个具体缺口。对同一个负 X 缩放的 MeshRenderer，精确软件 BVH 与实际 DXR 都按各子网格的来源 Cull 排除不合法近面，并返回更远的合法表面。两条路径分别对照运行前固定的几何与材质预期。

2026-11-08，在 Release123 同源工程（产品提交 `66880c5f`）内执行一次。环境为 Unity 6000.0.85f1、Direct3D12、RTX 2080 Ti。使用普通 Lit、一个实际 owner、一个 mesh、两个精确实例及四个三角。材质经 Scene／SurfaceCache 准入和实际 MaterialSource／Batch，软件由生产三角 provider 构建 BVH，DXR 录制实际 RTAS build。两个材质行均已解析，无贴图上传、未知材质或近似回退。[Release123 工程来源](../portal-recovery-138/delivery.json) · [原始读回](result.json)

## 固定输入与读回

局部红层 z=0、xy 半边长 1、submesh 0、Cull Front。蓝层 z=1、xy 半边长 2、submesh 1、Cull Back。每层源三角索引为 `0,2,1,0,3,2` 加本层顶点偏移，来源法线均为 `(0,0,-1)`，UV 由本地 xy 线性映射。材质均为不透明 dielectric，metallic=0。Renderer 缩放为 `(-1,1,1)`，位置与旋转为默认值。

射线世界 xy 均为 `(-.625,-.375)`，源 x 为 `+.625`。执行零足迹的普通表面查询，解析来源命中材质，maxT=4。表中读数由两条路径分别实际返回。

| 原点 z 与方向 | 预期拒绝的近层 | 实际远层 | t | 源 UV | 源重心坐标 | 漫反射 RGB |
| --- | --- | --- | --- | --- | --- | --- |
| −1，+Z | 红色正面 | 蓝色正面，submesh 1 | 2 | (.65625,.40625) | (.40625,.25) | (0,0,.96) |
| 2，−Z | 蓝色背面 | 红色背面，submesh 0 | 2 | (.8125,.3125) | (.3125,.5) | (.96,0,0) |

四个返回都指向 owner `stableId=1`、owner／geometry revision 3、各自的 submesh 实例和 primitive 0。来源 rawNg 都为 `(0,0,-1)`，方向标记分别为已知正面、已知背面。距离、UV、重心和 rawNg 满足预定 2e−6 容差，RGB 满足 2e−5 容差。两个 kernel 都写回了各自的实际查询结果，compute 错误为空，Unity 退出码为 0，场景设置已恢复。冻结输入、执行入口和退出记录保留在本机 `I:/Unity test/Comparison/ExactCull139Setup`，日志为 `I:/Unity test/Logs/ExactCull139.log`。

## 适用范围

Astra Max 同意采用这个静态不透明镜像双层的精确表面查询结果。真实光栅、阴影剔除、贴图采样、形变、图卡及混合回退继续按各自条件验收。本次读回仅用于功能判断。退出日志记录了 Unity D3D12 的 1 MiB scratch buffer 仍未释放提示，归因未定，资源寿命另按 G4／G5 验收。
