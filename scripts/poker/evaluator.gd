extends RefCounted
## Pure best-five evaluator. Card = suit * 13 + rank - 2; suits never break ties.

const NAMES = ["高牌", "一对", "两对", "三条", "顺子", "同花", "葫芦", "四条", "同花顺"]
const RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SUITS = ["♠", "♥", "♦", "♣"]

static func card_text(card: int) -> String:
	return RANKS[card % 13] + SUITS[int(card / 13)]

static func evaluate(cards: Array) -> Dictionary:
	if cards.size() < 5 or cards.size() > 7:
		return {}
	var seen = {}
	for card in cards:
		if card < 0 or card > 51 or seen.has(card):
			return {}
		seen[card] = true
	var best = {"score": -1}
	for a in range(cards.size() - 4):
		for b in range(a + 1, cards.size() - 3):
			for c in range(b + 1, cards.size() - 2):
				for d in range(c + 1, cards.size() - 1):
					for e in range(d + 1, cards.size()):
						var five = [cards[a], cards[b], cards[c], cards[d], cards[e]]
						var result = _five(five)
						if result.score > best.score:
							best = result
	return best

static func _five(cards: Array) -> Dictionary:
	var counts = {}
	var ranks = []
	var flush = true
	for card in cards:
		var rank = card % 13 + 2
		counts[rank] = counts.get(rank, 0) + 1
		ranks.append(rank)
		flush = flush and int(card / 13) == int(cards[0] / 13)
	ranks.sort()
	ranks.reverse()
	var straight = 0
	if counts.size() == 5:
		if ranks[0] - ranks[4] == 4:
			straight = ranks[0]
		elif ranks == [14, 5, 4, 3, 2]:
			straight = 5
	var groups = counts.keys()
	groups.sort_custom(func(a, b): return counts[a] > counts[b] if counts[a] != counts[b] else a > b)
	var category = 0
	var kickers = ranks.duplicate()
	if flush and straight > 0:
		category = 8
		kickers = [straight]
	elif counts[groups[0]] == 4:
		category = 7
		kickers = groups
	elif counts[groups[0]] == 3 and counts[groups[1]] == 2:
		category = 6
		kickers = groups
	elif flush:
		category = 5
	elif straight > 0:
		category = 4
		kickers = [straight]
	elif counts[groups[0]] == 3:
		category = 3
		kickers = groups
	elif counts[groups[0]] == 2 and counts[groups[1]] == 2:
		category = 2
		kickers = groups
	elif counts[groups[0]] == 2:
		category = 1
		kickers = groups
	var score: int = category
	for index in range(5):
		score = score * 15 + (kickers[index] if index < kickers.size() else 0)
	return {"score": score, "category": category, "name": NAMES[category], "kickers": kickers, "cards": cards.duplicate()}
