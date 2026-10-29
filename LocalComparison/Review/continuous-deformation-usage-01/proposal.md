# 69 next-step proposal: usable continuous deformation

User explicitly resumed full local development after the progress estimate. Keep
OriginalDevelopmentPlan's four goals/ten workflows, credible color bounce and stable
dynamics, parallel preparation, and value → smallest solution → correctness. Do not
equate absence of a new bug with completion, or create tests from unchecked labels.

Current HEAD50b63c3 is clean.65/66 material/history fixes and67 current Release were
accepted;68 HLOD cold-start fallback was accepted and committed, not deployed.
Actual Unity deployment and Release67 remain2fefc09.67 produced one readable FinalHDR
and120frames/normalexit; its101.249s first-camera wait is a known limitation, not an
attributed performance defect. Prior26 only applied one readable-mesh shear;43
coalesced producer requests used actual CPU/task adapters, not native continuous use.

## Independent Astra first judgment (before root/Pro/lane proposals)

继续，推进连续形变的实际可用性。43的合并请求仍只有任务适配证据，现有运行入口没有使用它；26只覆盖一次变形，67仍是静态场景。

唯一步骤：复用现有低面数网格，做一个可启动、停止的单对象连续形变示例，使用原RequestCoalescedCapture；两线分别准备场景接入与独立预期，主代理统一原生运行。

最大风险是把快照发布当作动态GI正确。结束条件：运动中持续发布、停稳后追上最终几何、实际绑定对应且图像可判读。有限结果即收束；只有具体反例才改核心，不重开材质或射线矩阵。

## Independent lanes and concrete existing entry points

transport_lane found an ordinary-use gap rather than an algorithm bug: the Release
Bootstrap disables ComparisonCapture/RuntimeAuditProbe and only navigates, so the
user cannot trigger existing door/light/deformation changes. Its smaller alternative
is one door-toggle key using capture.door/doorOffset plus R reset. This would add
interaction but not exercise43's continuously submitted producer demand.

temporal_lane could not attribute101.249s: the measured interval includes HDR target
creation before first endCameraRendering; last-frame readback/EXR encoding cannot
cause it. Unconditional loading of the exact-software fallback shader is only a
candidate; build-time96.27s compilation cannot explain runtime cost. No trace/run was
performed. Do not fold a speculative startup investigation into a dynamic example.

Existing Functional has RuntimeAuditProbe.deformation on Audit deforming occluder,
a low-poly readable MeshFilter. DeformationEventMode in26 cloned this mesh, sheared
upper vertices, requested one capture and retired the owned clone. The ordinary
bootstrap already disables the old automatic mixed sequence. Product exposes
HasSnapshot/GetSourceMesh/PublishedFrame; Proxy exposes current SDF/charts. Prefer
these actual APIs and existing source/binding access over restoring26's large
lifecycle/selected-ray observer. Frozen26 evidence explicitly lacks actual target
ray-hit coverage; do not relabel it.

Need Pro's one minimal plan: a genuinely usable start/stop example reusing the
ordinary local scene and RequestCoalescedCapture, bounded native confirmation of
progress/final catch-up/actual binding and interpretable image, clear ownership and
first-failure exit. Decide whether source-only sample or ordinary Release entry is
the smallest useful deliverable, and exact build/run allowance. No automatic product
algorithm change, new observer framework, timing benchmark, dark/MC/exposure work,
or broad native geometry/material matrix. Root alone owns deployment/Unity/git;
implementation and independent expected-state preparation may proceed in parallel.

## Astra comparison judgment after both alternatives

继续，保留连续形变作为唯一步骤。门开关准备更小，但43的持续请求能力进入真实使用，对原目标3更有价值。

最小范围：单网格、单键启动／停止，复用合并请求；只用公开快照引用与SDF/charts关联，加运动／停稳图像。启动耗时另留，不并入。

最大风险是复活26重观察器或把捕获帧当发布时点。有限窗口内持续推进、停稳后追上最终来源且关联一致即结束；未达则保留结果，不补矩阵、不宣称整体动态画质通过。
