// Offline solver helpers (Node.js, development only; nothing here ships in the APK).
// Cards use the game's encoding: id = suit * 13 + (rank - 2), rank 2..14.
// score() mirrors scripts/poker/fast_rank.gd exactly (same base-15 packing),
// and tools/solvers/check_rank.gd cross-checks the two on random hands.

export const RANKS = '23456789TJQKA';

function straightHigh(mask) {
  if (mask & (1 << 14)) mask |= 1 << 1;
  for (let high = 14; high >= 5; high--) {
    const run = 31 << (high - 4);
    if ((mask & run) === run) return high;
  }
  return 0;
}

function pack(category, kickers) {
  let value = category;
  for (let i = 0; i < 5; i++) value = value * 15 + (i < kickers.length ? kickers[i] : 0);
  return value;
}

const counts = new Int32Array(15);
const suitMask = new Int32Array(4);
const suitCount = new Int32Array(4);

export function score(cards, n = cards.length) {
  counts.fill(0); suitMask.fill(0); suitCount.fill(0);
  let mask = 0;
  for (let i = 0; i < n; i++) {
    const c = cards[i];
    const rank = (c % 13) + 2;
    const suit = (c / 13) | 0;
    counts[rank]++;
    suitMask[suit] |= 1 << rank;
    suitCount[suit]++;
    mask |= 1 << rank;
  }
  let flushSuit = -1;
  for (let s = 0; s < 4; s++) if (suitCount[s] >= 5) flushSuit = s;
  if (flushSuit >= 0) {
    const sf = straightHigh(suitMask[flushSuit]);
    if (sf) return pack(8, [sf]);
  }
  const ranks = [], quads = [], trips = [], pairs = [];
  for (let r = 14; r >= 2; r--) {
    if (counts[r] > 0) ranks.push(r);
    if (counts[r] === 4) quads.push(r);
    if (counts[r] >= 3) trips.push(r);
    if (counts[r] >= 2) pairs.push(r);
  }
  const except = (list, excluded, count) => {
    const out = [];
    for (const r of list) {
      if (!excluded.includes(r)) out.push(r);
      if (out.length === count) break;
    }
    return out;
  };
  if (quads.length) return pack(7, [quads[0], ...except(ranks, [quads[0]], 1)]);
  if (trips.length) {
    const other = except(pairs, [trips[0]], 1);
    if (other.length) return pack(6, [trips[0], other[0]]);
  }
  if (flushSuit >= 0) {
    const flush = [];
    for (let r = 14; r >= 2 && flush.length < 5; r--) if (suitMask[flushSuit] & (1 << r)) flush.push(r);
    return pack(5, flush);
  }
  const st = straightHigh(mask);
  if (st) return pack(4, [st]);
  if (trips.length) return pack(3, [trips[0], ...except(ranks, [trips[0]], 2)]);
  if (pairs.length >= 2) return pack(2, [pairs[0], pairs[1], ...except(ranks, pairs.slice(0, 2), 1)]);
  if (pairs.length === 1) return pack(1, [pairs[0], ...except(ranks, pairs, 3)]);
  return pack(0, ranks.slice(0, 5));
}

// 169 hand classes on the usual 13×13 grid: index = row * 13 + col with row/col
// counting down from A (0) to 2 (12). Row < col is suited, row > col offsuit, diagonal pairs.
export function classIndex(a, b) {
  const ra = 12 - (a % 13), rb = 12 - (b % 13);
  const suited = ((a / 13) | 0) === ((b / 13) | 0);
  if (ra === rb) return ra * 13 + ra;
  const hi = Math.min(ra, rb), lo = Math.max(ra, rb); // hi = higher rank = smaller row
  return suited ? hi * 13 + lo : lo * 13 + hi;
}

export function className(index) {
  const row = (index / 13) | 0, col = index % 13;
  const r1 = RANKS[12 - Math.min(row, col)], r2 = RANKS[12 - Math.max(row, col)];
  return row === col ? r1 + r2 : r1 + r2 + (row < col ? 's' : 'o');
}

// Every two-card combo grouped by class.
export const COMBOS = [];
export const CLASS_COMBOS = Array.from({ length: 169 }, () => []);
for (let a = 0; a < 52; a++) for (let b = a + 1; b < 52; b++) {
  COMBOS.push([a, b]);
  CLASS_COMBOS[classIndex(a, b)].push([a, b]);
}

// Deterministic generator so every table can be reproduced from its seed.
export function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
