HybridLumenGI — 本机 Release54

产品来源：a9292cb8c3c1bd86b64fdcb7888565bd7c957ec4。Windows x64 / Mono / DX12 / Linear，BuildOptions.None。
双击 Start-LocalRelease.cmd：既有 Functional colorView、普通 backbuffer、窗口常驻，关闭窗口退出；默认不计帧、不采图、不自动运行场景事件。
640×360 是本次固定视图配置，不是生产目标。请保留 EXE、整个 Data 目录与随附文件。

本次实际运行的是显式 -localReleaseFinalImage120 分支：固定 HDR camera target，从首帧保持同一目标，第120个相机帧保存一次 RGBA32F/EXR/PNG 并退出。
该图是最终 HDR 目标的读回，PNG使用既有固定预览映射；不是普通 backbuffer 像素证明。默认常驻模式未另跑一次。
来源、构建和图像证据：仓库 LocalComparison/Review/current-representative-final-image-01。
不代表完整画质、物理能量、动态稳定性、所有材质变体、性能、总显存或生产验收。
