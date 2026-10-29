# 相机与 TAA 身份稳定性修复

`95a3213` 将身份顶点改为与 URP Lit 相同的 `GetVertexPositionInputs`，使用实际绘制的物体矩阵与 URP 相机矩阵。删除旧的独立 CPU VP/M 上传；片元严格深度比较、alpha、三个 Cull pass、身份冲突及历史拒绝规则保持不变。

原 48 帧场景、相机路径、264 个预声明点与九个观察器文件完整复用。仅两个产品文件改变，其余 110 份产品源不变。已有 CPU 合同、12 个 shader 入口及两程序集预编译通过；随后真实 Unity 6000.0.85f1 / URP 17.0.4 / DX12 完成 48 个连续帧，工程已恢复。

首次分析通过：57 个新显露事件、561 个持续可见点、17 帧非零 jitter；unknown、输出违例、输入资格失败及覆盖失败均为 0。原失败帧 38/39 各有 7 个显露事件，41/42/43 各有 33 个持续点。每个首次显露点仍要求当前可信估计的精确复制及历史年龄 1，持续点仍要求原来源、运动和几何/材质资格与合法历史复用。

此前独立验证过的初始化来源窗口、C# 输入表达式精度与所有可能最近采样地址规则，在本次运行前纳入冻结分析合同；没有根据新输出放宽门槛。源冻结 `8f02156870c1367321fe04389ae5e47b098834876f723524537a8abf25ea02bd`，首次分析 SHA `96f65f49bf752da08e36dd7b356f6ae775e233dd246eea70b90245e9bae036db`。原 02 失败与深度诊断保留。

证据：[运行包](../LocalComparison/Review/camera-motion-taa-response-03/)、[执行与恢复](../LocalComparison/Review/camera-motion-taa-response-03/execution-receipt.json)、[首次分析](../LocalComparison/Review/camera-motion-taa-response-03/analysis-first.json)、[输入合同](../LocalComparison/Review/camera-motion-taa-response-03/input-model.txt)、[诊断](ReviewBrief-CameraIdentityDepthDiagnostic01.md)。

这证明原固定相机/TAA 路径的身份丢失与历史覆盖反例已修复，不代表任意运动、全场景画质或 G0–G5 全部完成。用户同时运行游戏，本次时长不作性能比较。当前普通 Player 的来源须以独立 Release 整合记录为准。
