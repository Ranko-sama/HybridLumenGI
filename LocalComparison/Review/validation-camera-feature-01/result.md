# 验证场景按实际相机选择GI Feature

公开操作`Tools > Hybrid Lumen GI > Create Validation Scene Assets`原先用全项目`Resources.FindObjectsOfTypeAll`结果是否唯一来预填Feature。无关已加载资产可导致错误绑定；实际相机的Feature正确且唯一时，也可能因其他资产存在而漏填。

生成器现在复用`HybridLumenGIUnifiedSampleBuilder.CameraFeature`。解析相机实际URP Renderer Data及默认／缺失索引回退，只接纳其中唯一active、persistent GI Feature。无可用配置时捕获原解析器的配置异常，保留空绑定并提示；几何烘焙、保存仍继续。没有修改Runtime、GI算法或新建解析系统。

独立源码审阅未见阻断。一次受影响Editor编译使用本机Unity6000.0.85f1的Roslyn及当前工程引用，通过且退出0；[日志](Editor.log)仅含既有AssetBundle选项过时warning，[响应文件](Editor.rsp)保留输入列表。没有测试夹具、哈希、Unity运行、场景重新生成或Player构建。两个编辑器文件已同步本机工程，可运行Release86不变；不增加画质或完整G2/G5通过项。

这次有界读取同时确认已有薄壁区、封闭反射房间和历史内部多层检查，未据“尚未完整验收”另造场景或重复它们。Astra同意修复仅限本处绑定，修后结束该线。
