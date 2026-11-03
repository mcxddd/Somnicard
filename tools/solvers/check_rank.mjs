// node tools/solvers/check_rank.mjs — compares score() with fast_rank.gd vectors.
import { readFileSync } from 'node:fs';
import { score, classIndex, className, CLASS_COMBOS } from './poker.mjs';

const rows = JSON.parse(readFileSync(new URL('../../.local/rank-vectors.json', import.meta.url)));
let bad = 0;
for (const [cards, expected] of rows) if (score(cards) !== expected) bad++;
const sizes = CLASS_COMBOS.map((c) => c.length);
const ok = bad === 0 && sizes.reduce((a, b) => a + b) === 1326 && className(0) === 'AA' && className(1) === 'AKs' && className(13) === 'AKo' && className(168) === '22'
  && classIndex(12, 24) === 13 && classIndex(12, 25) === 0 && classIndex(12, 11) === 1;
console.log(`RANK_CHECK ${rows.length} hands, ${bad} mismatches, classes ${ok ? 'ok' : 'WRONG'}`);
process.exit(ok ? 0 : 1);
