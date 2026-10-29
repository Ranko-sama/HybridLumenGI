# 真实色墙变色和关灯的有限动态响应

2026-10-29。产品来源 `269241b38c45a97f29758fb92640cdb36f5092f8`；完整 Feature、DX12 / RTX2080Ti / Unity6000.0.85f1 / URP17.0.4、Linear、640×360。此次没有新增 Runtime 修改，也没有使用 Codex with ChatGPT。

使用静态有限色墙参考的几何与材质来源，执行一次固定 96 帧的真实动态序列。前 32 帧建立旧颜色历史，帧 32 通过普通 `MaterialPropertyBlock.SetVector` 将线性色墙从 `(.5,.25,.125)` 改成 `(.125,.25,.5)`，帧 64 通过普通 `Light.enabled=false` 关灯。没有调用手动失效、强制重置、更换采样种子、额外预热或延长采样窗口。

此项隔离屏幕历史：8 rays/pixel、历史上限 32、当前权重 .08；世界反馈、引导、屏幕追踪、环境、发光、radiance clamp 和空间滤波关闭。它补充实际材质变化域和方向光变化输入下的动态历史证据，不证明默认多次反弹、物体运动、镜头运动或整景画质。

## 执行与数据

相机关闭自动渲染，每个连续引擎帧提交完整 URP StandardRequest。96 次请求、相机 begin/end、上下文 begin/end 均为 96；引擎帧为 1–96。普通启动导致最初两个实际 Work.frame 均为 0，其后正常递增，最后为 94；分析使用实际 Work.frame，不用请求编号替代。

在实际 Temporal dispatch 之后，通过只复制数据的临时 compute 入口，读取 27 个固定接收点及各自 5×5 支持域：当前 raw、history、moments、读入的历史和 moments、当前/之前 geometry 和 material、motion、实际全局参数与活动变化域。没有导出产品的历史有效性分支作为参考答案，也未替换传输或时间融合算式。

112 个产品源、8 个临时接线文件、双程序集预检、实际 GPU 读回和退出/恢复通过核对。全部帧的两块精确 DXR 几何及材质来源就绪，没有近似后端回退。临时文件已归档后移除，产品、Quality/Graphics 设置和既有 Functional 场景恢复一致。

首个渲染耗时 **141.3432 秒**，整段采集 142.2550 秒。这里没有测量稳态 GPU 成本或判定性能达标；首次使用等待仍是限制。日志中已有许可、D3D12 info queue 和编译警告保留，未当作零警告运行。

## 冻结首分析结果

运行前冻结的 `analyze.py` 首次执行通过 2,592 个中心接收器检查；没有 unknown 或 uncovered 条目。首分析保留为 `analysis-first.json`，其源码及输入二进制不覆盖。

- 旧色和新色分别有 711 / 721 个正值可信样本，所有当前可信 RGB 符合对应 4:2:1 / 1:2:4 色比。27 个点在换色当帧都有可信当前估计；随机射线未命中时允许可信黑，各点首次新色正值出现在第 0–2 帧。
- 换色前历史长度均为 31；换色当帧，接收器在非几何的局部影响域内，历史长度均降到 2，而非重置为 1。之后恢复累积，帧 63 达到 32。
- 关灯当帧的 27 个中心及记录支持域当前估计都是可信黑。方向光变化输入为全局 reactive、非几何变化；中心历史长度均降为 2。
- 关灯当帧最大历史分量 `0.019989013671875`，低于预先推导的 half 上界 `0.0200042724609375`；第 31 个后续帧最大分量 `0.0005726814270019531`，低于上界 `0.0005865097045898438`。上界由黑色 3×3 输入、方差夹取、样本数、当前权重和存储误差推导，不用观察到的残留拟合。

独立输入资格层随后对换色帧和 32 个关灯帧的 **891 个目标全部通过**，未覆盖数为 0。该层在读取本次 GPU 输入前完成并冻结，先通过 8 组纯输入正负测试；测试首轮仅有负例原因字符串错配，原源码与结果保留，分类门槛未改。它通过实际 motion/矩阵重投影的区间支持、前后几何平面距离、Ns/Ng 点积、材质差和历史 confidence/moments 证明输入条件；不解码 radiance RGB 数值，仅检查其二进制指数位是否有限。不能证明支持或历史无效的情况会判未覆盖，避免把无效零值误认为衰减。原首分析、32 项衰减上界和所有原始 GPU 数据保持不变；组合结论通过。

## 可复核材料

- [固定合同](../LocalComparison/Review/finite-wall-dynamic-response-01/contract.txt)、[首分析](../LocalComparison/Review/finite-wall-dynamic-response-01/analysis-first.json)、[独立输入资格](../LocalComparison/Review/finite-wall-dynamic-response-01/qualification/input-result.json)、[执行来源与恢复](../LocalComparison/Review/finite-wall-dynamic-response-01/execution-receipt.json)。
- [旧色预览](../LocalComparison/Review/finite-wall-dynamic-response-01/native/final-031-preview.png)、[新色预览](../LocalComparison/Review/finite-wall-dynamic-response-01/native/final-063-preview.png)、[关灯末帧预览](../LocalComparison/Review/finite-wall-dynamic-response-01/native/final-095-preview.png)。图像使用固定显示映射；定量分析读取原始数据。

四项目标与十条工作流仍持续推进；本项有限响应证据不关闭 G0–G5。下一工作是实际表面缓存下的有限反馈来源及逐阶颜色验证。
