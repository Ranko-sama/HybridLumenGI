"""Build the small user-facing picture report from measured values; no extra rendering."""
import json
from pathlib import Path
from html import escape
P=Path(__file__).resolve().parent
load=lambda n:json.loads((P/n).read_text())

def main():
    data=load('metrics.json');off=load('reference-comparison-0299.json')
    on=load('reference-comparison-0119.json') if (P/'reference-comparison-0119.json').exists() else None
    comparisons=[]
    for label,reference,target in [('灯亮静止',on,119),('关灯后59帧',off,299)]:
        if reference is None:continue
        row=next(r for r in reference['rows'] if r['frame']==target)
        for roi in ['Floor','White receiver']:
            r=row['roi'][roi];comparisons.append([label,roi,str(r['comparedPixels']),f"{r['candidateMeanY']:.6f}",f"{r['referenceMeanY']:.6f}",f"{r['relativeMeanBiasY']:+.1%}",f"{r['meanPixelConservativeLumaSE']:.6f}",f"{r['meanChromaL1']:.4f}"])
    headers=['状态','源几何ROI','已知点数','候选 D-Y','独立参考 D-Y','均值偏差估计','参考像素SE均值上界*','均值色向 L1']
    mdtable='| '+' | '.join(headers)+' |\n| '+' | '.join(['---']*len(headers))+' |\n'+'\n'.join('| '+' | '.join(r)+' |' for r in comparisons)
    htable='<table><thead><tr>'+''.join('<th>'+escape(x)+'</th>' for x in headers)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+escape(x)+'</td>' for x in r)+'</tr>' for r in comparisons)+'</tbody></table>'
    pending='' if on else '灯亮静止 frame119 的独立参考正在计算；这一项暂不报告完整颜色准确度。'
    summary='当前有两项可见问题：灯亮时漫反射间接光偏暗，换色和关灯后旧照明消退偏慢。相机新显露处的旧历史拒绝已在限定场景中有效；完整场景颜色准确度和多跳收敛仍未关闭。'
    color='对比的是漫反射入射量 D=E/π，不是 Final 图。参考由源几何/材质/灯光独立 CPU 路径追踪产生（256 spp、8次弹射），不读取候选颜色。主要看非金属且非零漫反射的 Floor / White receiver；全图汇总不用于把金属/黑材质合法早退的 D=0 归为颜色错误。'
    if on:color+=' 灯亮静止到frame119时，Floor / White 的平均亮度分别比参考低28.9% / 33.4%；关灯后59帧则分别高95.9% / 147.1%。这些是同源、同相机的偏差估计，表中的采样误差与下述模型局限必须同时看。Floor有13330个源域点，其中2点未知；White有86点，全部已知，不能把这个较小ROI当作全场景。'
    uncertainty='*SE 列是参考逐像素 RGB 标准误按亮度权重求和后的 ROI 均值，保守描述采样噪声，不是 ROI 均值置信区间或总误差界。参考仍近似硬阴影、忽略镜面路径且截断8次弹射；近发光面有高方差。可见偏差不能忽略，但百分比不能宣称为精确产品误差。色向 L1 比较归一化 ROI 平均 RGB，范围0到2，与亮度误差分开。'
    response='单反弹有限色墙：27个预定接收点都获得已知当前测量。4:2:1→1:2:4 换色后，历史平均色向距离仍为本次完整换色幅度的54.9%，31个后续帧后约1.30%。最坏点要16帧后低于10%、23帧后低于5%、31帧后低于2%；32帧观察窗内没有全体低于1%。这是实际色向残留，不是绝对辐射强度误差。'
    blackout='同一零源专项关闭唯一灯后，当前27点全部当帧已知黑，历史最高RGB仍为0.019989；2个后续帧降到0.009987，25帧后才低于0.001，31帧后为0.000573。60Hz仅作示意：25帧≈0.42秒、31帧≈0.52秒；这不是本次机器实测帧率。完整720场景关灯仍保留发光材质，不能要求黑。与同源参考相比，Floor/White在59帧后仍明显偏亮，且默认bounceFeedback=1，屏幕历史和当前多跳缓存估计必须分开处理。'
    motion='真实相机移动+TAA专项：57个由源几何选出的新显露点，第一帧 history RGB 与 current RGB 差全部为0、history age=1；561个持续可见控制没有被全局清零。该结论覆盖这些平面显露点，不证明所有运动、遮挡和空间滤波都无拖影。720场景门停止后，新显露ROI共2250点、2249点有配对已知值：停止帧179对帧209的D平均绝对变化为晚帧均值的8.8%，下一帧180为7.1%；画面仍有运动后的斑点/变化，但209是候选晚帧，不是独立无拖影真值。'
    convergence='720序列有720个渲染收据，但只存32张HDR。静止场景相对候选晚帧119的平均绝对变化，从frame0的28.7%降为frame30/60/90的约7.0–7.6%；这说明早期画面变化下降，不能等同物理颜色已收敛。关灯只采239/240/270/299，恢复只采300/330/359：只能报告这些观测点或时间区间，无法给缺失中间帧伪造精确收敛时刻。'
    if on:convergence+=' 恢复灯光当帧，Floor / White 比独立参考低60.7% / 67.5%；30帧后为33.9% / 37.1%，59帧后仍为31.7% / 34.4%。因此可以说它在30–59帧的采样区间接近此前偏暗状态，不能说它已收敛到正确颜色；本次观测窗内没有证据关闭这个误差。'
    fix='已提交给集成的最小修复：实际全局灯光版本变化时，若当前测量已知，清屏幕旧历史；unknown仍保留/限龄，静态帧及普通移动reactive保持。实际CSTemporal的WARP对照把已知黑的0.019989残留变为0、age1。此处展示的09图仍是修复前数据，不能称为Release74实机改善。该修复不自动解决局部MPB换色和多跳缓存里的当前估计残留；后续开发应优先处理这两个具体来源。'
    display='所有候选/参考辐射图共用曝光1和Reinhard+sRGB；没有各自自动拉亮。门停D对照统一乘4以看清结构。PNG仅垂直翻转方便观看，所有数值仍用原始矩阵/行对齐。灰棋盘=源域不比较（含边界/天空），洋红=未知，均不当作黑色；误差图红=候选偏亮、蓝=偏暗，固定量程0.05。'
    reference_images=('![灯亮候选／独立参考／差异／采样误差](color-reference-0119.png)\n\n' if on else '')+'![关灯候选／独立参考／差异／采样误差](color-reference-0299.png)'
    report=f'''# 动态画面对照与当前开发结论

{summary}

## 1. 颜色误差

{color}

{pending}

{mdtable}

{uncertainty}

{reference_images}

## 2. 换色与关灯残留

{response}

{blackout}

![实际换色与关灯曲线](finite-response-curves.png)

![同曝光27点历史色块](finite-history-swatches.png)

## 3. 运动拖影

{motion}

![门停后实际D对照](door-stop-gi-comparison.png)

## 4. 收敛时间与下一项修复

{convergence}

{fix}

![720序列稀疏ROI曲线](v209-response-curves.png)

![720序列正向画面对照](sequence-contact-sheet-upright.png)

## 数据与显示约定

{display}

详细测量：[metrics.json](metrics.json)。独立参考对照：[关灯](reference-comparison-0299.json){'、[灯亮](reference-comparison-0119.json)' if on else ''}。脚本：analyze.py / compare_reference.py。未启动Unity或Player；旧数据不被改写。
'''
    (P/'report.md').write_text(report,encoding='utf-8')
    def paragraph(text):return '<p>'+escape(text)+'</p>'
    def figure(file,caption):return '<figure><a href="'+file+'"><img src="'+file+'" alt="'+escape(caption)+'"></a><figcaption>'+escape(caption)+'</figcaption></figure>'
    html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>HybridLumenGI 动态画面对照</title><style>body{font:16px/1.75 system-ui,"Microsoft YaHei",sans-serif;max-width:1380px;margin:36px auto;padding:0 24px;color:#ddd;background:#171b22}h1,h2{line-height:1.3;color:#fff}h1{font-size:30px}h2{margin-top:38px}p{max-width:1100px}a{color:#9ec5ff}table{border-collapse:collapse;font-size:14px;width:100%}th,td{padding:9px;border:1px solid #46505e;text-align:left}th{background:#28313e}figure{margin:20px 0}img{width:100%;height:auto;border:1px solid #46505e}figcaption{font-size:13px;color:#aab6c8}.lead{padding:16px 20px;border-left:5px solid #f2bc63;background:#262a32}.small{font-size:13px;color:#aab6c8}</style><body><h1>动态画面对照与当前开发结论</h1>'''
    html+='<div class="lead">'+paragraph(summary)+'</div><p><a href="report.md">完整简报</a> · <a href="metrics.json">测量数据</a></p>'
    html+='<h2>颜色误差：候选与独立近似参考</h2>'+paragraph(color)+paragraph(pending)+htable+paragraph(uncertainty)
    if on:html+=figure('color-reference-0119.png','灯亮frame119：候选D／独立参考D／亮度差异／参考采样误差。')
    html+=figure('color-reference-0299.png','关灯后59帧：发光材质仍亮；不是应全黑的场景。')
    html+='<h2>换色和关灯残留</h2>'+paragraph(response)+paragraph(blackout)+figure('finite-response-curves.png','有限色墙、27个预定点；逐帧实际测量。')+figure('finite-history-swatches.png','实际历史色块，同一曝光与色调映射。每行同一27点；frame32换色，64关灯。')
    html+='<h2>运动拖影</h2>'+paragraph(motion)+figure('door-stop-gi-comparison.png','同一门停止姿态：D统一乘4；青色是源几何决定的新显露区域边缘。')
    html+='<h2>收敛与具体修复</h2>'+paragraph(convergence)+paragraph(fix)+figure('v209-response-curves.png','只连接实际存储样本；线段不代表测量了中间帧。')+figure('sequence-contact-sheet-upright.png','720序列事件前后，同曝光cameraAfterHLGI：HLGI合成后、透明物体前的相机信号。')
    html+='<h2>显示和适用范围</h2>'+paragraph(display)+'<p class="small">颜色强度与动态时间不是同一个指标。参考是近似漫反射D，截图是观察证据；没有把缺参考、unknown或源边界提升为质量通过。</p></body></html>'
    (P/'index.html').write_text(html,encoding='utf-8');print('report ready; static-color reference included:',on is not None)
if __name__=='__main__':main()
