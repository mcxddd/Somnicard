// node tools/solvers/pushfold.mjs [iterations=3000] [equity=.local/preflop-equity.json] [out=data/pushfold.json]
// Chip-EV push/fold equilibrium for 2–6 players, blinds 0.5 / 1 BB, no ante,
// equal effective stacks of 2–15 BB.
// Game: the first player to enter may only shove or fold; later players may
// only call or fold. Heads-up this is the complete push/fold game. With 3–6
// players one simplification applies: once somebody calls, everyone behind
// folds (no three-way all-ins). Card removal is exact between the shover and
// each caller and ignored against players who folded.
// Solved by fictitious play: every iteration best-responds to the running
// average; the reported exploitability is the most any single seat could gain
// by deviating from the final average strategy, in BB per hand where it acts.
import { readFileSync, writeFileSync } from 'node:fs';
import { CLASS_COMBOS } from './poker.mjs';

const iterations = Number(process.argv[2] ?? 3000);
const source = JSON.parse(readFileSync(process.argv[3] ?? '.local/preflop-equity.json'));
const out = process.argv[4] ?? 'data/pushfold.json';
const EQ = Float64Array.from(source.equity, (v) => v / 10000);
const H = 169;

// p(g | h): the distribution of one opponent's class given my class, exact card removal.
const COND = new Float64Array(H * H);
for (let h = 0; h < H; h++) {
  let total = 0;
  for (let g = 0; g < H; g++) {
    let n = 0;
    for (const x of CLASS_COMBOS[h]) for (const y of CLASS_COMBOS[g])
      if (x[0] !== y[0] && x[0] !== y[1] && x[1] !== y[0] && x[1] !== y[1]) n++;
    COND[h * H + g] = n;
    total += n;
  }
  for (let g = 0; g < H; g++) COND[h * H + g] /= total;
}
const PRIOR = CLASS_COMBOS.map((c) => c.length / 1326);

// Acting order for N players: UTG … BTN, SB, BB (heads-up: SB, BB).
const blinds = (n) => Array.from({ length: n }, (_, o) => (o === n - 1 ? 1 : o === n - 2 ? 0.5 : 0));
const NAMES = { 2: ['SB', 'BB'], 3: ['BTN', 'SB', 'BB'], 4: ['CO', 'BTN', 'SB', 'BB'], 5: ['HJ', 'CO', 'BTN', 'SB', 'BB'], 6: ['UTG', 'HJ', 'CO', 'BTN', 'SB', 'BB'] };

function solve(n, stack) {
  const b = blinds(n);
  const push = Array.from({ length: n - 1 }, () => new Float64Array(H).fill(0.5));
  const call = Array.from({ length: n - 1 }, (_, i) => Array.from({ length: n }, (_, j) => (j > i ? new Float64Array(H).fill(0.5) : null)));

  // Margin of calling over folding for caller j against shover i's range.
  function callMargin(i, j, pushRange) {
    const dead = 1.5 - b[i] - b[j];
    const margin = new Float64Array(H);
    for (let h = 0; h < H; h++) {
      let weight = 0, value = 0;
      for (let g = 0; g < H; g++) {
        const w = COND[h * H + g] * pushRange[g];
        weight += w;
        value += w * ((1 - EQ[g * H + h]) * (2 * stack + dead) - stack);
      }
      margin[h] = weight > 0 ? value / weight + b[j] : -Infinity;
    }
    return margin;
  }
  // Margin of shoving over folding for first-in player i against the callers behind.
  function pushMargin(i, calls) {
    const margin = new Float64Array(H);
    for (let h = 0; h < H; h++) {
      let reach = 1, ev = 0;
      for (let j = i + 1; j < n; j++) {
        const dead = 1.5 - b[i] - b[j];
        let p = 0, value = 0;
        for (let g = 0; g < H; g++) {
          const w = COND[h * H + g] * calls[j][g];
          p += w;
          value += w * (EQ[h * H + g] * (2 * stack + dead) - stack);
        }
        ev += reach * value;
        reach *= 1 - p;
      }
      ev += reach * (1.5 - b[i]);
      margin[h] = ev + b[i];
    }
    return margin;
  }
  const best = (margin) => Float64Array.from(margin, (m) => (m > 0 ? 1 : 0));
  for (let t = 1; t <= iterations; t++) {
    const step = 1 / (t + 1);
    const nextPush = push.map((_, i) => best(pushMargin(i, call[i])));
    const nextCall = call.map((row, i) => row.map((c, j) => (c ? best(callMargin(i, j, push[i])) : null)));
    for (let i = 0; i < n - 1; i++) {
      for (let h = 0; h < H; h++) push[i][h] += (nextPush[i][h] - push[i][h]) * step;
      for (let j = i + 1; j < n; j++) for (let h = 0; h < H; h++) call[i][j][h] += (nextCall[i][j][h] - call[i][j][h]) * step;
    }
  }
  // Exploitability: best-response gain over the average strategy for every decision.
  let worst = 0;
  const gain = (strategy, margin) => {
    let g = 0;
    for (let h = 0; h < H; h++) g += PRIOR[h] * (Math.max(0, margin[h]) - strategy[h] * margin[h]);
    return g;
  };
  const result = { push: [], call: [], pushMargin: [], callMargin: [] };
  for (let i = 0; i < n - 1; i++) {
    const pm = pushMargin(i, call[i]);
    worst = Math.max(worst, gain(push[i], pm));
    result.push.push(push[i]);
    result.pushMargin.push(pm);
    const rowC = [], rowM = [];
    for (let j = i + 1; j < n; j++) {
      const cm = callMargin(i, j, push[i]);
      // Weight by the chance the caller faces this shove at all.
      let reach = 0;
      for (let h = 0; h < H; h++) reach += PRIOR[h] * push[i][h];
      worst = Math.max(worst, gain(call[i][j], cm) * reach);
      rowC.push(call[i][j]);
      rowM.push(cm);
    }
    result.call.push(rowC);
    result.callMargin.push(rowM);
  }
  result.exploitability = worst;
  return result;
}

// Compact text: one char per class for frequency (0–9 tenths, 'a' = always),
// margins as signed hundredths of a BB joined by commas.
const freq = (s) => Array.from(s, (v) => '0123456789a'[Math.round(v * 10)]).join('');
const margins = (m) => Array.from(m, (v) => (Number.isFinite(v) ? Math.round(v * 100) : 0)).join(',');
const tables = {};
let worstAll = 0;
const started = Date.now();
for (let n = 2; n <= 6; n++) {
  for (let stack = 2; stack <= 15; stack++) {
    const r = solve(n, stack);
    worstAll = Math.max(worstAll, r.exploitability);
    tables[`${n}/${stack}`] = {
      exploitability: Math.round(r.exploitability * 10000) / 10000,
      push: r.push.map(freq), push_margin: r.pushMargin.map(margins),
      call: r.call.map((row) => row.map(freq)), call_margin: r.callMargin.map((row) => row.map(margins)),
    };
    const share = r.push[0].reduce((a, v, h) => a + v * PRIOR[h], 0);
    console.log(`PUSHFOLD ${n}p ${stack}BB first-in ${NAMES[n][0]} shoves ${(100 * share).toFixed(1)}% exploit ${r.exploitability.toFixed(4)} BB ${((Date.now() - started) / 1000).toFixed(0)}s`);
  }
}
writeFileSync(out, JSON.stringify({
  version: 'pushfold-1', iterations, equity_samples: source.samples, equity_standard_error_max: source.standard_error_max,
  blinds: [0.5, 1], ante: 0, stacks: [2, 15], positions: NAMES, exploitability_max: worstAll,
  model: 'chip EV; first-in shove or fold; one caller at most (3-6 players); equal stacks', tables,
}));
console.log(`PUSHFOLD_DONE max exploitability ${worstAll.toFixed(4)} BB`);
