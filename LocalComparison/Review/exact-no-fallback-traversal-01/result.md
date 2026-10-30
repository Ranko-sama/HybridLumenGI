# 精确后端完整接管时跳过空的回退遍历

唯一成本窗口通过预先固定的保留规则，待普通Release93整合。当前统一场景的精确后端已接管所有published owner，但每次查询仍遍历scene BVH并逐个跳过这些mesh。现在复用已有FallbackCount：有效快照无回退owner时直接保留精确查询结果，有回退或无精确后端时仍完整执行原循环。

修改仅涉及两种Bind中随meshFlags写入一个私有uniform、exact头文件声明及精确查询后的宏内提前返回。重建／复用路径中，FallbackCount为零对应所有published owner的mesh flag非零；warming和无效slot本来跳过。独立源码审阅确认时点、两种Bind、失败后无exact shader回退以及unknown／miss／valid语义保持。没有改变射线、filter4、材质资格、场景集合、时间累计或预算控制。

## 固定配置下的有限收益

沿用Release92的2ray／filter4／DXR、960×540／GI480×270、静止、只测量且反馈关闭，原样复用既有observer和native分析。基线来自已保存`FourPassLocalQualityCost01`；本次只新增一个完整512源帧窗口，没有新locator、反汇编、图像／参考采集或第二窗口。

| GI三区间逐源合计 | 既有Release92配置基线 | 本候选 |
| --- | ---: | ---: |
| 中位 | 23.920896ms | 18.392832ms |
| p95 | 24.5615824ms | 19.2983568ms |
| p99 | 24.751641ms | 19.498255ms |
| 最大 | 25.158688ms | 19.970336ms |
| 四个连续128帧块中位数范围 | 0.368864ms | 1.081760ms |

中位下降5.528064ms，大于两侧块中位范围最大值1.081760ms，p95也低于基线；符合执行前[scope](scope.md)规定的保留规则，见[采用判定](retention.json)。候选四块为18.581040／18.395600／18.760560／17.678800ms，末块保留，没有剔除。比较是两个有限静止窗口的描述性依据，不是总体置信保证、所有场景固定节省或整应用GPU加速比例。

当前p95距25ms起始上限约5.702ms；进程local有限采样峰值567.253906MiB，满足1GiB门槛，nonlocal为289.691406MiB且未设上限。local不是GI独占、整机显存或绝对瞬时峰值。相机回调平均53.735203Hz、间隔p95为22.096240ms，不是Present／显示FPS。三个GI范围仍不覆盖全部准备、上传、resolve或整应用GPU。详见[完整窗口结果](result.json)。

实际窗口source159–670，512连续原生来源及全部三个范围完整，反馈关闭、实际DXR；现有设置与基线一致。窗口显存采样512次成功、0失败。没有将只满足预算当作优化收益，也没有借此增加生产验收条件。

## 执行与范围

候选源码aeb6ba2已同步本机工程。唯一测量Release／None构建Unity PID23824、0错误／23条warning、native0；唯一Player PID22928正常退出0、watchdog未触发。记录见[构建来源](build-attempt.json)、[构建退出](build-exit.json)、[Player退出](native-exit.json)。原Renderer、Quality、初始化器与临时observer已恢复；原数据在`I:/Unity test/Comparison/ExactNoFallbackTraversal01`。

Astra批准以直接源码等价审阅加一次既有成本窗口收束，不为判断镜像建立夹具。回退非空分支和非exact分支保持旧代码；有限性能收益来自当前无回退的统一场景，不外推混合场景或软件后端的实际加速。

独立结果复核无阻断：配置、连续来源、退出及预定采用规则一致，现有起末端点均为published20／hardwareMeshes20／fallback0。Astra同意保留并整合93，不追加任何运行；这不是逐像素相同或混合场景加速证明。

画质设置及估计规则保持Release92。**颜色误差**没有新的filter4独立参考；**换色／关灯残留**没有新的事件观察；**运动拖影**沿用92四时点未见新增持续旧轮廓的有限图审；**收敛时间**仍无统一正确颜色时长。本轮没有新图像等价或完整G0–G5结论。
