After its independent detail-albedo proposal, Astra read the completed Pro33 plan and compared the alternatives against the full original plan. No next-package implementation had started.

【继续】调整上一建议，优先推进 temporal-subpixel-history，detail albedo暂留待办。当前CSTemporal确实把连续prevUV量化到单个GI像素；改善它直接推进原目标2、工作流6及G3，影响可靠表面的日常重投影。已有实际采样中心helper和kernel回归设施，最小路径清楚，所需验证也比开启另一项材质链修复更集中。

必须守住的一条边界：先保持原最近邻的完整有效性，再逐个验证所有非零独立tap；任何失败都完整退回原最近邻，绝不放宽拒绝条件换取插值收益。解析线性场应检查最终temporal输出，区分真实重建改善与仅helper正确；边界输入决定是否存在错误混合。唯一批次若无明确改善或破坏回退即撤回，通过则提交收束。最大风险是把有限取样改善扩写成整场景闪烁或动态画质已验收；本方案不支持这些结论。
