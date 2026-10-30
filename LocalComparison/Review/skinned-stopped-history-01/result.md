# Skinned 停稳历史：有限采用

关闭原目标2／3、G3的具体缺口：开启receiver对象身份时，普通Skinned来源此前因Renderer类型一律未知，骨骼停稳后仍不能积累屏幕历史。现在只在完整来源与renderer-local骨姿态稳定时恢复既有历史；骨变化继续更换几何代次并拒绝旧历史。不是跨形变重投影。

## 实现与范围

新增私有骨姿态快照，冻结Renderer、mesh、root与各bone引用、局部骨矩阵、SkinQuality及全局skinWeights。矩阵逐元素完全相等，不引入形变容差；完整网格来源检查仍包含bindposes及骨权重。姿态逻辑字节计入原来源预算，捕获前重核。Cloth（包括disabled）、blend shapes、不可读网格、缺失或无效骨保持拒绝；外部GPU顶点写入与自定义顶点变形不在合同内。

身份捕获使用实际SkinnedMeshRenderer的DrawRenderer顶点流；Mesh路径保持原DrawMesh。私有参数按命令排队，实际生效MPB若覆盖私有绑定则拒绝；不改来源MPB。原有精确深度、primitive、冲突、f-1、法线和变化域门槛保留，不新增产品GPU纹理或buffer。

## 必要验证

受影响的三个现有CPU入口通过，覆盖停稳／变形来源、原Mesh与私有参数绑定；Cloth兼容修正后仅重验受影响的ReceiverHistory入口。原生使用为保存的统一场景、640×360／半GI／2ray／filter4、实际DXR，关闭计时及反馈。固定240次RenderRequest，先停稳Skin，119后启动，127后停止，不扩展颜色、性能或BakeMesh检查。

| logical | 状态 | 实际Skin身份像素 | history > 1 | history最小／最大 | key |
| --- | --- | ---: | ---: | ---: | ---: |
| 119 | 初始停稳 | 2739 | 2739 | 32／32 | 28 |
| 120 | 骨变化 | 2739 | 0 | 1／1 | 35 |
| 127 | 骨变化 | 2754 | 0 | 0／1 | 42 |
| 128 | 停止后的首帧 | 2754 | 2726 | 0／2 | 42 |
| 159 | 停稳 | 2754 | 2740 | 0／14 | 42 |
| 239 | 停稳 | 2754 | 2740 | 0／32 | 42 |

最终骨角5.324414°，停止后保持；六点矩与身份有限。结果来自实际uint4身份与float4 moments对应，不是CPU flags代替GPU结果。119与239两张普通Final可见场景及门姿态变化；它们不是噪声改进、颜色准确、无拖影或完整光照收敛的证明。159的历史长度并未达到32，既有其他失效条件仍可重置历史，不承诺固定恢复时间。

原始摘要为[analysis.json](analysis.json)、[usage-result.json](usage-result.json)，图为[初始停稳119](frame-119-final.png)／[最终停稳239](frame-239-final.png)。原生12份binary保留在本机 `I:/Unity test/Comparison/SkinnedStoppedHistory03`，布局见逐帧metadata；不新增哈希或另建归档系统。

## 失败与限制

- native01在Unity编译阶段失败：ClothModule是可选模块，泛型Cloth引用形成硬依赖。改用Unity官方支持的GetComponent("Cloth")存在检查后编译成功，不要求安装Cloth。
- native02完成120次请求，119的整数纹理直接读回被Unity拒绝；moments和Final已生成，但缺身份对应，不能作为功能通过。随后复用既有MovingOccluderIdentityCopy按位拷贝到uint4 buffer，原判据不变。
- native03／PID23728完成240次且退出0，读回pending=0。**退出清理未通过**：仍有owned=5／pending=5、deformationBytes=286208，日志另报与临时拷贝尺寸对应的921600B buffer（驱动983040B）未释放。不能把所有待退休owner均归因观察器，也不能把读回排空当全部GPU fence完成。此次短序列立即退出保留这项限制；不据此声明产品资源或长时验收通过。

三次原生日志及attempt/exit均保留；临时观察器、Renderer配置、QualitySettings及初始化入口已恢复。普通交付构建不包含该观察器或拷贝buffer。采用仅限此停稳历史能力，完整G0–G5仍开放；此线不追加运行。

API依据：[Unity6 DrawRenderer](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Rendering.CommandBuffer.DrawRenderer.html)、[可选模块无静态引用的GetComponent(string)](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Component.GetComponent.html)。
