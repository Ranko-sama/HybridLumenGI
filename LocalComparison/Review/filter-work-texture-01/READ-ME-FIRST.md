# HybridLumenGI Release108 · Windows x64

将整个 ZIP 解压到新目录，双击 `Start-LocalRelease.cmd`。默认进入彩墙场景，单击窗口后可用键盘操作。

| 查看或操作 | 按键 |
| --- | --- |
| 查看本次复用纹理后的近场账目 | F3 进入中性两室，在近场按 F2 写入日志 |
| 中性两室的远近切换 | 2 到远场，1 返回近场 |
| 走过两道错位门洞 | 在两室中按 F4 进入三室，从右侧开口前进，向左对准中央门，再前进。O 开闭滑门 |
| 返回原场景 | F4 从三室返回两室，F3 关闭房间布局 |
| 自由移动、升降与转向 | WASD、Q/E、方向键 |
| 换墙色、开关解析灯、启停门运动 | C、L、M |
| 启停形变、切换可读网格与蒙皮 | 空格、K |
| 切换软件追踪或 DXR | 4、5 |
| 离开分页范围、释放／重载分页组 | 3、B |
| 隐藏面板、记录状态、退出 | F1、F2、Esc |

日志位于解压目录上一级的 `LocalRelease108.log`。本次中性两室近场的 F2 账目中，`screenTextureEstimateBytes` 为 32,140,800 字节，单列的 `receiverIdentityBufferBytes` 为 6,222,720 字节。

离线打开 `PictureComparison/index.html`，可查看已有的颜色误差、换色与关灯残留、运动拖影、恢复过程和烘焙光照贴图对照。各节注明采集版本及参考条件。

Unity 6000.0.85f1／URP 17.0.4，Windows x64、Mono、DX12、Linear。产品源码 `1afe13e66a7a566728fa44190ce70a8534dcbe40`。默认窗口 960×540，半分辨率 GI、每像素 2 条射线、4 级滤波，优先 DXR。分项 GPU 计时和显存观察默认关闭。原生插件通知与许可位于 `Documentation`。
