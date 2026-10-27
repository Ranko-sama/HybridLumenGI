# 原生 GPU 计时候选包：第三方声明

核验日期：2026-10-27。本文件随独立的 Windows x64 `HybridLumenGIGpuTiming.dll` 候选包分发，也保留在源码交付包中。候选包不自动安装到 Unity 工程。

## Unity Native Plugin API

原生插件和 WARP 测试的编译依赖来自 Unity 官方 `Unity-Technologies/NativeRenderingPlugin`，固定提交 **`522254181faf188efa8b50c3e3bf6fce720b26e4`**。下面三个文件均在自身文件头明确标注 Unity Companion License；其共同版权通知为：

> Unity Native Plugin API copyright © 2015 Unity Technologies ApS

| 官方来源（固定提交） | 原始文件 SHA-256 |
| --- | --- |
| [IUnityInterface.h](https://github.com/Unity-Technologies/NativeRenderingPlugin/blob/522254181faf188efa8b50c3e3bf6fce720b26e4/PluginSource/source/Unity/IUnityInterface.h) | `E23E267B57C049B438307542D62C30FBCD3FA77B6DAC3B08842EAE0DF10B8239` |
| [IUnityGraphics.h](https://github.com/Unity-Technologies/NativeRenderingPlugin/blob/522254181faf188efa8b50c3e3bf6fce720b26e4/PluginSource/source/Unity/IUnityGraphics.h) | `E95A8AC359897B5746494DB84AE594D6F59F3709C2EC20BD869D592ED4BBF4F7` |
| [IUnityGraphicsD3D12.h](https://github.com/Unity-Technologies/NativeRenderingPlugin/blob/522254181faf188efa8b50c3e3bf6fce720b26e4/PluginSource/source/Unity/IUnityGraphicsD3D12.h) | `7E6322A1F280E4D7DEA9AA567E5085875F05AC373C1DC134D4DADC7985C21617` |

这些未经修改的接口头保存在包外的构建缓存或构建者指定的 Unity PluginAPI 目录；源码包和 DLL 候选包不附带这些头文件。固定来源构建的报告记录实际头文件哈希；使用其他本地头文件的构建不属于这里列出的固定版本。

仓库根目录另有 [MIT LICENSE](https://github.com/Unity-Technologies/NativeRenderingPlugin/blob/522254181faf188efa8b50c3e3bf6fce720b26e4/LICENSE)。本通知保留这一来源事实，但不使用它替代三个接口头自己的许可。插件实现、提交状态机及测试由本项目实现，未移植 Unity 示例的渲染实现；引用接口并不在本通知中被解释成对本项目全部原创源码重新许可。

## 随包提供的 Unity Companion License

头文件给出的旧许可链接重定向至 [Unity 官方 Unity Companion License](https://unity.com/legal/licenses/unity-companion-license)。核验时正文版本为 **v1.4**，页面日期为 **10.29.2024**。完整正文随附于 [Licenses/Unity-Companion-License.txt](Licenses/Unity-Companion-License.txt)。

第 5 节要求在相应 Work 的实质部分或其衍生作品中提供许可和相关版权通知；不能放入时，允许置于惯常的通知位置。本交付将本通知和完整许可一并放入候选包，确保接收方获得这些信息；这里不对最终 DLL 是否构成法律意义上的实质部分或衍生作品作认定。

使用与分发应阅读完整条款。第 1 节将授权用途与有效 Unity Engine License 下的创作或分发相联系，并包含竞争性用途限制；第 2 节不改变 Engine License；第 3 节区分 Unity 的 Work 与使用它创作的内容；第 4 节涉及商标；第 6 节为免责声明；第 7 节涉及许可版本更新。本项目面向 Unity URP 集成，本通知不证明任何接收方已经持有所需许可，也不提供整个项目的新授权。

许可正文直接从上述官方网页的 v1.4 条款提取，保留标题、版本、全部 10 节及日期。仅移除 HTML 标记、统一 UTF-8/LF 段落格式，并在商标条款的链接边界添加可读空格；未翻译或改写条款。随附文本 SHA-256：

```text
538E1932AAA1603AA64F0977A66FA05FC718B6821A2CD5A8DB47FA2A9208D47E
```

## 候选包应包含的通知文件

保留以下相对路径，避免本通知指向的许可链接失效：

```text
Documentation/NativeGpuTimingThirdPartyNotices.md
Documentation/Licenses/Unity-Companion-License.txt
```

同时保留原生构建报告、来源清单和 DLL 哈希，便于对应到实际二进制。若今后附带 Unity 接口头本身，须保留它们原有的版权及许可声明；若更换来源、修改头文件或加入其他第三方实现，应重新更新对应记录。

本通知核验范围是上述 Unity 接口依赖。当前 Release 构建使用 MSVC 静态运行库；Unity 的许可不替代 Microsoft 编译工具链及可分发代码的条款。候选包不附带 Windows SDK 头、Windows 系统 DLL 或 VC Redistributable 安装程序。关于 Microsoft 文件的分发条件，以实际使用的工具许可和 [Microsoft 官方分发说明](https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files?view=msvc-170)为准。
