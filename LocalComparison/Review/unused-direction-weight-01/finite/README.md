# 有限方向权重对照

由主线程执行 `run.py` 一次。此准备阶段没有编译或运行。脚本从 `ff3805d` 读取真实旧源码，从当前工作区读取候选；只使用已存在的 `ReceiverTemporalWarp.exe`，不创建 host、不运行 Unity、不计算哈希。

固定七行：area 开/关与 emissive 开/关的四个正常组合；area 开/关的非有限 normal；area 开启、emissive 有效但 CDF 宽度为正无穷的 PDF 拒绝。最后一行是有意非法的资源输入，不声称正常 proposal builder 会生成它。它用 seed 0、+Z 发光球和正无穷 PMF，产生有限正向方向及非有限完整 PDF；不能用会被 `pmf>0` 跳过的 NaN 替代。

每个输入运行实际 screen/cache 两个 sample → Matched → direction finite 前缀。Sampler、vMF/PDF、RNG、Cosine、旧两分量采样及 Matched 函数算术不复制、不改写。资源适配只有 proposal StructuredBuffer 改成本线程固定数组、原常量改为输入；调用前缀只提升局部声明并插入观测赋值，以保留拒绝后的原始结果。

比较方向、RNG、Matched 与 caller 拒绝；只在 caller 接受时比较最终 weight。有限值逐位相等，不使用容差；NaN 两侧必须同为 NaN，不要求 payload 相同。preweight 和拒绝后未消费的 weight 仅记录。输出二进制不规范化 NaN，JSON 用字符串标记非有限值并保留所有 uint32 原始字。

默认结果为本目录 `output/result.json`、`baseline.bin` 和 `candidate.bin`。`output/` 已存在就拒绝运行，不覆盖首结果，也不自动重试。本范围不是真实纹理/Unity、射线命中、面积光贡献积分、分布或性能验证；实际完整 CSTrace 编译及性能窗口由主线程决定。
