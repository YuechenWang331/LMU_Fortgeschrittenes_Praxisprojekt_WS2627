"""Build a self-contained Chinese results reader from the completed R outputs."""
from pathlib import Path
import csv, html, base64, math
root=Path(__file__).resolve().parents[2]
out=root/'results/Kreistyp_Alter_Zeit'
def read(name):
    with (out/name).open() as f:return list(csv.DictReader(f))
def num(s):
    try:return float(s)
    except:return float('nan')
def fmt(s,n=1):
    v=num(s)
    return f'{v:.{n}f}' if math.isfinite(v) else '不可稳定估计'
def pval(s):
    v=num(s)
    return '<0.001' if v<.001 else fmt(s,3)
def table(headers, rows):
    return '<table><thead><tr>'+''.join('<th>'+html.escape(h)+'</th>' for h in headers)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+html.escape(str(c))+'</td>' for c in r)+'</tr>' for r in rows)+'</tbody></table>'
def image(name):
    data=base64.b64encode((out/name).read_bytes()).decode()
    return f'<img src="data:image/png;base64,{data}" alt="{name}">'
cs=read('pairwise_contrasts.csv')
def select(**kw):return [r for r in cs if all(r[k]==str(v) for k,v in kw.items())]
rows=[]
for a,b in [(1,2),(1,3),(1,4),(2,3),(2,4),(3,4)]:
    absr=select(period='All',outcome='standard',type_a=a,type_b=b,scale='absolute')[0]
    rel=select(period='All',outcome='standard',type_a=a,type_b=b,scale='relative')[0]
    rows.append([f'{a} 对 {b}',fmt(absr['estimate']),f"{fmt(absr['lower'])} 至 {fmt(absr['upper'])}",fmt(rel['estimate'],3),pval(absr['p_holm']),pval(rel['p_holm'])])
content='''<h1>COVID-19｜城乡 × 年龄 × 时间</h1><p class="sub">第一轮分析 · 2020–2023 · 地区视角 · 2026-11-23</p>
<div class="highlight"><b>总体差异不大，仍可以有研究意义。</b>这次要区分：差多少、是否有统计证据、差异集中在哪些年龄和时期。以下是实际数据结果，推断仍属探索性。</div>
<h2>1 🧭 这次完成了什么</h2>'''
content+=table(['部分','已完成'],[
['数据核查','400地区 × 209周 × 7年龄；列出分母缺失和分类变更'],
['A 总体差异','粗率与年龄标准化率；6组两两比较；绝对与相对尺度'],
['B 年龄','人口构成、分年龄差异、直接年龄交互检验'],
['C 时间','全部周趋势、W1–W5和其余时期、直接时期交互检验'],
['D 年龄＋时间','直接检验年龄交互是否随时期变化'],
['核查','地区整组bootstrap 1999次；多重比较校正；独立计算验证']])
content+='''<p>主分析使用四年分母完整的<b>383个地区</b>，每个地区权重相同，固定使用2023年城乡分类。17个分母不完整地区另列清单，并在可用数据敏感性检查中使用。</p>
<h2>2 📊 总体：统一年龄构成后，差异仍存在</h2>
<p>下面比较的是<b>平均每周标准化报告发病率</b>。1＝独立大城市；2＝城市型县；3＝有聚集特征的乡村县；4＝稀疏乡村县。差值为前者减后者；比值为前者除以后者。</p>'''
content+=table(['比较','绝对差值','逐项95%区间','比值','差值校正p','比值校正p'],rows)
content+='''<div class="highlight">大城市对稀疏乡村：粗率差为 <b>−12.7</b>，标准化后为 <b>−22.0</b> 例/10万人/周，比值约 <b>0.906</b>。在这个比较中，统一年龄构成后差距扩大，而非消失。</div>
<p>这不是“年龄造成了多少差异”的因果分解。参考年龄比例来自2021年400地区的RKI推算人口，不是独立官方年龄人口。</p>'''+image('04_overall_absolute.png')
content+='''<h2>3 👥 年龄构成与年龄交互回答不同问题</h2>'''
content+=table(['问题','含义'],[['年龄构成','各类地区里，儿童、成年人、老年人分别占多少？'],['年龄标准化','如果大家用同样年龄比例，整体差距怎样改变？'],['年龄交互','儿童的城乡差距，是否与老年人的城乡差距不同？']])
content+='''<p>以“大城市 − 稀疏乡村”为例：6–17岁差值约 <b>−27.7</b>，70–79岁约 <b>−3.8</b>。直接比较这两个差值，得到 <b>−23.9</b>（95%区间 −32.5 至 −15.2），绝对尺度年龄交互的Holm校正p&lt;0.001。</p>
<p><b>同一例子的相对交互则没有通过该比较族的校正</b>（比值之比约0.941；校正p约0.102）。所以“年龄是否改变城乡差异”必须说明采用哪种尺度，不能一概而论。</p>'''+image('03_age_composition.png')+image('05_age_relative.png')
content+='''<h2>4 🕒 时间：差异并非四年始终一样</h2>
<p>仍以“大城市 − 稀疏乡村”的标准化率为例：W4平均周差约 <b>−58.0</b>，W5约 <b>−142.7</b>，W5之后整个长时期平均约 <b>−3.6</b>。这些是预定义时期均值，不能替代每周曲线。</p>
<p><b>不能据此直接说“W5显著大于W4”。</b>两时期差值的直接比较在本次大量时期比较的Holm校正后没有足够证据（校正p＝1）。这里的1是多重校正结果，不表示两时期完全相同。</p>
<p>W1–W5沿用并核对RKI表1。P0为W1之前；G1/G2是波次间隔；PostW5是2022年第22周至2023年末的观察段，<b>不是一个新波次</b>。后续应结合周曲线和外部划分进一步研究这段长时期。</p>'''+image('06_age_period_absolute.png')+image('07_weekly_pairwise_differences.png')
content+='''<h2>5 🔍 哪些判断较稳，哪些仍需谨慎</h2>'''
content+=table(['检查','本轮发现／限制'],[
['资料完整性','排除17地区可能限制代表性；缺失没有填零。'],
['纳入每周可用地区','固定分类下，各类型标准化率的全时期均值变化不足1例/10万人/周；个别周变化最高约44.1，不能忽略局部差异。'],
['分类变更','仅改用年度分类时，全时期均值变化不足0.1；个别周约3.2。'],
['另一套年龄权重','已计算地区年龄比例等权的标准化结果；在结果表中标为standard_equal。'],
['不确定性','同地区的时间和年龄关联得到保留；跨地区空间关联未建模，区间可能偏窄。'],
['统计证据','图中区间为逐项95%区间，判断用表中Holm校正p；未显著不等于证明相同。'],
['零病例','早期P0的部分相对比较不稳定，区间和检验留空并标记，不用伪病例凑比值。'],
['解释范围','是报告发病率关联；没有控制通勤、收入、检测等因素，不能做因果结论。']])
content+='''<h2>6 🗂 在项目里怎么看</h2>
<p>脚本：<code>Scripts/Kreistyp_Alter_Zeit/run_analysis.R</code><br>核查：<code>Scripts/Kreistyp_Alter_Zeit/validate_results.R</code><br>全部图表与CSV：<code>results/Kreistyp_Alter_Zeit/</code><br>完整方法：<code>reports/Kreistyp_Alter_Zeit_Methoden.md</code></p>
<p>新分支：<b>analysis/kreistyp-age-time</b>。已有脚本、未保存的编辑和旧结果保留。本次已直接在RStudio运行，结果在独立环境 <code>covid_age_time</code> 中。</p>
<h2>7 下一步怎么推进</h2>
<p>先一起读“总体差异 → 年龄交互 → 时间变化”三组结果，确定论文的主要比较；如果要更强的解释，再加入地区社会因素及空间相关模型。PostW5内的细分需要有外部依据。本次不是只挑显著结果，也没有把Poisson回归方案当成已经完成的模型。</p>
<p class="sub">波次来源：<a href="https://edoc.rki.de/bitstream/handle/176904/10260/EB-38-2022-Phaseneinteilung.pdf?sequence=1">RKI Epidemiologisches Bulletin 38/2022，表1</a>。数值来自本地分析结果；运行记录和输入校验值随结果保存。</p>'''
style='''body{font-family:"Gujarati MT","Songti SC",serif;color:#25333b;max-width:1100px;margin:50px auto;padding:0 28px;font-size:18px;line-height:1.65}h1,h2{color:#155867}h1{font-size:36px}h2{margin-top:48px}table{border-collapse:collapse;width:100%;font-size:16px;margin:20px 0}th{background:#dceef0;color:#155867;text-align:left}td,th{padding:12px 14px;border:1px solid #d3dddd}tr:nth-child(even){background:#f5f8f8}.highlight{background:#fff1a8;padding:20px 24px;border-radius:8px;margin:24px 0}.sub{color:#65747b;font-size:15px}img{width:100%;height:auto;margin:20px 0}code{font-size:15px;overflow-wrap:anywhere} @media print{body{margin:0;font-size:12pt}h2{break-after:avoid}table,img{break-inside:avoid}}'''
page='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>COVID-19 分析结果</title><style>'+style+'</style><body>'+content+'</body></html>'
(out/'研究结果导读.html').write_text(page)
print(out/'研究结果导读.html')
