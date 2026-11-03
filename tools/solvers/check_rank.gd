extends SceneTree
## Writes random 7-card hands with the game's own scores so check_rank.mjs can
## prove the offline evaluator ranks every hand exactly like fast_rank.gd.
const Rank = preload("res://scripts/poker/fast_rank.gd")

func _initialize() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20261104
	var rows: Array = []
	for i in range(20000):
		var deck = range(52)
		for j in range(7):
			var k = rng.randi_range(j, 51)
			var t = deck[j]; deck[j] = deck[k]; deck[k] = t
		var cards = deck.slice(0, 7)
		rows.append([cards, Rank.score(cards)])
	var file = FileAccess.open("res://.local/rank-vectors.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows))
	file.close()
	print("RANK_VECTORS %d" % rows.size())
	quit()
