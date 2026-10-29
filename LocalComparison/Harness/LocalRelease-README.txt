HybridLumenGI — 本机普通 Release 基线

双击 Start-LocalRelease.cmd 启动。窗口保持运行，按Esc或点击关闭按钮退出。
点击窗口获得焦点后：WASD平移，Q/E升降，方向键转向，R回到启动视点。松键或切换到其他窗口时停止移动。
空格启动／停止红绿格纹薄板的连续形变，默认停止。停止时保持形状，GI快照随后追上；可见动画与GI更新允许有延迟。R只复位相机。
入口使用既有 Functional 初始视图，正常启用 GI；不执行自动门运动、材质修改或阶段截图。
启动器固定窗口640×360，沿用本轮验证尺寸；这不是生产分辨率目标。当前配置偏好DXR，保留产品自身的回退规则。
日志写入本目录 local-release.log。请保留 EXE、整个 Data 目录及随附文件，不要只复制EXE。

构建平台：Windows x64 / Mono / Direct3D12 / Linear，BuildOptions.None。
默认启动不计帧、不查询诊断、不自动退出。验证参数 -localReleaseVerify120 配合新的绝对 -localReleaseOutput 路径才会进行120目标相机帧有限检查。

本机入口为LocalRelease69，产品源码50b63c3，示例接线另记于LocalComparison/Review/continuous-deformation-usage-01。
沿用Release67固定六面RGBAFloat演示环境，非物理天空参考。有限验证使用同一启停方法，未重复验证操作系统键盘输入。
这是本机可运行基线；不代表完整画质、性能、总显存、长时稳定性或所有平台已经验收。
