extends RefCounted
## Direct 5–7 card rank for simulation. Same base-15 score as evaluator.gd.
static func score(cards: Array) -> int:
	var counts = PackedInt32Array()
	counts.resize(15)
	var suits = [[], [], [], []]
	var mask: int = 0
	for card in cards:
		var rank: int = card % 13 + 2
		counts[rank] += 1
		suits[int(card / 13)].append(rank)
		mask |= 1 << rank
	var flush: Array = []
	for suit in suits:
		if suit.size() >= 5: flush = suit
	if not flush.is_empty():
		var flush_mask: int = 0
		for rank in flush: flush_mask |= 1 << rank
		var straight_flush = _straight(flush_mask)
		if straight_flush: return _pack(8, [straight_flush])
	var quads: Array = []
	var trips: Array = []
	var pairs: Array = []
	var ranks: Array = []
	for rank in range(14, 1, -1):
		if counts[rank] > 0: ranks.append(rank)
		if counts[rank] == 4: quads.append(rank)
		if counts[rank] >= 3: trips.append(rank)
		if counts[rank] >= 2: pairs.append(rank)
	if not quads.is_empty(): return _pack(7, [quads[0]] + _except(ranks, [quads[0]], 1))
	if not trips.is_empty():
		var other_pairs = _except(pairs, [trips[0]], 1)
		if not other_pairs.is_empty(): return _pack(6, [trips[0], other_pairs[0]])
	if not flush.is_empty():
		flush.sort()
		flush.reverse()
		return _pack(5, flush.slice(0, 5))
	var straight = _straight(mask)
	if straight: return _pack(4, [straight])
	if not trips.is_empty(): return _pack(3, [trips[0]] + _except(ranks, [trips[0]], 2))
	if pairs.size() >= 2: return _pack(2, pairs.slice(0, 2) + _except(ranks, pairs.slice(0, 2), 1))
	if pairs.size() == 1: return _pack(1, pairs + _except(ranks, pairs, 3))
	return _pack(0, ranks.slice(0, 5))

static func _straight(mask: int) -> int:
	if mask & (1 << 14): mask |= 1 << 1
	for high in range(14, 4, -1):
		var run = 31 << (high - 4)
		if mask & run == run: return high
	return 0

static func _except(ranks: Array, excluded: Array, count: int) -> Array:
	var out: Array = []
	for rank in ranks:
		if rank not in excluded: out.append(rank)
		if out.size() == count: break
	return out

static func _pack(category: int, kickers: Array) -> int:
	var value = category
	for index in range(5): value = value * 15 + (kickers[index] if index < kickers.size() else 0)
	return value
