# 普通场景的批处理构建

`HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build` 使用工程现有场景和设置构建普通 Release Player，入口不依赖本机测试 Harness，也不注入观察器，可直接供本地脚本或 CI 调用。工程内已有的自动启动脚本仍会随 Unity 正常编译和执行；调用方需使用自己的普通运行工程与场景。

Release114 的普通 Windows 包直接取自可编辑 Unity 工程 ZIP 的干净解压目录。在本机首次导入后，场景没有缺失脚本，实际 PC 配置为 2 射线、4 级滤波和优先 DXR。公开入口成功构建 `NeutralThreeRooms.unity`，普通 Release／None，0 个错误、6 个警告。[打开工程与构建命令](UnifiedUnityProject.md)

先在工程中完成 URP 和 GI Feature 配置并保存场景。当前入口限定 Windows x64、Mono、显式 Direct3D12 和 Linear；不自动修改工程设置。Unity 需要已有可用许可。

```powershell
& $unityEditor -batchmode -quit -projectPath $projectPath `
  -buildTarget StandaloneWindows64 `
  -executeMethod HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build `
  -hlgiScene 'Assets/MyScenes/UnifiedSample.unity' `
  -hlgiOutput 'D:/Builds/HybridLumenGI-NewBuild' `
  -logFile 'D:/Builds/HybridLumenGI-NewBuild.log'
```

`-hlgiOutput` 必须是不存在的新目录，不能放在 Assets、Packages、Library 或 ProjectSettings 下。多个场景重复传入 `-hlgiScene`，顺序即构建顺序；这也可包含运行时要加载的 Additive 场景。首次场景必须是普通运行场景，避免把自动验证场景当成用户入口。

成功输出 `HybridLumenGIPlayer.exe` 及其数据目录，并保存简短 `build-result.json`。配置错误或构建失败会抛出异常，供批处理返回失败；失败中的部分输出保留。日志同时打印 `HLGI_PLAYER_BUILD_RESULT`，预检失败且尚未创建输出目录时可从日志读取原因。

该入口已实际构建[Release75](<I:/Unity test/Comparison/Builds/LocalRelease75/Start-LocalRelease.cmd>)：复用保存的统一场景，Release/None，0错误、23条warning，见[BuildReport摘要](<I:/Unity test/Comparison/Builds/LocalRelease75/build-result.json>)。普通窗口呈现、一次L关灯和Esc退出完成，native exit 0。局部测试工程的自动观察器临时沿用旧版统一场景guard，构建后恢复；PC质量设置也恢复。没有新增场景生成、哈希或来源归档流程。

这是本地普通构建入口的实际使用，不代表CI已运行或生产平台放行。原Release74仍保留自己的来源；本轮没有重新验收公开生成器接线，也没有新增整景图像、性能或收敛结论。
