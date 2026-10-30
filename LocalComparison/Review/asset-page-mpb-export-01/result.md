# 资产页导出不再静默丢失MPB覆盖

后续已实现[受支持URP Lit静态覆盖持久化](../asset-page-mpb-persistence-01/result.md)。以下拒绝行为和检查结果保留为该中间版本的实际记录，不代表当前所有MPB输入仍被拒绝。

2026-10-30。直接公开`HybridLumenGIAssetPageBuilder.Export`过去接受带Renderer或材质槽MPB的输入，但只克隆`sharedMaterials`，新rig没有保存覆盖。蓝色等运行时覆盖可能在导出后恢复成共享材质外观。

现在在创建任何输出资产前明确拒绝带MPB的源，并说明应先在材质资产中制作持久外观，或由应用在页绑定后重新施加运行时覆盖。无MPB输入沿用原导出路径；源对象和运行时MPB支持不变。

这关闭的是原目标3／工作流8公开导出的**静默丢失未序列化状态**错误处理缺口。MPB导出持久化仍未实现，不因此关闭材质保真或完整G4/G5，不把统一aggregate示例的限制扩大为产品运行时限制。没有把覆盖直接烘焙进Material，以免改变既有颜色空间或栅格状态语义。

Astra审查认可该有限范围及唯一必要Editor检查。Unity6000.0.85f1中实际调用公开导出入口，分别使用Renderer级`_BaseColor`覆盖和仅材质槽覆盖：[结果](result.json)两者均在生成目录／metadata／rig前拒绝，原材质、MPB、mesh及proxy绑定保持。PID8820/native0，临时Editor辅助文件已移除；修复后的导出器保留在本机工程。

没有构建bundle或Player，没有新图像、性能、哈希核验或材质矩阵。当前[Release85](<I:/Unity test/Comparison/Builds/LocalRelease85/Start-LocalRelease.cmd>)及其GI算法不受Editor修复影响，四项画质结论不变。备份：`C:/Users/Administrator/AppData/Local/Temp/hlgi-mpb-export-27c580477aff461b80c865b2232b94ed`。
