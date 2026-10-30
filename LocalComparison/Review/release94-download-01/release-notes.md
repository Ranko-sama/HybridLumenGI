下载下面的 **HybridLumenGI-Release94-Windows-x64.zip**，完整解压后运行 `Start-LocalRelease.cmd`；无需Unity编辑器。不要选择GitHub自动生成的Source code压缩包来运行演示。

这是现有普通Release94的可下载实验版，960×540／半分辨率GI／2ray／filter4，优先DXR；操作与限制见包内 `READ-ME-FIRST.md`。只增加下载包装、操作说明和既有第三方通知，没有重建Player，也不包含已撤回的骨骼运动短历史候选。

Release94补齐普通骨骼停稳后的历史累计，真正骨变化仍拒绝旧历史。当前仍有整景颜色、多跳残留、完整运动／精确收敛及长时负载待完成；G0–G5未整体验收，CI暂缓。起始25ms／1GiB预算的已有有限结果保持Release93来源，不改标为94动态验收。

本机环境：Unity6000.0.85f1、URP17.0.4、Windows x64／Mono／DX12／Linear、RTX2080Ti；其他设备未完成验收。详细四项画质边界和来源见[项目首页](https://github.com/Ranko-sama/HybridLumenGI#当前画质与性能)。

二进制产品来源 `65c36ef`，普通构建及整合记录 `e296750`。原生插件第三方通知和许可正文已随包保留。
