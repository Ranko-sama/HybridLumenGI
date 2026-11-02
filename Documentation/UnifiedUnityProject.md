# 在 Unity 中打开并重建统一示例

将 `HybridLumenGI-Release119-UnityProject.zip` 完整解压到新目录。在 Unity Hub 中选择 **Add → Add project from disk**，选中包含 `Assets`、`Packages`、`ProjectSettings` 的目录。使用 Unity **6000.0.85f1**、Windows x64 Build Support 和可用的 Unity 许可。工程已声明 URP **17.0.4**，首次导入由 Unity 的包管理器解析依赖。

在 Project 窗口打开 `Assets/HLGINeutral106/Variant/NeutralThreeRooms.unity`，按 Play 进入彩墙场景。WASD 移动，C 换墙色，L 开关解析灯，M 启停门运动。F3 进入中性两室，随后按 F4 进入三室，O 开关中央滑门。1、2 分别切到近景与远景。

按 **F5** 或点击 **F5: show indirect light** 可以单独看间接光。再次按 F5 回到原视图。要观察颜色反弹，可对准白色地板，按 C 换墙色，再用 F5 对照最终画面。运行时代码也可在相机准备前调用 Renderer Feature 的 `SetIndirectIntensity(float)` 与 `SetDebugView(DebugView)`。强度只接受有限非负数。

工程含普通渲染及编辑器源码、活动场景和 Renderer Feature、材质与烘焙资产、可编辑分页源以及 `Assets/StreamingAssets/UnifiedNeutral106` 下的 Windows 资源页。可直接查看、修改场景。若修改分页源网格、贴图或材质，需要用分页导出工具重新生成对应的资源页。首次打开时请保留已有的 `.meta` 和分页目录，使场景引用及物理页路径保持匹配。

## 构建普通 Windows Player

关闭正在编辑这个工程的 Unity 窗口，在解压后的工程根目录打开 PowerShell。将第一行改为本机的 Unity Editor 路径，并为每次构建选择一个全新的输出目录。

```powershell
$unityEditor = 'C:/Program Files/Unity/Hub/Editor/6000.0.85f1/Editor/Unity.exe'
$projectPath = (Get-Location).Path
$buildPath = Join-Path (Split-Path -Parent $projectPath) 'HLGI-Windows'
& $unityEditor -batchmode -quit -projectPath $projectPath -buildTarget StandaloneWindows64 `
  -executeMethod HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build `
  -hlgiScene 'Assets/HLGINeutral106/Variant/NeutralThreeRooms.unity' `
  -hlgiOutput $buildPath -logFile "$buildPath.log"
```

成功时，输出目录内的 `build-result.json` 记录 `Succeeded` 和所选场景。运行 `HybridLumenGIPlayer.exe -force-d3d12 -screen-fullscreen 0 -screen-width 960 -screen-height 540` 即可以发布版使用的窗口尺寸启动。示例采用 Linear、半分辨率 GI、2 条射线和 4 级滤波，优先使用 DXR。
