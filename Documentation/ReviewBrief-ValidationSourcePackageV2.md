# 同场景 HDR 来源包与固定序列接线

2026-10-29：现有 ValidationSequence 的来源导出、同帧合成分解、自动 SDF/charts 烘焙及 720 帧运行已接通。最终第 09 次来源在真实 Unity 6000.0.85f1 / URP 17.0.4 / DX12 / Linear 中完成；这是数据与接线验收，独立物理参考、整体画质和生产性能仍未通过。普通可运行入口仍为 Release73／95a3213，未用源码工作区冒充已更新的 Player。

## 实现

- 新增物理 `source.json` 与逐帧动态状态；可读网格、材质/MPB、灯、环境、渲染配置和资产内容单独归档。原场景、产品代码、SDF/charts 等导出来源保留在独立 provenance 中。无法表达的输入显式 unsupported。
- 在同一次 RenderGraph 中保存 `cameraBeforeHLGI`、`cameraAfterHLGI`、`filteredD` 及七路支持纹理。范围是 skybox 后、透明物体前的 HLGI 合成边界。深度使用显式 Depth 子资源整数 Load；保留原始 Linear RGBA32F、有效性掩码、精确相机矩阵与来源哈希。
- 默认关闭导出；开启时每项采集绑定实际 camera/feature/engine/work/epoch，并使用有界自有 staging/readback。失败和退出不提前释放可能在 GPU 使用中的存储，不生成物理质量通过结论。
- 原验证场景的 20 个代理自动烘焙、校验并绑定一个共享网格的 SDF/charts；每个 Run 保存明确无 Unity 烘焙 GI 的 LightingSettings。导出器逐个检查所有已加载场景的 LightingDataAsset，非空且未解码时仍拒绝完整来源。
- 显式 StandardRequest 维持每逻辑帧一次渲染。宿主先完成 Editor 来源归档，再等待同一 URP 管线跨两个完整 Update 稳定；没有 GI 预热。正式运行中计数跳过、重置和额外渲染仍失败。

## 最终证据

[09 首次数据分析](../LocalComparison/Review/validation-package-v2-09/package-verification-first.json)确认 720 个逻辑帧、engine 4–723、GI 1–720 连续；32 个选择时点、三路信号、七路支持纹理和旧 endCamera 输出均完整，全部 RGBA 数值有限，所有声明文件的尺寸、哈希、掩码和逐帧来源符合协议。`candidateStatus=complete`、`sourceUnsupported=[]`。

`filteredD` 的 1,843,200 个采样像素中有 202,161 个明确未知；未知不按黑色或质量成功处理。没有独立参考，冻结比较器返回 exit 2 / `reference-required`，`physicalQualityPassed=null`。`cameraAfter-cameraBefore` 只用于解释合成，不能替代独立反弹参考。

[执行与恢复核验](../LocalComparison/Review/validation-package-v2-09/execution-verification.json)逐项确认 118 份产品源码、两程序集预编译、运行时同一个管线/Pass、三份受保护工程文件、归档中的 20 组 SDF/charts 引用及临时根目录恢复。[原生日志检查](../LocalComparison/Review/validation-package-v2-09/native-log-analysis.json)未发现列出的设备、编译、引用、读回或未决退休错误；最终记录的产品 owner 和资源计账归零，不据此宣称整个进程没有任何内存占用。

最终来源冻结 SHA256：`97839818ebffbc576653fd012f521de23082b90528b67d1a5cf140b117f6f93d`。物理来源 SHA256：`d57d519d8f205065de3c2e7d890cf73915d4b22c556071b36e2568eb20d52077`。完整原始数据位于 `I:/Unity test/Comparison/ValidationPackageV209`；[同数据合成预览](<I:/Unity test/Comparison/ValidationPackageV209-composition-01/index.html>)使用固定曝光与显示映射，不改原始采集文件。raw GPU 纹理行顺序和实际 GPU 投影必须共同解释，不能只凭预览朝向推断相机输入。

用户同时运行游戏。宿主耗时、GPU 占用和采集 IO 不构成受控性能比较，本次不报告提速或回退。

## 保留的首次失败

| 次数 | 实际结果与后续处理 |
| --- | --- |
| 01 | 未命名空场景不能并行创建 Additive scene；生成器只对干净单空场景使用 Single，并恢复空场景。 |
| 02 | 宿主用 currentPipeline 非空作为 SupportsRenderRequest 的前置条件，阻止了后者初始化；保留唯一强制停止、文件恢复及场景缓存语义恢复记录。 |
| 03 | `Lightmapping.lightingSettings` 在无设置时抛异常；先改 TryGet，最终导出器改用逐场景 getter。 |
| 04–05 | 首帧深度采集拒绝 D32S8；扩充准确深度格式并使用 Depth 子资源，再移除对 DSV 附件的错误 Sample 能力检查。05 未记录各布尔条件，不声称其唯一条件已被实测。 |
| 06 | 首帧全部采集成功，第二帧 GI 计数仍为 1；提前归档没有消除该问题。 |
| 07 | 宿主被动记录证明首、次帧之间整个管线和 Pass 均被替换，新对象重新从 1 开始。正式采集改在启动稳定后开始，没有放宽连续性门。 |
| 08 | 完成 720 帧与数据完整性；来源仍有内置 LightingDataAsset 未解码标记，保持 incomplete。其首次 Python 分析报告 exit 2，外层 PowerShell 未转发导致命令显示 1；09 显式转发，未改判据。 |
| 09 | 明确保存新场景无烘焙设置并逐场景导出；完整数据、来源与恢复通过，物理参考仍缺失。 |

01–09 各自部署、预编译、冻结、运行日志和恢复记录保留于 `LocalComparison/Review/validation-package-v2-*`，没有覆盖失败数据。后续依原计划继续同场景动态使用、流式/HLOD/后端切换与独立参考求解；不追加无具体问题的测试矩阵。
