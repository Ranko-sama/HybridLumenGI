# Unity 功能接线检查（runtime-candidate-16，2026-10-27）

本轮以实际运行效果修复已实现功能，不增加 GI 架构或扩大离线框架。已完成有限 Editor/Player 关卡，停在朋友测试候选；早期诊断失败保留在下面，不能冒充候选验收。

已复用的固定序列结果见 LocalRuntimeFix02.md：精确软件与 SDF 各 720 帧，原黑室严重漏光已修复。旧版、关闭 GI 和未改变的离线证据不重复执行。

## 新发现

- Unity 的实际 LitInput GPU 探针：BaseColor / SpecColor 使用线性转换，HDR EmissionColor 使用原值。`Project/Logs/HybridLumenGI-color-contract.json` 保存六项 GPU 读回。代理材质回退的发光色额外 `.linear` 已移除。
- 旧验证场景设置了发光颜色，却使用 `MaterialGlobalIlluminationFlags.None`。URP 导入器清除了 `_EMISSION`，历史测试没有覆盖发光体采样。场景生成器已改为 RealtimeEmissive；新场景保持发光 keyword。旧结果不修改，但不得再称旧关灯段为“发光仍开启”的测试。
- 新有限功能场景覆盖三张贴图、两个 submesh、alpha clip、normal map、MPB 变化、可读网格形变往返、镜头移动及切换。开启对象身份历史，用 GPU 读回观察其输出。
- `20261027-141042-585748787f404ff5afded2f4f7c689d5` 收集完 720 帧、32 张 HDR、零采集错误，但功能未通过：纹理页停留在回读等待，精确后端退回近似路径；历史最高累计为 1。CPU 发光布局有 12 个三角形不能证明实际 GPU 使用了它们。
- `20261027-140804-24e3a3dd7d2d4af49f36e96fb1220c15` 是诊断工具错误：Unity 不支持该 UInt4 纹理的直接 ReadPixels。已用 compute Load 归约到整数 buffer 后读回；不算产品功能失败。

## 后续修复与最终运行

后续增量：RGB24 贴图在 Unity 中保留 `R8G8B8_SRGB` 逻辑格式，DX12 Sample 能力查询为 false；导入器因此每次都拒绝 Checker。已仅对 RGB8 UNorm/SRGB 查询对应 RGBA8 backing 能力，保留源一致性与 GPU ready 校验。修复后 `20261027-142102-a159a5c31ae54f7e94b40c2b1cf6d20f`：720 帧 / 32 HDR / 零采集错误，719 帧精确软件，仅第1帧等待纹理回读；54800 字节只在首帧上传，图集保存真实 RGB/法线/HDR Le。历史最高32帧。DXR `20261027-142201-c4f287b332614c1e9ad9c24cfb49333c` 同样完成，719帧实际硬件后端（22网格），首次receipt约310秒。

新场景 off `20261027-142823-0496ddbfe4f04bb1b577caa10fbf44eb` 用于新材质/发光差值，不重跑原旧版 off。关灯帧299的 `Final−off` 平均Y为0.004026，软件/DXR平均RGB绝对差约0.00000224。新黑室帧719平均Y约0.000000319。原生替换检查 `20261027-142859-3358730603e1458b939f26479d48fd47` 是刻意120帧的定向探针（run.json标 incomplete-probe，不冒充720完整序列）：非零环境SH、replacement、GI intensity0；相对零环境off，地面固定区域平均RGB误差约6.1e-10，红墙约3.1e-7；未知区域按设计保留原生照明，不要求整图全等。

真实 AssetBundle 导出又发现两项此前离线未暴露的问题：运行时代码引用 Editor-only `Light.lightmapBakeType`，已分支使用 Player `bakingOutput.lightmapBakeType`；BuildAssetBundles 会卸载未被 Unity 场景引用的临时资产，导出器需要按已保存路径重新获取副本后读驻留估算。修复后导出6个实际 LZ4 页并运行 `20261027-143257-40a76cf9bb9e4c5b9016aefedbded1e6`：预算不足时无IO/上传；加载275889字节驻留估算、49404字节bundle；f180旧detail保持、新aggregate预热，f190切换；第二相机持有detail到f270，之后才解绑。逐帧检查又发现f360返回近场有22帧GI覆盖空洞：最后一个detail卸载时丢失已有group，返回时重建为空。已修改 TopLevelRoot 保留已有、仍有效的group根，等待新detail完整就绪再替换；新建独立 FarFieldOnly 的规则不变。最终Player将验证该修复以及220米离场后的资源退休。已运行现有纹理池、灯光、HLOD定向回归，不重跑整套离线验证。

1. 修复纹理上传/历史接线，确认精确软件实际运行、稳定页停止重复上传、材质与形变对图像有效，再在同场景检查 DXR 实际运行。
2. 在一组真实导出资源页上验证近远切换、准备完成后的 HLOD 发布及资源退休；只修阻断，不增加新流式架构。
3. 完成一次最终 Player 构建与运行，冻结新源码、明确支持边界、更新 README 和测试范围并打包。GPU 毫秒/总显存与生产长测不以诊断计数替代。

最终实际 Player：功能场景 `20261027-144902-1340b5f01dd7432fa40a4248445e31b3`，流式场景 `20261027-145323-ef045e1d249442fe80bc034116453c9b`，各720帧/32HDR/零采集错误。功能 Player 717帧为精确软件（3帧启动回读等待），纹理仅首帧上传，历史最高32帧；黑室末帧平均Y约5.19e-7。首次出帧约168秒。Editor/Player有局部像素差异和动态低采样噪点，不宣称逐像素一致。

流式 Player 在f360返回近场时保留aggregate直到detail ready；f119–479没有publication覆盖空洞。第二相机需要detail时不提前解绑。f480移到220米（超过150米far范围），到f487全部页退休，最终resident/bundle计账均为0。这里是资产页计账，不是驱动总VRAM。

仅按修复扩展已有HLOD回归；Astra Max只读确认保留旧组不阻断远场/禁用退休。最终Runtime/Editor全部非meta文件与构建工程哈希一致，来源及运行摘要保存在 `Tests/runtime-validation-results.json`。诊断hook在Player退出前的恢复帧可能追加同一719编号；分析取首次逻辑帧记录，正式capture仍为720份receipt。

已知边界：Editor/Player退出仍有GraphicsBuffer/原生资源释放警告；没有验收长期无增长、GI GPU p95/p99或峰值显存。未逐一认证Skinned、自定义材质、全部lightmap/fog/decal/Forward+组合与薄壁真值。当前不是生产放行，也不声称 UE5 Lumen 完全等价。朋友工程反馈前停止追加运行验证。
