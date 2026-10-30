# 普通骨骼运动历史候选：不采用，保留 Release94

原目标2／G3要求减少运动颗粒且不明显加重拖影。本轮候选使普通URP Lit Skin在运动时可通过现有motion纹理、两帧owner／primitive及来源检查保留最多2个有效历史样本；停稳仍使用94的正常累计。候选在限定原生序列中可达，但没有满足画质采用条件，产品和普通交付恢复至e296750／Release94。不新增G3画质关闭项，不构建Release95。

## 功能结果与停止原因

baseline03与candidate03都完成既定240次请求、640×360／半分辨率GI／2ray／filter4／实际DXR；GPU计时、反馈关闭。观察来自真实identity和moments输出。完整来源见[baseline](baseline/usage-result.json)、[candidate](candidate/usage-result.json)及各自analysis.json。

| 观察点 | baseline：角度／历史最大值 | candidate：角度／历史最大值 |
| --- | --- | --- |
| 静止119 | 0°／32 | 0°／32 |
| 运动120 | 1.569182°／1 | 0.508704°／2 |
| 运动127 | 5.152818°／1 | 4.889201°／2 |
| 停止128 | 5.152818°／2 | 4.889201°／2 |
| 停止159 | 5.152818°／17 | 4.889201°／26 |
| 停止239 | 5.152818°／32 | 4.889201°／32 |

候选120／127的row flags为3，分别有2739／2728个可见Skin像素的历史大于1，最大均为2；初始和末尾恢复32。这只证明功能分支可达与有效历史权重上限，不能证明所有EMA输入的最大年龄、画质或精确收敛。

两侧从120起实际骨角不同，后续120条姿态记录不一致，见[同数据比较](comparison.json)。临时驱动沿用普通交互的unscaledDeltaTime，captureFramerate并未保证这里的同轨迹；不据此解释图像差异。按预先约定的输入不匹配停止条件，不修建新运动驱动、不追加采集、不调cap或放宽其他门槛。

主线程及独立审阅查看127／128／159的Final：门面没有足够可辨认且一致的颗粒改善，静态端点也不能证明连续运动拖影。三对原图保留，未做颜色修饰：

| 时点 | baseline | candidate |
| --- | --- | --- |
| 运动127 | [原图](baseline/frame-127-final.png) | [原图](candidate/frame-127-final.png) |
| 刚停128 | [原图](baseline/frame-128-final.png) | [原图](candidate/frame-128-final.png) |
| 停止159 | [原图](baseline/frame-159-final.png) | [原图](candidate/frame-159-final.png) |

本轮不新增颜色误差或换色／关灯残留结论；不声称运动拖影改善；历史长度恢复不是辐射度收敛时间。原画质、残留、成本结论保留各自版本和范围，见[首页](../../../README.md)。本轮也不是退出清理或25ms／1GiB预算验收。

## 启动纠错与保留成果

baseline01在0请求的前置pass资格检查失败；baseline02把检查后移后，在8请求切换Skin时仍失败，两次失败记录均保留。首次曾推断FindPass调用时机是原因，但该推断不等于已证明唯一原因。

随后核对Unity 6文档及已安装URP17源码，确认原候选错误地要求普通Lit的MotionVectors材质开关开启。Unity对骨骼动画即使该开关关闭仍绘制object motion；关闭主要抑制静止且无骨骼动画的对象。已修正候选为要求通道存在，材质开关仍冻结并参与来源变更失效；普通Lit、Skin配置、f-1与像素门保持。第三次两侧均使用保存材质的原关闭状态，未强开通道。[官方语义](https://docs.unity.com/en-us/engine/6000.0/manual/cameras/urp/motion-vectors/motion-vectors)

候选源码和受影响CPU检查保存在[candidate-not-adopted.patch](candidate-not-adopted.patch)，相对于e296750；开发树及本机产品恢复94，补丁不自动编译或进入交付。此前History／Frame／MaterialSource检查通过，资格纠错只重跑受影响MaterialSource，没有重复全矩阵、哈希或严格误差证明。所有这些检查不替代上述画质采用条件。

临时脚本保留用于理解原结果，不作为新验证系统继续扩建。原生输出在`I:/Unity test/Comparison/SkinMotionHistory03-baseline`与`SkinMotionHistory03-candidate`，其中大体积原始GPU读回留在本机；本目录保留结果和Final。旧失败记录不覆盖，临时注入已撤回。
