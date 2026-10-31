"""Produce audited local evidence and the compact in-game result from raw blocks."""
import json
from pathlib import Path
from scipy.stats import t
import numpy as np

root = Path(__file__).resolve().parents[2]
raw = json.loads((root / '.local/arena-1.11.0.json').read_text(encoding='utf-8'))
reports = raw['reports']
assert len(reports) == 9 and all(r['completed'] for r in reports.values())
total = sum(sum(int(b['hands']) for blocks in r['block_returns'].values() for b in blocks.values()) for r in reports.values())
assert total == 21312
paired = {}
for group in reports['level1-style0']['groups']:
    def values(level):
        blocks = reports[f'level{level}-style0']['block_returns'][group]
        return np.array([100 * blocks[str(i)]['net'] / blocks[str(i)]['hands'] for i in range(128)])
    for low, high in [(0, 1), (1, 2)]:
        differences = values(high) - values(low)
        half = t.ppf(.975, 127) * differences.std(ddof=1) / np.sqrt(128)
        paired[f'{group}:{high}-{low}'] = dict(mean=float(differences.mean()), low=float(differences.mean()-half), high=float(differences.mean()+half), blocks=128)
raw['paired_differences'] = paired
raw['method'] = 'Common seeded deals, all seat rotations, reset stacks/no rake; subject against frozen opponent-2 standard-balanced. Confidence intervals cluster all rotations of a deal. Paired comparisons descriptive, no multiple-comparison adjustment. No human rating.'
raw['hands'] = total
raw['app_version'] = '1.11.0'
out = root / 'docs/benchmarks/arena-1.11.0.json'
out.write_text(json.dumps(raw, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
compact = dict(hands=total, version='1.11.0', reports={k: dict(params=r['params'], groups=r['groups']) for k,r in reports.items()}, paired=paired)
(root / 'data/arena-evidence-1.11.0.json').write_text(json.dumps(compact, ensure_ascii=False, indent='\t')+'\n', encoding='utf-8')
print(f'SUMMARY_OK hands={total} reports={len(reports)} paired_groups={len(paired)}')
for k, d in paired.items():
    if ':2-1' in k:
        print(k, f"{d['mean']:+.1f} [{d['low']:+.1f}, {d['high']:+.1f}]")
