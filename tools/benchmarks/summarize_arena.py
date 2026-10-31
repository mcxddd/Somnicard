"""Produce audited local evidence and the compact in-game result from raw blocks.

Usage: python tools/benchmarks/summarize_arena.py <app version>
Reads .local/arena-<version>.json written by tools/benchmarks/arena.gd.
"""
import json
import statistics
import sys
from pathlib import Path

# Two-sided 95% Student t critical value for 127 degrees of freedom (128 blocks).
T_975_127 = 1.9788

root = Path(__file__).resolve().parents[2]
version = sys.argv[1] if len(sys.argv) > 1 else '1.11.0'
raw = json.loads((root / f'.local/arena-{version}.json').read_text(encoding='utf-8'))
reports = raw['reports']
assert len(reports) == 9 and all(r['completed'] for r in reports.values())
total = sum(sum(int(b['hands']) for blocks in r['block_returns'].values() for b in blocks.values()) for r in reports.values())
assert total == 21312
paired = {}
for group in reports['level1-style0']['groups']:
    def values(level):
        blocks = reports[f'level{level}-style0']['block_returns'][group]
        return [100 * blocks[str(i)]['net'] / blocks[str(i)]['hands'] for i in range(128)]
    for low, high in [(0, 1), (1, 2)]:
        differences = [h - l for h, l in zip(values(high), values(low))]
        mean = statistics.fmean(differences)
        half = T_975_127 * statistics.stdev(differences) / len(differences) ** 0.5
        paired[f'{group}:{high}-{low}'] = dict(mean=mean, low=mean - half, high=mean + half, blocks=128)
baseline = next(iter(reports.values())).get('baseline_version', '')
raw['paired_differences'] = paired
raw['method'] = f'Common seeded deals, all seat rotations, reset stacks/no rake; subject against {baseline} standard-balanced. Confidence intervals cluster all rotations of a deal. Paired comparisons descriptive, no multiple-comparison adjustment. No human rating.'
raw['hands'] = total
raw['app_version'] = version
out = root / f'docs/benchmarks/arena-{version}.json'
out.write_text(json.dumps(raw, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
compact = dict(hands=total, version=version, reports={k: dict(params=r['params'], groups=r['groups']) for k, r in reports.items()}, paired=paired)
(root / 'data/arena-evidence.json').write_text(json.dumps(compact, ensure_ascii=False, indent='\t')+'\n', encoding='utf-8')
print(f'SUMMARY_OK version={version} hands={total} reports={len(reports)} paired_groups={len(paired)}')
for k, d in paired.items():
    if ':2-1' in k:
        print(k, f"{d['mean']:+.1f} [{d['low']:+.1f}, {d['high']:+.1f}]")
