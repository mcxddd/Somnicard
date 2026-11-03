// node tools/solvers/preflop.mjs [iterations=3000] [equity=.local/preflop-equity.json] [out=data/preflop.json]
// Approximate 100 BB preflop equilibrium for 2–6 players, blinds 0.5 / 1, no ante.
// This is an ABSTRACT game, not full No-Limit Hold'em:
// - first in: fold or open (2.5 BB; the small blind opens to 3 BB), no limps;
// - the first player behind who continues (call or 3-bet) ends the round for
//   everyone else, so every pot that sees a flop is heads-up;
// - re-raise ladder: 3-bet (3× in position, 4× out of position), 4-bet (2.2×),
//   then an all-in 5-bet; facing all-in only call or fold;
// - a called pot is not played out. With all-in equity e for the player in
//   position, it takes the share e^a / (e^a + (1−e)^b) of the pot and the other
//   side the rest (REALIZATION below: a for in position, b out of position, per
//   pot type). Exponents above 1 mean weak hands realise less than their equity;
//   b > a gives position its edge. An all-in pot pays plain equity. These
//   exponents are assumptions chosen to approximate published realisation
//   estimates; they are not solved.
//   Optional arguments: a and b for single-raised pots (defaults 1.15 1.45).
// Card removal is exact between the two players who reach a showdown and ignored
// against players who folded. Solved with CFR+ (regret matching+, linear averaging).
// The reported exploitability is the most one seat gains by best-responding,
// measured inside this abstract game only.
import { readFileSync, writeFileSync } from 'node:fs';
import { CLASS_COMBOS } from './poker.mjs';

const iterations = Number(process.argv[2] ?? 3000);
const source = JSON.parse(readFileSync(process.argv[3] ?? '.local/preflop-equity.json'));
const out = process.argv[4] ?? 'data/preflop.json';
const STACK = 100;
const H = 169;
const EQ = Float64Array.from(source.equity, (v) => v / 10000);
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
const PRIOR = Float64Array.from(CLASS_COMBOS, (c) => c.length / 1326);
const NAMES = { 2: ['SB', 'BB'], 3: ['BTN', 'SB', 'BB'], 4: ['CO', 'BTN', 'SB', 'BB'], 5: ['HJ', 'CO', 'BTN', 'SB', 'BB'], 6: ['UTG', 'HJ', 'CO', 'BTN', 'SB', 'BB'] };

// Postflop, the blinds act first; otherwise later seats act later. Heads-up the SB is the button.
function inPosition(n, a, b) {
  if (n === 2) return a === 0;
  const rank = (o) => (o >= n - 2 ? o - n : o);
  return rank(a) > rank(b);
}

function buildTree(n) {
  const blinds = Array.from({ length: n }, (_, o) => (o === n - 1 ? 1 : o === n - 2 ? 0.5 : 0));
  const nodes = [];
  const node = (spec) => { nodes.push(spec); return nodes.length - 1; };
  // Terminal: contributions per seat, winner by folds or a showdown pair.
  const terminal = (put, winner, pair, kind) => node({ terminal: true, put, winner, pair, kind });
  function duel(o, j, put, ladder) {
    // ladder: 0 = j to act facing the open, 1 = o facing 3-bet, 2 = j facing 4-bet, 3 = o facing all-in
    const ip = inPosition(n, o, j);
    const actor = ladder % 2 === 0 ? j : o;
    const other = actor === j ? o : j;
    const facing = Math.max(...put);
    const children = [], actions = [];
    const fold = put.slice();
    children.push(terminal(fold, other, null, 'fold'));
    actions.push({ action: 'fold', to: 0 });
    const called = put.slice();
    called[actor] = facing;
    const allIn = facing >= STACK;
    children.push(terminal(called, -1, [o, j], allIn ? 'allin' : ['srp', 'threebet', 'fourbet'][Math.min(ladder, 2)]));
    actions.push({ action: 'call', to: facing });
    if (ladder < 3) {
      let to;
      if (ladder === 0) to = facing * ((ip ? j : o) === j ? 3 : 4);
      else if (ladder === 1) to = Math.round(facing * 2.2 * 2) / 2;
      else to = STACK;
      to = Math.min(STACK, to);
      const raised = put.slice();
      raised[actor] = to;
      children.push(to >= STACK ? allInNode(o, j, raised, actor) : duel(o, j, raised, ladder + 1));
      actions.push({ action: 'raise', to });
    }
    return node({ player: actor, children, actions, label: `${NAMES[n][o]}-${NAMES[n][j]}-${ladder}` });
  }
  // After a shove the other side only calls or folds.
  function allInNode(o, j, put, shover) {
    const actor = shover === o ? j : o;
    const fold = put.slice();
    const called = put.slice();
    called[actor] = STACK;
    return node({ player: actor, children: [terminal(fold, shover, null, 'fold'), terminal(called, -1, [o, j], 'allin')],
      actions: [{ action: 'fold', to: 0 }, { action: 'call', to: STACK }], label: `${NAMES[n][o]}-${NAMES[n][j]}-jam` });
  }
  function responders(o, j, put) {
    if (j >= n) return terminal(put, o, null, 'steal');
    const facing = Math.max(...put);
    const ip = inPosition(n, j, o);
    const call = put.slice(); call[j] = facing;
    const to = facing * (ip ? 3 : 4);
    const raised = put.slice(); raised[j] = to;
    return node({ player: j, children: [responders(o, j + 1, put), terminal(call, -1, [o, j], 'srp'), duel(o, j, raised, 1)],
      actions: [{ action: 'fold', to: 0 }, { action: 'call', to: facing }, { action: 'raise', to }], label: `${NAMES[n][j]}-vs-${NAMES[n][o]}` });
  }
  function firstIn(o) {
    if (o === n - 1) { const put = blinds.slice(); return terminal(put, n - 1, null, 'walk'); }
    const open = n > 2 && o === n - 2 ? 3 : 2.5;
    const put = blinds.slice(); put[o] = open;
    return node({ player: o, children: [firstIn(o + 1), responders(o, o + 1, put)],
      actions: [{ action: 'fold', to: 0 }, { action: 'raise', to: open }], label: `${NAMES[n][o]}-open` });
  }
  const root = firstIn(0);
  return { nodes, root, n };
}

const A = Number(process.argv[5] ?? 1.15), B = Number(process.argv[6] ?? 1.45);
const REALIZATION = { srp: [A, B], threebet: [1 + (A - 1) * 0.66, 1 + (B - 1) * 0.66], fourbet: [1 + (A - 1) * 0.33, 1 + (B - 1) * 0.33], allin: [1, 1] };

// Per-seat payoff vectors at a terminal for the given reach vectors.
function terminalValues(tree, t, reach, out) {
  const n = tree.n;
  const pot = t.put.reduce((a, b) => a + b, 0);
  const mass = reach.map((r) => r.reduce((a, v, h) => a + v * PRIOR[h], 0));
  for (let p = 0; p < n; p++) {
    const v = out[p];
    let others = 1;
    for (let k = 0; k < n; k++) if (k !== p && !(t.pair && t.pair.includes(k) && t.pair.includes(p))) others *= mass[k];
    if (t.winner >= 0 || !t.pair.includes(p)) {
      const c = (t.winner === p ? pot : 0) - t.put[p];
      for (let h = 0; h < H; h++) v[h] = c * others;
      continue;
    }
    const q = t.pair[0] === p ? t.pair[1] : t.pair[0];
    const [ea, eb] = REALIZATION[t.kind];
    const ip = inPosition(n, p, q);
    for (let h = 0; h < H; h++) {
      let value = 0;
      for (let g = 0; g < H; g++) {
        const w = COND[h * H + g] * reach[q][g];
        if (w === 0) continue;
        const e = EQ[h * H + g];
        // e is p's equity; the formula is written for the in-position side.
        const eip = ip ? e : 1 - e;
        const top = Math.pow(eip, ea);
        const shareIp = top / (top + Math.pow(1 - eip, eb));
        const share = ip ? shareIp : 1 - shareIp;
        value += w * (share * pot - t.put[p]);
      }
      v[h] = value * others;
    }
  }
}

function solve(n) {
  const tree = buildTree(n);
  const regret = tree.nodes.map((s) => (s.terminal ? null : s.actions.map(() => new Float64Array(H))));
  const average = tree.nodes.map((s) => (s.terminal ? null : s.actions.map(() => new Float64Array(H))));
  const strategyAt = (id, useAverage) => {
    const s = tree.nodes[id];
    const table = useAverage ? average[id] : regret[id];
    const out = s.actions.map(() => new Float64Array(H));
    for (let h = 0; h < H; h++) {
      let total = 0;
      for (let a = 0; a < s.actions.length; a++) total += Math.max(0, table[a][h]);
      for (let a = 0; a < s.actions.length; a++) out[a][h] = total > 0 ? Math.max(0, table[a][h]) / total : 1 / s.actions.length;
    }
    return out;
  };
  // Returns per-seat counterfactual value vectors. mode: 'cfr' updates, 'avg' evaluates, 'br' best-responds for seat brSeat.
  function walk(id, reach, mode, weight, brSeat) {
    const s = tree.nodes[id];
    const values = Array.from({ length: n }, () => new Float64Array(H));
    if (s.terminal) { terminalValues(tree, s, reach, values); return values; }
    const strategy = strategyAt(id, mode !== 'cfr');
    const p = s.player;
    const childValues = [];
    for (let a = 0; a < s.actions.length; a++) {
      const next = reach.slice();
      next[p] = Float64Array.from(reach[p], (r, h) => r * strategy[a][h]);
      childValues.push(walk(s.children[a], next, mode, weight, brSeat));
    }
    for (let k = 0; k < n; k++) {
      for (let h = 0; h < H; h++) {
        let v = 0;
        if (k === p && mode === 'br' && brSeat === p) {
          v = -Infinity;
          for (let a = 0; a < s.actions.length; a++) v = Math.max(v, childValues[a][k][h]);
        } else if (k === p) {
          for (let a = 0; a < s.actions.length; a++) v += strategy[a][h] * childValues[a][k][h];
        } else {
          for (let a = 0; a < s.actions.length; a++) v += childValues[a][k][h];
        }
        values[k][h] = v;
      }
    }
    if (mode === 'cfr') {
      for (let a = 0; a < s.actions.length; a++) for (let h = 0; h < H; h++) {
        regret[id][a][h] = Math.max(0, regret[id][a][h] + childValues[a][p][h] - values[p][h]);
        average[id][a][h] += weight * reach[p][h] * strategy[a][h];
      }
    }
    return values;
  }
  const ones = () => Array.from({ length: n }, () => new Float64Array(H).fill(1));
  const started = Date.now();
  for (let t = 1; t <= iterations; t++) {
    walk(tree.root, ones(), 'cfr', t, -1);
    if (t % 500 === 0) console.log(`PREFLOP ${n}p iteration ${t}/${iterations} ${((Date.now() - started) / 1000).toFixed(0)}s`);
  }
  // Exploitability per seat (BB per hand dealt): best response minus average-strategy value.
  const base = walk(tree.root, ones(), 'avg', 0, -1);
  let worst = 0;
  const seatGain = [];
  for (let p = 0; p < n; p++) {
    const br = walk(tree.root, ones(), 'br', 0, p);
    let gain = 0;
    for (let h = 0; h < H; h++) gain += PRIOR[h] * (br[p][h] - base[p][h]);
    seatGain.push(gain);
    worst = Math.max(worst, gain);
  }
  // Per-node, per-class action values conditional on reaching the node.
  const export_ = [];
  function record(id, reach) {
    const s = tree.nodes[id];
    if (s.terminal) return;
    const strategy = strategyAt(id, true);
    const p = s.player;
    const evs = [];
    for (let a = 0; a < s.actions.length; a++) {
      const next = reach.slice();
      next[p] = Float64Array.from(reach[p], (r, h) => r * strategy[a][h]);
      const child = walk(s.children[a], Array.from({ length: n }, (_, k) => (k === p ? new Float64Array(H).fill(1) : next[k])), 'avg', 0, -1)[p];
      evs.push(child);
      record(s.children[a], next);
    }
    // Normalise by the opponents' chance of reaching this node so EVs read in BB.
    let others = 1;
    for (let k = 0; k < n; k++) if (k !== p) others *= reach[k].reduce((a, v, h) => a + v * PRIOR[h], 0);
    export_.push({ label: s.label, player: NAMES[n][p], actions: s.actions,
      frequency: strategy.map((row) => Array.from(row, (v) => '0123456789abcdefghijk'[Math.round(v * 20)]).join('')),
      ev: evs.map((row) => Array.from(row, (v) => (others > 1e-12 ? Math.round((v / others) * 100) : 0)).join(',')),
      reach: Math.round(others * 1e6) / 1e6 });
  }
  record(tree.root, ones());
  return { nodes: export_, exploitability: worst, seat_gain: seatGain, seconds: (Date.now() - started) / 1000 };
}

const tables = {};
let worstAll = 0;
for (let n = 2; n <= 6; n++) {
  const r = solve(n);
  worstAll = Math.max(worstAll, r.exploitability);
  tables[String(n)] = { exploitability: Math.round(r.exploitability * 10000) / 10000, seat_gain: r.seat_gain.map((g) => Math.round(g * 10000) / 10000), nodes: r.nodes };
  const share = (x, a) => Array.from(x.frequency[a]).reduce((s, c, h) => s + PRIOR[h] * '0123456789abcdefghijk'.indexOf(c) / 20, 0);
  const opens = r.nodes.filter((x) => x.label.endsWith('-open')).map((x) => `${x.player} ${(100 * share(x, 1)).toFixed(0)}%`).join(' ');
  const bbDefend = r.nodes.filter((x) => x.label.startsWith('BB-vs-')).map((x) => `${x.label.slice(6)}:${(100 * share(x, 1)).toFixed(0)}+${(100 * share(x, 2)).toFixed(0)}`).join(' ');
  console.log(`PREFLOP_SOLVED ${n}p nodes=${r.nodes.length} opens ${opens} | BB call+3bet ${bbDefend} | exploit ${r.exploitability.toFixed(4)} BB seats ${r.seat_gain.map((g) => g.toFixed(3)).join('/')} ${r.seconds.toFixed(0)}s`);
}
writeFileSync(out, JSON.stringify({ version: 'preflop-1', iterations, stack_bb: STACK, blinds: [0.5, 1], ante: 0, equity_samples: source.samples,
  model: 'abstract preflop tree; heads-up pots only; postflop = hand- and position-dependent equity realisation', realization: REALIZATION, positions: NAMES, exploitability_max: worstAll, tables }));
console.log(`PREFLOP_DONE max exploitability ${worstAll.toFixed(4)} BB`);
