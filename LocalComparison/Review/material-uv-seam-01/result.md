# 普通材质／UV 接缝的图集与锚点

**固定静态两槽接缝的图集颜色、位置和锚点归属已有实际依据；完整冻结合同仍为 `insufficient-binding-values`。** 四条三角绑定的返回数值在观察脚本的 JSON 序列化中丢失，不能用 `available=true` 或图卡元数据替代。没有据此修改产品、补采或发版，G2／T4 整体继续开放。

## 已观察的子结论

| 事先确定的源域 | 左槽／card 0／chart 1 | 右槽／card 1／chart 3 |
| --- | ---: | ---: |
| 颜色及位置检查像素 | 1,710 | 1,710 |
| 未覆盖／位置超差／颜色超差 | 0／0／0 | 0／0／0 |
| 最大绝对位置差，世界单位 | 0.0000147830 | 0.0000147830 |
| 最大绝对 RGB 差 | 0.000784376 | 0.000784376 |
| 两种预期源色的像素数 | 855／855 | 855／855 |
| 距接缝最近两排内部纹素 | 59，均无超差 | 58，均无超差 |
| 预声明 stripe tie 排除数 | 30 | 30 |

位置容差为运行前固定的 0.00002，逐像素 RGB 最大通道差容差为 2/255。域由保存的源几何、图卡投影及纹素中心计算，未用实际有效性筛点；原生行序保留。靠缝子域同样先按预期位置选择，最远距 x=0 约 0.030323 世界单位，不声称精确边线的亚纹素覆盖。排除的 60 个点是预先声明的点采样分色边界，未将其视为通过或黑色。

每侧 16 个 patch 单元中，12 个有源几何覆盖、4 个为空。实际 **24 个有覆盖锚点**均处于各自半开单元，并具有有效覆盖和正确来源位置；其中 **20 个核对了颜色，4 个恰在 stripe tie，不作颜色判定**。8 个空单元的锚点均为 (-1,-1)。这核对坐标与实际像素，不以 ready 卡数代替。

输入确实可辨别错配：若交换材质槽，每侧 1,710 个检查像素都会不同；若忽略右侧 UV 旋转，右侧 855 个像素会不同。这只是对固定输入的解析辨别量，没有新增运行。元数据中的 owner、chart 及矩阵与保存的源 chart 相符，两个 chart 各保存其原 submesh 的两片三角。

## 输入、实际入口与范围

Unity 6000.0.85f1／URP 17.0.4，RTX 2080 Ti，D3D12／Linear。一个单位变换 XY 网格，z=0，源法线 +Z；左槽 x∈[-1,0]、右槽 x∈[0,1]，y∈[0,1]。接缝位置相同、顶点及 UV 分开。左 UV=(x+1,y)，右 UV=(y,1-x)。两个普通不透明 Lit 材质均为白色、metallic=0、Cull Back；8×8 线性、Point、无 mip 纹理分别沿 U 分成红／绿和蓝／黄。预期图集漫反射为源 albedo×0.96，容差覆盖 half／RGBA8 存储；这不是整景辐照度或颜色反弹误差。

首次 Editor 进程 33524 只创建保存源 Mesh、charts、capture mesh 子资产、材质及纹理，正常退出；第二进程 33224 重开同一工程、加载这些持久化资产，执行生产 `SurfaceCache.Prepare/RecordCapture` **一次**。图集 128×128、tile 64、patch grid 4。直接读取完整 diffuse、position、emission-validity 图集及实际 metadata／anchor buffer，不添加 compute 适配器或产品插桩。两次原生退出码均为 0，原场景设置已恢复。invert-culling 均为 false，全局 A2C 可用值均为 0。

当前所用七个直接相关生产文件已在启动入口按文本与工作区比较，未安装或改写产品。该主干的产品代码仍归 Release122／`7c08327`；本次没有普通 Feature 合成、光照缓存收敛或 Player 画面观察。

## 缺失记录与收束

首次分析在访问 binding 的 `value` 时抛出 `KeyError: 'value'`，没有生成判断结果。原因是观察脚本通过 `JsonUtility` 嵌套保存生产的 `TriangleChartBinding`，该结构体未标记 Serializable；原输出保留四条 `available=true`，但缺少返回的四个 uint。主线程遗漏了这个序列化问题。后续没有重启 Unity 或修改原始输出。

在 Astra Max 审查后，分析只用完整保存的 metadata 定位源 chart 对应的图集，继续原有几何／UV／位置／颜色／锚点计算，所有原阈值与样点不变；这**不能重建实际 binding 返回值**。因此 `bindingIdentityMatches` 和完整 `satisfied` 均为 null，只有 `atlasAnchorSatisfied=true`。Astra Max 同意按此子范围交付并结束。

本结果不覆盖完整三角绑定合同、镜像／其他变换、Bilinear／mip 接缝、MPB 更新、池复用、缓存照明、精确射线材质、最终 GI 画面、性能或 Player。没有新的产品故障依据，不把这次记录疏漏变成扩建验证系统的理由。

[冻结合同](contract.md) · [数值结果](result.json) · [原生捕获及源输入](capture.json) · [完整图集／锚点与固定域](signals.npz) · [分析脚本](analyze.py) · [本机原始输出](<I:/Unity test/Comparison/SurfaceSeam125>) · [两次退出与已恢复观察资产](<I:/Unity test/Comparison/SurfaceSeam125Setup>)

复算使用 Python／NumPy，将本目录作为第一个参数、一个尚不存在的输出目录作为第二参数：`python analyze.py <本目录> <新输出目录>`。既有数据格式兼容不改变上面的判据。
