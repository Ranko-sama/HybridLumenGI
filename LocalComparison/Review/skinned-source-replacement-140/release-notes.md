# Release124 · 蒙皮来源切换

同一个 `SkinnedMeshRenderer` 替换或清空 `sharedMesh` 时，旧版仍可能把上一个网格的 Mesh、SDF 和图卡用于 GI。Release124 在下一次帧级渲染准备撤回旧快照、取消旧作业。运行中的作业实际结束后才释放私有快照，已发布快照沿现有 GPU 栅栏退休。替换网格按原预算捕获，再成套发布。

实际组件的 CPU 回归覆盖同一 Renderer 从 A 换到 B、再清空来源。它验证了旧 Mesh／SDF／图卡撤回、旧作业取消后无法发布、B 成套发布、借用网格仍由调用方持有，以及通过模拟完成票据释放旧快照。首次套件运行复用了既有用例的门闩编号，修正后又定位到 `SourceMesh` 已从表达式属性改为 getter 的旧源码断言。两处测试准备问题均已修正，最终套件通过。[修复代码](https://github.com/Ranko-sama/HybridLumenGI/blob/72025a44eabb527f39dbaacdd2c197bafe76fa86/Runtime/HybridLumenGIDeformedMesh.cs) · [形变来源与帧边界](https://github.com/Ranko-sama/HybridLumenGI/blob/72025a44eabb527f39dbaacdd2c197bafe76fa86/Documentation/DeformedGeometry.md)

普通 Windows x64 运行包与可编辑工程使用同版源码，沿用 Release123 的场景、资源页和离线画册。完整解压 Windows 附件后双击 `Start-LocalRelease.cmd`。工程使用 Unity 6000.0.85f1 和 URP 17.0.4，原创内容采用 Apache-2.0，第三方许可和通知随附。

本次验证范围为实际 C# 组件与受控后台任务、适配器退休票据，以及普通 Player 构建。形变画质、实际 GPU 退休和生产负载性能继续按原 G3–G5 条件验收。两室关门的实测画面保留 Release123 的来源。[既有同曝光对照](https://github.com/Ranko-sama/HybridLumenGI/blob/68d52e4d/LocalComparison/Review/portal-recovery-138/result.md)
