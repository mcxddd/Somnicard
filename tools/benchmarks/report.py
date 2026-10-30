"""Build the shipped evidence text and full report from frozen evaluations.

Run from project root after opponents.gd with the documented seeds/flags.
No strategy changes or selective filtering of unfavorable results.
"""
import hashlib
import json
from pathlib import Path
from statistics import mean, stdev

root = Path(__file__).resolve().parents[2]
strength = json.loads((root / '.local/opponents-holdout.json').read_text(encoding='utf-8'))
styles = json.loads((root / '.local/opponents-styles.json').read_text(encoding='utf-8'))
assert strength['blocks'] == 1024 and strength['seed'] == 760001 and strength['games'] == 18432
assert styles['blocks'] == 128 and styles['seed'] == 97000001 and styles['games'] == 1152
out = root / 'docs/benchmarks'
out.mkdir(exist_ok=True)
strength['source_sha256'] = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in [
    'scripts/poker/local_bot.gd', 'scripts/poker/range_model.gd',
    'tools/benchmarks/legacy_bot.gd', 'tools/benchmarks/opponents.gd']}
strength['paired_comparisons'] = {}
for count in (6, 9):
    a = strength['block_bb_per_100'][f'{count}max-L2']
    b = strength['block_bb_per_100'][f'{count}max-L1']
    differences = [x-y for x, y in zip(a, b)]
    avg = mean(differences)
    half = 1.98 * stdev(differences) / len(differences)**0.5
    strength['paired_comparisons'][f'{count}max-advanced-minus-standard'] = {
        'difference_bb_per_100': avg, 'ci95_low': avg-half, 'ci95_high': avg+half}
(out / 'opponents-1.6.0.json').write_text(json.dumps(strength, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
(out / 'styles-1.6.0.json').write_text(json.dumps(styles, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def result(key):
    s = strength['summaries'][key]
    return f"{s['bb_per_100']:+.1f} [{s['ci95_low']:+.1f}, {s['ci95_high']:+.1f}]"

labels = ['入门', '标准', '进阶（实验）', '旧版标准']
intro = '''# 电脑对手设计与实测（1.6.0）

三档表示不同决策逻辑。现有数据支持入门弱于标准 / 进阶，尚未证实进阶稳定强于标准，因此标为实验档。没有真人对照数据，不能换算成真人段位、现金桌级别、Elo 或职业水平；也不能将这些盈利率外推到真实牌局。

## 三档逻辑

| 档位 | 翻牌前 | 翻牌后 | 有意保留的局限 |
| --- | --- | --- | --- |
| 入门 | 偏宽入池、位置影响很弱，较少主动加注 | 24 次均匀范围模拟，估算噪声、偏宽跟注、较粗的牌型下注 | 模拟休闲玩家常见的爱跟注与位置意识不足；不是随机乱按按钮 |
| 标准 | 根据位置、跟注价格和加注次数收紧范围，强牌主动加注 | 72 次公开行动范围加权模拟，考虑位置兑现率、听牌与多人底池，使用明确的价值 / 听牌下注规则 | 只作局部经验决策，不搜索未来街道 |
| 进阶（实验） | 更稳定地执行位置与价格阈值；短码调整，少量同花 A 再加注 | 160 次加权模拟；比较 1/3、2/3、满池尺度的单轮响应近似；分别限制价值下注、半诈唬、纯诈唬频率 | 响应模型未用真人数据校准，未搜索再加注和后续街道；复杂边池回退经验策略 |

所有档位只看自己的底牌、当前公共牌、公开行动、筹码和合法操作。已知信息相同时更换其他人的真实底牌不改变输出。抽样有效样本不足时向均匀范围收缩；样本更多不等于更强。只有私牌实际参与的听牌才用于自身半诈唬判断。

进阶的加注 EV 使用假设跟注概率、跟注者牌力与预计投入，包含不确定性折扣。跟注概率、未来权益兑现率、预计投入之间的相关性均是近似；即使在单轮也不是精确最优解。无法用它宣称完整 GTO 或可利用度保证。教学使用独立 advisor / CFR 模块，并未被替换为电脑策略。

## 行动风格与逐座位设置

偏被动 / 均衡 / 偏激进独立于难度：主要控制主动入池、加注、边缘施压和诈唬频率。激进不自动获得更高牌力，偏被动也不代表低难度。不是按风格直接提高所有跟注概率。

开桌页“对手 / 设置”，或对局中点电脑座位 → 配置这位对手。1–8 号电脑可各自设置；跟随默认的座位随全局难度更新，独立指定的座位不受影响。应用后从下一次电脑行动生效，取消与返回丢弃草稿；换人数保留暂时不用的配置。存档保留继承关系，历史保存每次配置变化的事件边界；复盘显示和训练重打使用该时刻的配置，不读取未来修改。旧记录无元数据时训练沿用当前配置。

## 冻结评测设计

- 100 BB 初始有效筹码，盲注 5/10，无前注、无抽水，每手重置筹码；不包括比赛 ICM、持续桌画像或淘汰赛。
- 三档之间的全部双人配对，以及每档对冻结 1.5.0 标准电脑。每个独立牌序交换双方座位，两次结果形成一个块。每个 HU 配对 2,048 手。
- 6 人桌各档两位、9 人桌各档三位，均为均衡风格。每个牌序轮换三个档位，使每档均覆盖每个位置；两种桌型各 3,072 手。
- 共 1,024 个独立牌序块、18,432 手，固定种子 760001。开发调参仅使用种子 11111 的 16 / 512 块，修正了过高的纯诈唬频率；未依据最终测试结果继续调整策略。
- 另用种子 97000001 做 128 块九人混合风格测试，每种难度 × 风格各一位、轮转九次，共 1,152 手。用于描述风格行为，不为风格做强弱排名。
- 区间为按独立牌序块计算的近似 Student t 95% 区间，保留同牌序内轮换的相关性。多组结果为描述性比较，未做多重检验校正。净收益单位 BB/100，正数为盈利。行为统计按玩家手数计算，包含仅交盲注的牌局；VPIP 为翻前主动跟注 / 加注，PFR 为翻前加注。
- 扑克收益方差很大，不能靠少量胜负评定实力。可参见 [AIVAT 原始论文](https://poker.cs.ualberta.ca/publications/aaai18-burch-aivat.pdf)。本项目采用配对轮换与块级区间，**未实现 AIVAT**。

## 双人完整结果

| 对比（前者收益） | BB/100 [95% 区间] |
| --- | --- |
'''
rows = [('标准 对 入门', 'HU-0-1-L1'), ('进阶 对 入门', 'HU-0-2-L2'), ('进阶 对 标准', 'HU-1-2-L2'),
        ('入门 对 旧版标准', 'HU-0-3-L0'), ('标准 对 旧版标准', 'HU-1-3-L1'), ('进阶 对 旧版标准', 'HU-2-3-L2')]
text = intro + ''.join(f'| {label} | {result(key)} |\n' for label, key in rows)
text += '\n标准、进阶对入门均有正向证据；进阶对标准的区间跨 0。新标准 / 进阶对旧版标准的区间也跨 0，不能宣称新版决策收益已稳定超过旧版。\n\n## 多人混合桌\n\n| 桌型 | 档位 | BB/100 [95% 区间] | VPIP | PFR |\n| --- | --- | --- | --- | --- |\n'
for count in (6, 9):
    for level in range(3):
        key = f'{count}max-L{level}'
        b = strength['behavior'][key]
        text += f"| {count} 人 | {labels[level]} | {result(key)} | {b['vpip_pct']:.1f}% | {b['pfr_pct']:.1f}% |\n"
text += '\n同块配对的“进阶减标准”差值：\n\n'
for key, s in strength['paired_comparisons'].items():
    text += f"- {key[0]} 人：{s['difference_bb_per_100']:+.1f}，95% 区间 [{s['ci95_low']:+.1f}, {s['ci95_high']:+.1f}] BB/100。\n"
text += '\n两档都能从入门对手的漏洞获利，不等于在真人桌有同样盈利率；不同桌型的均值排序也不一致。\n\n## 风格实测（九种配置同桌）\n\n| 档位 | 风格 | 玩家手数 | VPIP | PFR | 翻后主动比例* |\n| --- | --- | --- | --- | --- | --- |\n'
for level in range(3):
    for style in (1, 0, 2):
        b = styles['behavior'][f'9styles-L{level*3+style}']
        text += f"| {labels[level]} | {['均衡','偏被动','偏激进'][style]} | {b['hands']} | {b['vpip_pct']:.1f}% | {b['pfr_pct']:.1f}% | {b['postflop_aggression_pct']:.1f}% |\n"
text += '''
*翻后主动比例 = 下注 / 加注次数 ÷（下注 / 加注次数 + 跟注次数）；不包含过牌和弃牌，不是全动作占比。实际局面随对手动作变化，不能把整局统计视作严格的同局面因果效应。另有同一 KQo 开局、400 个共同随机种子 × 三档 × 三种风格的匹配决策测试，三档均验证偏被动 < 均衡 < 偏激进的加注频率。

## 复现与下一步

```powershell
& $GodotExe --headless --path . --script tools/benchmarks/opponents.gd -- --blocks=1024 --seed=760001 --out=res://.local/opponents-holdout.json
& $GodotExe --headless --path . --script tools/benchmarks/opponents.gd -- --styles --blocks=128 --seed=97000001 --out=res://.local/opponents-styles.json
python tools/benchmarks/report.py
```

`$GodotExe` 为本机 Godot 4.7.2 console 路径。原始块结果与代码摘要保存在 [强度结果](benchmarks/opponents-1.6.0.json) 和 [风格结果](benchmarks/styles-1.6.0.json)。固定策略、同一 Godot 版本、种子及机器架构可复现实验；运行耗时不保证一致。

自动测试覆盖 2–9 人、不等筹码、短码全押、合法下注、筹码守恒、隐藏信息隔离、私牌听牌、设置草稿、继承 / 恢复、历史配置时间边界与训练。桌面行动耗时只用于本机性能观察，不代表安卓耗时；真实触摸和长时间性能仍需设备反馈。

下一步需要在新的冻结样本、50 / 200 BB、更多固定基线与人工审查局面中继续验证标准和进阶的差异。真人水平校准需要自愿提供的对局数据或受控真人对战，再按位置、深度和人数比较行为及收益；当前没有这类数据。
'''
(root / 'docs/opponents.md').write_text(text, encoding='utf-8')
app = '离线电脑评测 · 1.6.0\n100 BB，无抽水；18,432 手。独立牌序 1,024 组，同牌换位；以下为 BB/100 [95% 区间]。\n\n'
app += '\n'.join(f'{label}：{result(key)}' for label, key in rows[:3])
app += '\n\n进阶对标准的区间跨 0，尚未证明更强。6 / 9 人混合桌两档均优于入门，但排序不一致。新标准 / 进阶对旧版标准的区间也跨 0。\n\n这些是特定电脑阵容的结果，不能换算成真人段位或真人盈利率。未测完整 GTO；50 / 200 BB 的强弱排序尚未校准。'
source = 'extends RefCounted\n## Generated by tools/benchmarks/report.py from frozen full results.\nconst TEXT = ' + json.dumps(app, ensure_ascii=False) + '\n'
(root / 'scripts/poker/opponent_evaluation.gd').write_text(source, encoding='utf-8')
print('Generated full evidence, raw block reports and in-game summary.')
