# 同一目标引用、full 尺寸变化而 GI 尺寸不变的历史

## 必要性与范围

原 Validation 的 camera cut/resize 合同承诺尺寸变化应重置屏幕历史。切镜已有双 Base 与112完整路线，不重跑；既有记录没有找到真实运行时尺寸切换。此前源码与离线条件不替代这次实际使用。本项只改变该原G3子项是否已有真实依据的判断，不以未验收字样当作bug，不扩大到镜像、门调参或新测试矩阵。

Astra Max允许一次简化观察：当前Release122同源7c08327、Unity6000.0.85f1／URP17.0.4／RTX2080Ti／D3D12／Linear，直接使用原V209保存资产、相机、20个owner、5灯及静止0..104序列。单个Base相机，2ray／filter4／半GI／DXR／IndirectOnly。原门120才开始运动，本前缀不改门源码；曝光、相机姿态、灯、材质和所有Settings在事件前后不变。

## 唯一事件与数据

初始full1918×1078、实际GI应为959×539。logical95渲染返回后同一引擎帧，对Sequence的同一output RenderTexture对象Release、改宽高1919×1079并Create，同时改Sequence的width／height以使后续metadata正确；Camera、RT引用和renderRequest.destination仍为原对象。不给产品MarkDirty或Invalidate，不换目标、不跳帧／等待下一引擎帧。尺寸前后、实际GI大小及这些引用若不成立，按不足结束，不改输入重试。

只请求95／96／97三张现有Capture票据，最终平面清单为GI尺寸的filteredD／geometry／moments和full尺寸的material及它们原有有效性。每张所选读回来源须匹配实际Camera／Feature／引擎／workFrame；记录0..104所有源，实际DXR、引擎／GI连续。Capture最大pending3、最大512MiB仅为有限观察持有额度，不是产品GPU预算，不增加plane或新probe。临时抑制Sequence普通HDR导出，并复用134已有选择平面的观察接线；原Reserve、所属、格式、回读、失败／完成逻辑及产品传输／时域计算不改。95改尺寸前自身普通HDR pending须已为空；原Capture的独立plane持有按其正常流程处理，不等待95票据排空而破坏连续源关系。

共105帧后停止Sequence，保留原720协议failed-prefix；封存三个请求后等实际异步读回和原Sequence输出清理终止，再退出Play／Editor，恢复观察补丁及工程设置。300秒仅错误／保留checkpoint，不在存储所有者仍活跃时强杀、重启或复用输出。

## 预先采用规则

95须已有非空成熟时域前史，否则不足。96全部moments年龄必须有限且在0..1；合法0保留未知，不能把未知当错误或以黑色填补。97全部年龄须在0..2，并报告是否出现新累计2的点域及对应有效性分布。filteredD／Ng有效不代表当帧fresh raw；现有API没有raw直读，此项不添加探针，不据它声称全部已知点都是可信新测量。若没有足以观察新历史／恢复的数据，保持不足，不自动指认为产品bug。

上述原moments上界用于直接检查没有继承95的成熟年龄；只采用实际观察到的新历史与累计，不能推广为所有像素、任意复用资格、raw新鲜、无串色、物理颜色正确或完整G3。末端unknown和全域分布如实保留，不通过事后挑出仍成功的点判整个域通过。

本轮不判完整1919边缘覆盖、不同viewport、返回原尺寸、其他后端／分辨率、普通Player、性能、资源压力或数学参考。无论通过、超标或不足均收束；发现可归因的问题才另提具体修复。没有第二次运行、补采、阈值更改、哈希校验、公开122重建或新验证框架。

## 执行前减少无关输出

最初草案请求全部Capture support，但现有Reserve按每像素staging+33字节计持有，1919级完整单票就会超出512MiB。尚未启动Unity时已发现这一不适配；按Astra审查只保留上述四个必要平面，三票估算约480MB，仍须由原额度实际准入，超额不提高上限或补跑。未读取的普通HDR、depth、captureDepth、emissionValidity、normals等不列为通过。本节为首次执行前确定的最终范围，不是运行失败后的放宽。
