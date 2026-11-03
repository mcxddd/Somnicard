// node tools/solvers/preflop_equity.mjs [samples=24000] [out=.local/preflop-equity.json]
// All-in preflop equity of every class against every class (win + tie / 2),
// averaged uniformly over non-overlapping combo pairs and random boards.
// Monte Carlo: the standard error per entry is printed and stored.
import { writeFileSync } from 'node:fs';
import { score, CLASS_COMBOS, rng } from './poker.mjs';

const samples = Number(process.argv[2] ?? 24000);
const out = process.argv[3] ?? '.local/preflop-equity.json';
const random = rng(20261104);
const equity = new Float64Array(169 * 169);
const cards = new Int32Array(7);
const used = new Uint8Array(52);
const started = Date.now();

function pairs(a, b) {
  const list = [];
  for (const x of CLASS_COMBOS[a]) for (const y of CLASS_COMBOS[b])
    if (x[0] !== y[0] && x[0] !== y[1] && x[1] !== y[0] && x[1] !== y[1]) list.push([x, y]);
  return list;
}

let worst = 0;
for (let a = 0; a < 169; a++) {
  for (let b = a; b < 169; b++) {
    const list = pairs(a, b);
    let total = 0, square = 0;
    for (let s = 0; s < samples; s++) {
      const [x, y] = list[(random() * list.length) | 0];
      used.fill(0);
      used[x[0]] = used[x[1]] = used[y[0]] = used[y[1]] = 1;
      for (let k = 2; k < 7; k++) {
        let c;
        do c = (random() * 52) | 0; while (used[c]);
        used[c] = 1;
        cards[k] = c;
      }
      cards[0] = x[0]; cards[1] = x[1];
      const sx = score(cards);
      cards[0] = y[0]; cards[1] = y[1];
      const sy = score(cards);
      const v = sx > sy ? 1 : sx === sy ? 0.5 : 0;
      total += v; square += v * v;
    }
    const mean = total / samples;
    worst = Math.max(worst, Math.sqrt(Math.max(0, square / samples - mean * mean) / samples));
    equity[a * 169 + b] = mean;
    equity[b * 169 + a] = 1 - mean;
  }
  if (a % 13 === 12) console.log(`EQUITY_PROGRESS row ${a + 1}/169 ${((Date.now() - started) / 1000).toFixed(0)}s`);
}
writeFileSync(out, JSON.stringify({ samples, seed: 20261104, standard_error_max: worst, equity: Array.from(equity, (v) => Math.round(v * 10000)) }));
console.log(`EQUITY_DONE samples=${samples} max_se=${(worst * 100).toFixed(2)}% ${((Date.now() - started) / 1000).toFixed(0)}s`);
