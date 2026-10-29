# Surface视差UV：首个候选的有限结果与控制失败

原目标1/4、工作流2/7。基线55c74f1；实际Pro65下一方案与Astra同意补普通Surface遗漏的stock Lit视差UV。普通捕获准入该材质，当前UV路径却没有偏移；身份历史对parallax的拒绝不阻止普通捕获。产品与独立参考两线并行，未改Feature、其他材质路径或身份规则。

候选只修改Surface.shader，26新增/1替换行。新增原材质同名高度纹理/比例、同时覆盖VS/PS的multi_compile_local，以及条件顶点输入和viewDirTS插值。顶点视线按锁定URP函数生成；片元在第一次材质读取前只调用一次Core ParallaxMapping，后续所有读取复用偏移UV，detail随后应用自己的ST。保留65的最终反射率夹取。候选SHA256为289acdf7ef8a05e48c9cff491f7e5d823820ab77a0047bf655bf92bc3a97cb6a。

独立参考先于产品编辑冻结。一个固定三角的不同N/T和视线经三个实际Vert调用再插值，可区分错误的片元框架重建。只有非零视差、keyword-off、height=.5零偏移三个案例。全部材质UV、漫反射、AO、发光使用事前2e-6数值界；off/zero另要求完整记录逐位相同。使用未改的既有WARP宿主与明确纹理/光栅适配，非原生Unity或实际附件格式验证。

首个旧源命令exit0，旧UV(.48,.4)与独立URP偏移(.5021881569,.41407039769)明显不同。首个候选命令exit1，已立即停止：

- 主非零案例通过，六种材质读取及detail偏移都匹配独立参考。
- 零偏移案例所有数值界、有限性、主UV、clip/validity/policy通过，但三个diffuse通道及detailUV.x各相差一个binary32 ULP，违反原逐位控制合同。其余记录相同。
- 候选keyword-off和四个完整顶点/片元编译尚未执行。没有行为重跑、容差变更或候选再编辑。

原失败、原数组、原分析和编译产物完整保留，见[结果](../LocalComparison/Review/surface-parallax-uv-01/result.txt)。旧源DXIL直接存储折叠后的常量；候选DXIL在依赖高度的路径中包含fast乘加。这是浮点优化差异的源码证据，尚未进行逐指令数值归因，不能把推测写成已证明。

实际Pro66的[裁决](../LocalComparison/Review/surface-parallax-uv-01/gpt6-pro-failure-review-and-continuation.txt)为SIMPLIFY：不改产品或优化设置，仅对原零偏移记录四个已识别float字段授予原2e-6界的显式数值资格，其余字节继续精确一致；再完成原未执行的off控制与四个完整编译。原逐位FAIL不改写为通过。Astra先独立给出相同的简化建议。

唯一续行已首次通过，exit0。对原始主案例与零偏移数组作离线复核，四字段满足原独立参考与数值界，其余字节不变；keyword-off完整368字节与旧源相同且原数值检查通过；四个完整Vert/Frag off/on入口均编译成功。候选、依赖、工具和原证据前后身份一致，没有重新编译/dispatch on、重建宿主或新增案例。见[续行结果](../LocalComparison/Review/surface-parallax-uv-01/continuation/analysis.json)与[完整命令](../LocalComparison/Review/surface-parallax-uv-01/continuation-command.json)。

Pro已在裁决中明确：上述剩余项首次通过且来源不变即批准本地提交与有限结项，因此无需再重复一轮审查。本次最终结论是“原逐位合同FAIL保留；零偏移获显式数值资格；其余原控制与完整编译通过”。这条材质线结束，不再追加等价夹具。

累计材质投入包含36/51/52/65/66。整体颜色反弹、动态质量、原生keyword/属性传递及生产验收均未被本次结果关闭；Unity部署和普通Release入口不变。
