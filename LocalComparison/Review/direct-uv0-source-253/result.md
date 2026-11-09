# 直接注册的 UV0 覆盖撤销基础网格的精确资格

一片绿色裁剪近板与一片蓝色远板使用普通 URP Lit。近板只有一个材质槽，基础 UV0 在查询点落入透明纹素。仅附加 Float32 UV0 覆盖后，相同材质在原生光栅中心显示实心近板。Release210 的软件和 DXR 继续用基础 UV0 测试覆盖，旧图卡和两条旧精确批次也继续通过来源核对。修复让直接注册的额外 UV0 进入现有来源检查，带覆盖的 owner 由已配置的 SDF 或解析后备表示处理。 [Unity 6 的额外顶点流](https://docs.unity3d.com/kr/6000.0/ScriptReference/MeshRenderer-additionalVertexStreams.html)

| 同一近板 | Release210 原生中心 | Release210 软件／DXR | 修复版软件／DXR |
| --- | --- | --- | --- |
| 基础 UV0 | 蓝 | 远板精确命中，t=2 | 远板精确命中，t=2 |
| 加入覆盖 UV0 | 绿 | 远板精确命中，t=2，近板图卡仍获准 | 近板解析遮挡，t≈1，撤销近板图卡 |
| 移除覆盖 | 蓝 | 远板精确命中，t=2 | 恢复原近板图卡和精确候选，透明处仍命中远板 |

两侧使用 Unity 6000.0.85f1、RTX 2080 Ti 和 D3D12。复用双板夹具的实际 Scene、SurfaceCache、软件 BVH、DXR RTAS 和混合表面／阴影查询。覆盖流只替换 UV0。两后端共用按真实页回读确认的材质批次。修复侧覆盖启用后，两条旧批次和原图卡绑定在重新准备前均被拒绝。原生中心颜色在基线采集，候选只读回查询和图卡资格。两侧恢复场景并正常退出。 [合格基线](baseline.json) · [修复读回](fixed.json)

首次观察在加覆盖前停住。观察器先后建立两份材质批次，DXR 批次撞上正常的纹理页就绪等待，命中带 `MATERIAL_UNKNOWN`。Astra Max 同意一次同输入入口更正，按已有方式先等待真实页就绪，再共用批次。该首次结果单独保留。 [初次资格不足](initial-insufficient.json)

采用范围为直接 MeshRenderer UV0 覆盖的拒旧和后备遮挡。解析后备的颜色与覆盖纹理按原近似范围使用。静态 UV0 导出仍可将有效坐标固化到网格，完整实时顶点流着色、统一示例画质和 G3–G5 验收另按原计划推进。 [原有导出范围](../../../Documentation/IndependentAssetPages.md#build-and-use)
