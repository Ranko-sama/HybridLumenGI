# 切换 URP Renderer 后的双相机页退休

复用独立分页 HLOD 的实际 AssetBundle 和一个粗根。两台启用且自动渲染的 Game Base 相机先用含 Hybrid Lumen GI 的 Renderer A，在各自的 128×64 目标取得粗根发布。随后依次用 `UniversalAdditionalCameraData.SetRenderer(1)` 切到同一管线资产中没有该 Feature 的 Renderer B。第一台切走时撤回粗根需求，绑定组件继续启用。第二台继续在 A 完成准备，直到它也切走。使用 Unity 6000.0.85f1、URP 17.0.4、DX12 Editor 和软件 GI 路径。

| 阶段 | Release134 | 候选 |
| --- | --- | --- |
| 两台相机使用 A | 绑定有效，2 份页引用 | 绑定有效，2 份页引用 |
| 仅第一台改用 B | 第二台持续在 A 发布，完整租约保留 | 第二台持续在 A 发布，完整租约保留 |
| 两台均改用 B | 后续 24 个实际上下文仍绑住 2 份引用，未进入退休 | 下一个上下文解绑，2 份引用仍在，2 份租约进入退休 |
| 完成后 | 页驻留账目 7292 字节，包账目 36562 字节 | 旧页状态均为 Unloaded，引用、退休租约、驻留、包和在途账目归零 |

两台相机在观察期间均保持 active、enabled 和 Base。离开的相机没有再推进旧 Feature 的准备帧。候选第 15 个上下文结束时已解绑 Renderer 和网格，第 17 个上下文后读取到归零。租约完成仍使用资源退休协调器在实际上下文尾提交的 DX12 栅栏。最初同时使用显式请求与自动渲染的观察未通过切换控制，采用的是随后同场景的自动渲染对照。[Release134 实录](<I:/Unity test/Comparison/RendererRetirement152/baseline-auto.json>) · [候选实录](<I:/Unity test/Comparison/RendererRetirement152/candidate-auto.json>)

资源页保留现在比较相机当前选择的 Renderer 与该 Scene 上次准备的实际 Renderer。若查询期间 Unity 重建 Renderer 并改变消费者注册，当前释放步会保守等待下次查询。实测覆盖两个已配置 Renderer 的切换与单个组的实际归还。Renderer 重建、普通 Player、多组压力和生产性能分别验收。
