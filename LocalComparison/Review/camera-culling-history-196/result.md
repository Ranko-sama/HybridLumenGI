# 相机可见层切换后的屏幕历史

普通 Base 相机运行中切换 `cullingMask` 时，当前接收面集合可以改变，画面尺寸、viewport 和相机姿态仍相同。默认的屏幕时域门比较历史位置、法线和漫反射率。不同层上满足这些条件的接收面可能继承对方的旧累计。

修复将实际相机掩码并入现有成功帧的历史上下文，并把同一个值用于接收面 RendererList。任一掩码位变化都会拒绝前一屏幕历史。相同掩码的成功帧可继续累计，世界缓存按原事件和版本规则更新。

定向回归通过。兼容性控制使用原公开无掩码构造，在画面坐标相同时仍允许复用。实际准入类使用含掩码的上下文后，切换到第 31 层拒绝旧输出。未录制帧无法提交，随后同层成功帧能发布新输出，下一帧可复用。切回原层也重新开始。[定向场景](../../../Tests/StandaloneHistoryLifecycle/CullingMask.cs.txt)

可在源码仓库根目录运行该定向场景。

```powershell
& './Tests/Invoke-CSharpHarness.ps1' -Name 'history-culling-mask' -Sources @{
    'HybridLumenGIHistoryLifecycle.cs' = Get-Content 'Runtime/HybridLumenGIHistoryLifecycle.cs' -Raw
    'Program.cs' = Get-Content 'Tests/StandaloneHistoryLifecycle/CullingMask.cs.txt' -Raw
}
```

首次尝试原生命周期总宿主时，旧的 `StateSpy`、`Work` 缺少当前 Feature 已有的准备状态与回调签名，编译退出。上述定向入口直接执行实际生命周期类，Feature 集成由普通 Win64 构建确认。结论限于 G3 的可见层切换拒旧，残影幅度和其他接收面变化继续按原画面条件验收。
