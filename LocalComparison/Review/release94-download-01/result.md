# Release94可下载演示包

关闭G5使用交付中的具体缺口：统一可运行版本此前只能通过开发机I:路径启动，现在可从用户已授权的私有仓库[Release94演示发布页](https://github.com/Ranko-sama/HybridLumenGI/releases/tag/release94-demo)下载。仓库可见性保持private，发布标记prerelease，未声明生产稳定或完整G0–G5通过。

[直接下载Windows x64包](https://github.com/Ranko-sama/HybridLumenGI/releases/download/release94-demo/HybridLumenGI-Release94-Windows-x64.zip)，39,389,027字节。完整解压运行相对路径`Start-LocalRelease.cmd`，无需Unity编辑器。升级使用新文件夹；保留完整exe、数据、Mono、D3D12、原生插件和StreamingAssets，不能只替换exe。首页与包内[操作说明](READ-ME-FIRST.md)已明确源码下载和可执行演示的区别。

直接复用现成普通Release94，产品`65c36ef`、构建整合`e296750`；没有重建、修改运行代码、扩大支持范围或加入新观察器。只排除明确DoNotShip的Burst调试目录，完整StreamingAssets保留；附既有原生插件通知及相对路径许可正文。独立只读检查确认普通入口所需目录、保存场景的资源页根、附带初始化器的关闭条件，无需另建依赖裁剪系统。打包后只检查ZIP目录中的运行必需项，没有全字节重读或哈希。

GitHub连接器对该私有仓库返回404，改用已能推送本仓库的Git Credential Manager在内存取得认证；凭据未输出或写入文件。GitHub REST先确认授权private仓库，建立演示草稿、上传现有ZIP，最后发布prerelease。发布后官方API确认标签`release94-demo`、资产state=uploaded、大小及下载链接，见[published-release.json](published-release.json)；没有重新下载或运行同一二进制。

操作和质量限制随包保留：颜色、换色／关灯残留、拖影、收敛时间保持原证据版本；25ms／1GiB有限窗口仍属于93，不改标为94的全部动态性能。此前[普通Skin持续窗口](../release94-skin-sustained-use-01/result.md)因截图工具错目标而未开始；用户截图仅确认94普通三维场景和实际DXR，正常退出0，不新增持续形变验收。

Astra事前认可该交付缺口与范围。完整生产验收、未完成质量目标和用户暂缓的CI均保持原状态。
