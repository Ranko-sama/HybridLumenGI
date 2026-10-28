# 当前移动遮挡物阶段复评

任务 c2c_a702 / iteration38，HEAD8a5f17b；Runtime未改。实际Pro37选定本方向，计划知情的独立Astra批准以实际motion/jitter/采样位置约束归属判定。完整原计划与G0–G5仍开放。

## 已完成的当前行为覆盖

一次构建，一次可见DX12 / RTX2080Ti Player，原Functional场景0–197共198逻辑帧，640×360。保留原门120–179移动及灯光/GI配置；仅停用测试probe.Update中的相机摆动、形变和MPB事件，保留初始形变快照与读回、安全退出。不是旧混合事件场景A/B。

运行ID：20261028-180327-5b7d7f90f09f451e962fae7eb315c2fa，数据在 LocalComparison/Review/moving-occluder-stage-review-01/native-window/run/ 同名目录。正常自动exit0，watchdog=false；198连续帧、29组PNG/HDR/EXR、0采集错误；176–196原raw tap21份及阶段189份payload全部完成、pending0。原run.json的incomplete-probe表示未运行720帧全序列，保持原标签。启动80.61秒不是GPU性能。

复用原DenoiseSceneTap及旧MaterialEventReadback的CopyIdentity原函数体，只接入身份/来源与现有阶段复制；没有材质trace/cache框架、新射线或产品shader修改。C#实际Unity编译通过；构建112份产品源、8临时来源及284产物匹配，部署已恢复。原始完整数据和运行前冻结分析器保留。

## 有限判定

scene-analysis.json第一且唯一分析：finite-coverage-no-counterexample。按实际当前/前一identity、上传object行、CPU静态来源、真实motion/jitter/矩阵及实际GI采样中心计算旧采样位置。只选择此前为门、当前为来源可靠静态背景且有效几何的像素；不按颜色/历史结果选点。CPU浮点投影/分支边界的0.001全分辨率像素保护只排除模糊映射，不放宽产品门槛。

176/177/178/179分别65/63/2/62个已知raw显露样本，共192个；全部history与current四分量逐位一致、moments历史长度1。未发现该有限覆盖内错误复用门primitive历史的反例。3个未知raw样本单独报告，不作为已知黑色或已知测量通过；本结论不覆盖所有未知测量分支。

已实际查看119静态、179门到位及196停稳PNG。179门面可见的小尺度变化到196更平滑，背景没有可据这组静态图定位的持续门轮廓。没有参考真值，也不是连续运动主观评分；不能称绝对无残影、恢复时间达标或整体动态质量通过。raw/history/filtered与最终HDR均保留、有限值检查通过；未出现值得进一步按层拆解的确定反例，不以最终RGB减raw制造“残影”指标。

最终已记录owner/pending/unknown/failed及相关保留计账归零，native扫描无命中；引擎UTP汇总原样保留，不声明总VRAM或所有生命周期通过。当前分辨率/FPS/GI时间/显存生产阈值仍待用户回答，不重复询问。

## 明确取舍

按原退出条件结束此动态检查：有限当前覆盖无反例，默认零产品改动，不追加第二次构建/运行，不补点、补帧、改曝光或历史权重。它补上了当前代表动态中的一条集成合同；没有新增算法，也不重开时域/detail、暗区、MC或计时调查。请求独立Astra及实际Pro38按完整计划选择唯一下一实质开发缺口，避免将后续工作变成重复观察器验收。
