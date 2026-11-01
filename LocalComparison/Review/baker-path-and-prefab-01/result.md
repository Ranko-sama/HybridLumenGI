# G2 · 烘焙资产的保存与实例绑定

Unity 6000.0.85f1 的 SDF 烘焙菜单现在会拒绝磁盘上已存在的目标文件，包括尚未进入 AssetDatabase 的 `.asset`。此前只检查已导入的主资产。无图形 Editor 核对使用一个已有有效 SDF 绑定的 Proxy，再选择刚复制到 Assets、尚未导入的有效 Mesh 资产。菜单提示改用新路径；目标文件的内容和 Proxy 原绑定均保留。[修复后的入口](../../../Editor/HybridLumenGIMeshSdfBaker.cs) · [占用路径实测](occupied-path.json)

另核对了普通 Prefab 实例的保存行为。在两个带有既有 Proxy 的实例上，分别通过 SDF 与 surface chart 烘焙器生成并绑定资产。保存场景、关闭并重开后，两个实例仍引用各自烘焙的资产，源 Prefab 上的两个字段仍为空。此结果来自修改路径检查前的产品源码 `51d9c2d`。[实例重开实测](prefab-reopen.json)

两次均使用编辑器中实际的烘焙与绑定代码，批处理只代选文件对话框的临时路径。实例输入是普通可读 Cube 网格。结果限于作者工具的保存和绑定，不涉及 GPU 图像、离屏纹理命中或嵌套 Prefab 的编辑行为。
