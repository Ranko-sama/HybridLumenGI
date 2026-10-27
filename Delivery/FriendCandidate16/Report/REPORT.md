# HybridLumenGI runtime-candidate-16

本机有限运行关卡完成，交付朋友测试候选；不是生产认证或 Lumen 等价。

- Unity 6000.0.85f1 / URP 17.0.4 / Windows DX12 / RTX 2080 Ti / Linear / 640×360。
- 功能与流式 Player 各720帧、32HDR、零采集错误。默认 Player 717帧精确软件，3帧启动纹理回读等待，稳定纹理仅首帧上传；最高历史32帧。
- 真实发光、UV/normal/alpha/多材质、MPB与可读网格形变进入实际场景；GPU图集保留HDR Le=(5,3,1.5)。软件与DXR同场景差异已保留，不能当路径追踪真值认证。
- HLOD返回近场的22帧覆盖空洞已修：新细节ready前旧aggregate仍发布；最终Player f119–479无publication空洞。第二相机退出后才可解绑，移到220米后到f487全部页释放，resident/bundle计账归零。
- 原生Lit替换模式定向检查：有效地面/红墙与零环境off的RGB误差约6.1e-10/3.1e-7；未知区域保留原生照明。不是全部lightmap、SSAO、fog、decals、Forward+组合验收。

本轮实际修复：发光keyword导入丢失、HDR重复线性化、RGB24格式误拒绝导致精确路径/历史失效、Player灯光API、bundle构建后副本引用失效、HLOD组随细节卸载丢失。此前精确编译超时与黑室缓存连接漏光修复继续保留。

旧版、off与SDF原始结果复用。旧场景的_EMISSION被导入器禁用，旧关灯段不能证明面积发光采样；旧报告保留为历史。新材质场景与旧场景不同，不能直接算版本优劣。

已知限制：动态低采样噪点、薄壁真值与完整材质/Skinned组合仍待验证；退出仍有GraphicsBuffer/原生资源释放警告。没有可信GI GPU p95/p99、峰值显存、长时无增长或跨平台生产结论。冷启动：Editor精确约249秒、DXR约310秒、最终软件Player约168秒，均不是GPU帧时间。

交付包包含源码、Windows测试Player、独立Unity工程、README与证据。朋友先用工程副本导入；不要再把integration-15当作本次修复版。当前停止追加运行，等待实际集成反馈。
