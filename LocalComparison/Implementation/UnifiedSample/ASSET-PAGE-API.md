# 可调用 AssetPageBuilder 草稿

```csharp
var result = HybridLumenGIAssetPageBuilder.Export(
    sourceProxies,
    "Assets/MyGeneratedSample/Pages",                 // 必须尚不存在
    "Assets/StreamingAssets/MyGeneratedSample/Pages" // 必须尚不存在
);
HybridLumenGIAssetPageManifest manifest = result.Manifest;
GameObject inactiveRig = result.Rig;
```

签名为 `Export(IEnumerable<HybridLumenGIProxy>, string assetDirectory, string bundleOutputDirectory)`，返回只读 `ExportResult.Manifest/Rig`。源代理集合在调用时复制、去重；空/null/已销毁代理拒绝。保留原有完整HLOD父组、静态MeshRenderer及材质槽检查。参数必须为正斜杠的project-relative路径；bundle目录必须位于`Assets/StreamingAssets/`下，两个输出目录不能相同或互相包含。目录、文件、已有Unity资产、叶/祖先孤立meta、路径跳转、空段、非法/歧义文件名及reparse点在首次写入前拒绝。沿用原构建代码的项目相对IO，若进程工作目录不是该Unity项目则提前拒绝。

API沿用当前activeBuildTarget及原有LZ4/Strict/Deterministic构建选项；CRC、直接依赖、Geometry/SDF/Charts/Material/Texture引用重映射、build后重取对象、计账、空目的绑定、变换祖先和HLOD父映射保持原实现。manifest.RelativeRoot从显式bundle目录推导。短目录名也可作rig显示名。

菜单路径不变，仍遍历Selection并使用GUID新目录，成功后选中返回的inactive rig；现有StreamingAuditEditor的ExecuteMenuItem和Selection.activeGameObject接线仍成立。公开API本身不修改Selection，也不删除/停用/解绑源对象，不保存场景。源对象强引用是否移除、何时启用rig及如何协调视觉/HLOD由新样例调用方决定。

失败保留原有行为：异常前生成的内容可能留在这两个明确的新目录，不自动删除或覆盖重试；调用方可在自己的生成事务中处理。接口不宣称全局AssetDatabase.SaveAssets的既有行为已改为事务化，不新增清理框架。

交付包含候选文件、`asset-page-builder-api.patch`及`asset-page-builder-api-source.json`。四段原构建/绑定算法逐字一致；路径拒绝先于资产创建，patch仅只读检查，实际Editor源未改变。未运行Unity、AssetBundle构建或新行为矩阵；整合后由根统一编译/构建验证。
