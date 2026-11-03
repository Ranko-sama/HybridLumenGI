# Release122：稳定回退时保留间接光历史

材质页持续超出预算、相机一直使用同一 SDF／解析回退时，本版允许静止接收面正常累积间接光历史。Release121 在这个条件下每帧都从 1 起算；修复后的实际相机历史可以连续累积。实际追踪表示变化时仍重新起算。[原生读回与适用范围](https://github.com/Ranko-sama/HybridLumenGI/blob/7c08327f6fd6758dc5cdda563ec10e42e26b50bb/LocalComparison/Review/stable-fallback-history-01/result.md)

**运行统一示例。** 完整解压 Windows 包，双击 `Start-LocalRelease.cmd`。按 M 启停门运动，按 F5 切换间接光视图，按 C 换墙色，按 L 开关解析灯。示例保留 960×540、半分辨率 GI、2 条射线、4 级滤波和 DXR 偏好。包内 `PictureComparison/index.html` 可离线查看原图、原始 EXR 和各项测量范围。

**版本来源。** 产品源码为 `7c08327f6fd6758dc5cdda563ec10e42e26b50bb`，相对 Release121 更新 Renderer Feature 和硬件准备路径。场景、配置、SDF、表面卡与 Windows 资源页沿用 Release121。普通 Windows Player 从本版可编辑工程 ZIP 的干净解压目录构建。已有工程在作者资产与构建目标不变时，可沿用有效的烘焙与资源页；更新源码时应同步完整同版产品目录并保留 `.meta`。

**画质结论沿用各自的测量来源。** 本次为已有修复的普通构建整合，没有新增画面、性能或压力测量。

- 颜色误差：Release93 静止第 119 帧的地板／白色接收块平均间接亮度相对独立近似参考低 3.075%／0.831%，只覆盖两个区域及该参考配置。
- 换色／关灯残留：Release114 绿发光板切蓝后，首蓝帧旧绿剩 7.46%，第 +30 帧剩 0.285%；Release112 的关灯 Final 含保留的发光面，不能从全图亮度分离旧间接光。
- 运动拖影：已采用的同曝光 3／4 级滤波四时点对照显示颗粒减少，所示帧未见明显加重的旧门轮廓；全过程闪烁及弱拖尾时长仍未知。
- 收敛时间：已有数据只说明所采时点的响应，尚无统一的正确颜色收敛时间。

[四项画质问题及原图来源](https://github.com/Ranko-sama/HybridLumenGI/blob/7c08327f6fd6758dc5cdda563ec10e42e26b50bb/LocalComparison/Review/dynamic-picture-comparison-01/report.md)

本版不新增整体 G3／G5 放行结论。冷高速入场的首次完整表示仍有空档；纹理页等待读回时仍可能临时回退。完整生产验收尚未完成，CI 按既有决定暂缓。
