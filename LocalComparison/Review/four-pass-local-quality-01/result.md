# 本机统一示例：第4级空间滤波

候选画面收益明确，已通过预先约定的静止预算门；待普通Release92构建整合。仅将本机示例现成`filterIterations`从3设为4，保留2ray／DXR和Runtime算法。第4级空间步长8扩大当前帧滤波支持，不回写时间历史或moments，通用Feature默认仍为3。

## 画面收益与代价

[同曝光四时点对照](comparison.png)左为已保存Release88的2ray／DXR／filter3，右为当前ffb42b1同GI源码的filter4候选。主线程、独立图审和Astra均看到149／179运动中及结束时、189／209停止后10／30帧的门面、地板和绿墙云斑明显减弱；门、黑白块及墙地轮廓保持清楚，未见明显新增串色、缺损或持续旧门轮廓。

代价是同平面明暗过渡更柔、局部对比减弱。这符合用户允许适度柔化、优先减少运动颗粒的取舍；并不证明真实阴影或局部能量更正确。两侧全图出射平均Y分别变化+0.031%、+0.022%、−0.050%、−0.042%，未见靠整体压暗换平滑的信号；全图均值接近不等于颜色准确度通过。

图像为640×360普通IndirectOnly间接漫反射出射贡献，GI320×180，曝光1、Reinhard+sRGB；不是独立D或物理参考。保存的Feature确认2ray、cache8、filter4、DXR偏好；四帧实际诊断均reported-hardware、20mesh／0fallback，相机、门和灯状态与基线匹配。详见[图像元数据与均值](comparison.json)。

唯一Unity PID23168完成原0–209前史，210渲染帧、failures=0、backendMismatches=0。原720完成协议仍为failed／native exit1，不能称完整序列通过。临时场景、捕获选择与Quality已恢复，原数据在`I:/Unity test/Comparison/FourPassLocalQuality01`。没有补帧、新参考、D采集、参数扫描或哈希校验。

## 已确认预算下的静止成本

画面通过后原样复用既有observer和native分析，960×540／半分辨率GI、2ray／filter4／实际DXR、反馈关闭、UI／输入关闭。每个source frame先加ReceiverCapture、Transport与Composite，再统计分位数；不把三个分位数相加。

| 项目 | 本次有限窗口 |
| --- | ---: |
| GI三区间合计中位 | 23.920896ms |
| GI三区间合计p95 | 24.5615824ms |
| GI三区间合计p99／最大 | 24.751641／25.158688ms |
| local采样峰值 | 565.441406MiB |
| nonlocal采样峰值 | 289.691406MiB |

本次满足用户起始目标p95≤25ms、local有限采样峰值≤1GiB；p95余量约0.438ms，不能称有充足性能余量。最大值超过25ms不违反所选p95门槛，但仍如实保留。nonlocal单列且没有已选上限。原Release90／filter3的22.643ms属于独立历史窗口，不用两次差值冒充精确的单级滤波增量成本。

完整原生来源窗口为159–670、512帧，DXGI采样512次成功、0次失败；所有GI范围完整。相机回调平均40.936873Hz、间隔p95为27.028595ms，只是回调节奏，不是应用Present／显示FPS。三个GI范围不含全部准备／上传、resolve或整应用GPU；进程显存不是GI独占或绝对瞬时峰值，也不是长时／最大负载验收。详见[成本结果与来源](performance/result.json)。

测量专用Release／None构建Unity PID15252、0错误／23条warning、native0；Player PID23012正常退出0，watchdog未触发。原作者Renderer、Quality、初始化器及临时observer已恢复。原数据在`I:/Unity test/Comparison/FourPassLocalQualityCost01`；普通Release91未变。

## 四项画质问题与采用边界

- 颜色误差：没有filter4独立D参考。Release88软件119的Floor／White偏差−2.776%／−0.938%等定量继续标为filter3，不能直接当作本配置误差。
- 换色／关灯残留：本次没有这两类事件。缓存和时间规则未改，但空间输出已改变，旧响应数值仍保持原版本／配置来源。
- 运动拖影：上述四时点未见新增明显持续旧轮廓；不证明全段或任意运动无拖影。
- 收敛时间：只有停后10／30帧普通画面，不能给出达到正确颜色的统一帧数；软化不等于收敛更快。

本线只采用本机质量配置取舍，不称算法缺陷修复或G1／G3／G4整体放行。按Astra批准范围，预算通过后只做普通构建整合，不追加参考、运动Present、软件、长时或第二预算窗口。
