# Release180 同源动态贴图的跨相机上传

当多个 Base 相机读取同一个动态 RenderTexture 时，各自的帧内复制可能对应不同生产内容。旧版以贴图引用识别共享帧额度的等待者。前序相机可以消费后序相机保留的额度并清掉等待，后序命中材质反复处于未知。Release180 从普通渲染入口传入当前相机。不可复用的复制按来源和相机分别排队，可复用的静态页仍沿用来源共享。来源失效会撤回相关等待，离场的请求按原帧龄过期。[实际入口](../../../Runtime/HybridLumenGIRendererFeature.cs) · [额度与等待](../../../Runtime/HybridLumenGIRayTexturePool.cs)

旧新版使用相同的 C# Batch 输入。三个消费者始终按 A、B、C 录制，每次更新同一张 516×127 RGBAFloat 无 mip RenderTexture。每份复制含元数据恰为 1 MiB，共享帧额度为 1 MiB。此尺寸和复制账量沿用原双 Base 实机观察，原观察的第二个来源是独立静态页。[原生输入依据](../native-camera-texture-turn-182/result.md)

| 录制顺序 | 首帧 | 第二帧 | 第三帧 | 第四帧 |
| --- | --- | --- | --- | --- |
| Release179 获得复制的相机 | A | A | A | A |
| Release180 获得复制的相机 | A | B | C | A |

两侧每帧均计 1 MiB，录制复制的批次获得有效的材质句柄，等待中的批次保留未知。旧版宿主的入口适配仅接收并忽略新增的相机参数，实际复制逻辑来自原源码。同次检查保留了异源竞争、在飞读者、受控退休、跨相机静态页复用和请求撤回。Astra Max 按 CPU 准入和命令录制范围采用。实际 GPU 完成、多个相机的画面和生产负载按原条件验收。[定向用例](../../../Tests/StandaloneHitMaterialBatch/Program.cs.txt)
