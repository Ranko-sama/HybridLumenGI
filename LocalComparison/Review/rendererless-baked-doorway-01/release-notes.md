**没有 Renderer 的 MeshFilter 也能使用显式烘焙的距离场。** 对同一扇带洞门框，旧版把穿洞射线挡在 3.5 单位处。Release120 让它命中 8.75 单位外的后墙；旁边打门柱的射线仍命中实体，距离 3.49966，独立物理查询为 3.5。[门框条件、两条射线与适用范围](https://github.com/Ranko-sama/HybridLumenGI/blob/main/LocalComparison/Review/rendererless-baked-doorway-01/result.md)

GI 灯表也修复了一项准入问题。不能照到任何接收面的灯会让出名额，使后面的有效灯可以产生反弹。只关闭投影者的阴影层时，灯仍可照明。

**运行统一示例。** 完整解压 Windows 包，双击 `Start-LocalRelease.cmd`。按 **M** 启停灰门平移，按 **F5** 切换间接光视图。`PictureComparison/index.html` 可离线查看颜色、残留、运动与收敛的实测范围。统一示例沿用 2 条射线和 4 级滤波。旧版同曝光图中，门面和地板颗粒减弱，所示帧未见明显加重的旧门轮廓。[三级／四级滤波原图](https://github.com/Ranko-sama/HybridLumenGI/blob/bbafa950f3f20a4cd41b28128b130483f02205a3/LocalComparison/Review/four-pass-local-quality-01/comparison.png) · [普通画面的门往返](https://github.com/Ranko-sama/HybridLumenGI/blob/bbafa950f3f20a4cd41b28128b130483f02205a3/LocalComparison/Review/full-dxr-sequence-112/comparison.png)
