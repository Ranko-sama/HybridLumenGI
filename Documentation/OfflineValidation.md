# integration-15 离线验证记录

更新：2026-10-27。当前汇总覆盖 **73阶段、155项选定DXC、310份来源哈希、61份Runtime/Editor C#语法输入**，封包门控通过。[主报告](../Tests/offline-validation-results.json) SHA256：`79BD33A51C62777250A3CB975E992AF6BE89B565ADE73D82E681A273B3B40A14`；汇总完成时间 `2026-10-27T10:45:56.6040131Z`。

这是 integration-15 生成时的朋友测试候选证据；当时未安装或运行Unity，因此本报告不包含Unity API类型检查、Shader Importer、Player构建、真实DXR、实体GPU或GI图像验收。后来安装Unity后的实际失败/修复与有限运行证据另见 [LocalRuntimeFunctionalAudit](LocalRuntimeFunctionalAudit.md) 和 [runtime-validation-results.json](../Tests/runtime-validation-results.json)，不能归入这份旧来源报告。不等价于完整UE5 Lumen，也不是生产认证。

## 执行组成

本轮完整遍历73阶段，其间保留失败与来源变化。修复后仅重验受影响阶段，并复用相关来源未变的成功编译产物；**不是单次来源未变的全绿运行**。主报告的 `consolidation` 记录原报告身份、七份发生变化的源文件、实际修复调用、来源继承理由和不同调用目录。

- 核心51项：原6个transport入口，加已经完成的3个software temporal/filter/identity入口，加42个剩余入口。重复进入的长编译wrapper被停止，其失败记录保留；没有把中断当作成功。原六入口最终全部默认优化通过。
- 其他基础80项：Native Diffuse 42、Global SDF 3、Receiver Policy 22、Receiver Identity 12、Receiver Temporal helper 1。
- 材质链22项：9份专项报告，绑定131份实际二进制、输入、输出及附属工件。
- 新传输2项：实际AreaEmission和SoftwareTriangleBvh helper，在D3D12 WARP上执行并与独立数值oracle比较；整帧UV/覆盖/光照链仍需Unity图像验收。

核心、Native Diffuse、Global SDF、原生计时、Receiver Policy、Receiver Identity和Receiver Temporal七份伴随JSON随包提供；材质链及新传输报告和产物身份嵌入主报告。C#状态机用明确的Unity依赖适配器，WARP为软件实现，不能扩大证据范围。

## 本轮必要修复

1. 预算审计发现退休的几何属性buffer漏算。实际当前/退休分配改为count×stride计量，分配前检查替换峰值；释放后才扣回。Feature给软件与硬件都传有限额度。既有Backend专项、语法及相关Feature合同定向复验通过。
2. DirectLighting源码合同仍检查旧ProxyRadiance包装函数。改为检查实际带Le权重的求值函数，并额外验证兼容包装按权重1转发；数值oracle未削弱。
3. HitMaterials宿主在30秒fence等待后抛异常，会先析构仍可能被GPU引用的COM资源。相同DXIL/输入在35.15秒完成并通过独立oracle。修复仅限此测试宿主：提交前创建同步对象、180秒有界等待、未证明完成时明确失败退出以避免提前析构。正式三变体复验通过226,800项检查；产品HLSL与oracle未改。旧EXE/源码/失败报告和重放证据均保留。
4. RayTextures报告的输入文件包含12字节头、metadata和纹理arena，不能只按case stride计算总长度。校验器现在检查完整布局；同时允许显式汇总记录各修复阶段真实调用目录，仍严格核对命令、时间、报告哈希与实际产物。未增加负例矩阵或重跑整套。

原73阶段失败报告位于构建机 `TEMP/hlgi-integration15-final-59a14f9c77304f20a5babf55596a9fd3.json`；其SHA与修复报告SHA保存在主报告。历史integration-14及其70阶段结果只属于封存ZIP，不用于证明当前来源。

## 构建成本与限制

本机原精确软件 `CSTrace` 默认优化从17:44:27到18:45:05，DXIL为14,357,532字节；观察到的编译进程峰值工作集约9.65GB。硬件 `CSTrace` 约23分钟、13,597,172字节。编译耗时和内存是该构建机的观测，不是GPU帧时间，也不能预测朋友Unity Importer的精确耗时。原进程在检查终止条件时已正常完成，**没有采用关闭优化的交付配置**。首次导入应保存编译日志并留意构建资源占用。

源码ZIP不包含构建机TEMP的DXIL、listing、EXE、输入输出和Unity includes。主报告绝对路径属于构建机；完整工件复验需保留这些目录或在新环境运行套件生成本机证据，不能把JSON当作可独立搬运的完整运行证据包。朋友导入Unity不需要先安装离线开发工具。

`PackageSource.ps1`检查当前报告，`VerifySourcePackage.ps1`核对ZIP清单、路径、大小和SHA256；可选原生计时包绑定同一源码归档和本轮实际测试的DLL。归档完整性不等于Unity运行成功。

## 朋友端下一步

按 [FriendHandoff](FriendHandoff.md) 先取得导入、软件路径首个画面和Player结果；有阻断先回传日志。之后按 [固定序列](ValidationSequence.md) 回传HDR/状态/日志、精确Unity/URP版本、场景资产和SOURCE-MANIFEST.json。软件/DXR对照、动态稳定性、GPU p95/p99、峰值显存和长时测试留在朋友设备。没有可信参考图或明确阈值时，画质保持待验。
