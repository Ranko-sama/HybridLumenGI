# 普通URP Lit静态MPB覆盖可随资产页保存

直接资产页导出现在会将受支持的有效MPB输入保存成各槽独立的材质资产。相同共享材质的不同覆盖不会串用；非空slot块仍整体替代Renderer块，覆盖纹理进入既有页面依赖图。颜色使用现有材质来源合同处理作者空间／shader空间，HDR与alpha保持；原关键词和栅格状态不由MPB数字值重新推导。原源对象不被改写。

复用`HybridLumenGIMaterialSource`／`HitMaterialData`已有字段，未增加运行时页格式或通用MPB序列化系统。无MPB导出沿用原资产；静态覆盖仅保存导出时状态，不跟随后续动画或MPB变化。范围见[使用说明](../../../Documentation/IndependentAssetPages.md#static-urp-lit-overrides)，任意自定义Shader参数／数组／buffer不在该能力内，RenderTexture继续拒绝。统一aggregate生成器保留其单独限制。

## 实际结果与保留的失败

Unity6000.0.85f1、URP17、DX12／Linear。第三次运行实际导出、保存rig prefab并加载所产AssetBundle：两槽得到独立材质；覆盖纹理及BaseMap／Detail UV变换、标量、源Cull和关键词保持。[原result03](result03.json)中六项既有ColorContract shader输入对照的最大误差为1.1176×10⁻⁸；HDR及slot1输入零差。比较的是实际原始MPB与重新加载材质的shader输入，不把`SetColor`调用参数当作shader空间值，也不是整景GI物理误差。沿用既有小型颜色探针的容差，没有新参考积分或生产质量门槛。

该运行末尾的`sourcePreserved=false`及native1完整保留。辅助检查误用了GPU历史的`IsCurrent`：它还包含managed引用、纹理更新计数和mip状态，且快照取得早于`SaveAssets`。输入资产保存后的关键词也与最初脚本调用状态不同；未定位原短路表达式的具体失败字段，不能把它改写为通过或归因成“仅引用变化”。

因此只补了[直接源值检查](result04.json)：以`SaveAssets`完成后、`Export`之前的真实材质／MPB／ST／纹理和资产槽绑定为起点，导出后重新读取同一组值。记录的前后状态完全相同，`sourcePreserved=true`，native0。未重复此前已成功的prefab／bundle加载或GPU颜色对照。

该固定输入在保存后的实际关键词集合为空，前后相同；不据此声称实际验证了所有非空关键词变体。

前两次失败均发生于导出前的辅助输入准备：仍以`CreateAsset`前的managed材质引用调用实际槽身份合同；首轮没有保留`TryCapture`的reason，第二轮补出`Material slot changed before observation`。修正为从Renderer取当前材质引用后才进入实际导出。原[result](result.json)、[result02](result02.json)及执行脚本保留，没有修改产品源身份规则。

## 交付边界

关闭原目标1／3、工作流7／8中“普通URP Lit静态覆盖无法随直接资产页导出保持”的功能缺口，先前仅拒绝MPB的保护已由本能力取代。这个结论不覆盖任意MPB、运行时变化、完整材质矩阵或G4/G5生产验收。

本机工程已导入此Editor实现，临时检查组件已移除。最后Unity PID2960正常native0退出；第三次PID8548的native1原样保留。源与导出资产保留在本机`Assets/HLGIMpbPersistence03`／`04`及对应StreamingAssets目录。没有Player构建、性能窗口、哈希核验、整景GI参考或进一步重测；[Release85](<I:/Unity test/Comparison/Builds/LocalRelease85/Start-LocalRelease.cmd>)及颜色／换色残留／动态拖影／收敛的既有结论保持来源不变。
