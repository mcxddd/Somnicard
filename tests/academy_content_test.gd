extends SceneTree
const Academy = preload("res://scripts/product/academy.gd")
const Evaluator = preload("res://scripts/poker/evaluator.gd")
const Table = preload("res://scripts/poker/table.gd")
const Store = preload("res://scripts/poker/training_store.gd")
# Generated from HEAD 4c13337's LESSONS before expansion; exemptions follow IDs.
const LEGACY_QUESTION_IDS = [
	"start:0", "start:1", "start:2", "position:0", "position:1", "position:2",
	"price:0", "price:1", "price:2", "sizing:0", "sizing:1", "sizing:2",
	"draw:0", "draw:1", "draw:2", "range:0", "range:1", "range:2",
	"review:0", "review:1", "review:2", "tools:0", "tools:1", "tools:2"
]
var checks = 0
var failures = 0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)

func item(id: String) -> Dictionary:
	for lesson in Academy.LESSONS:
		if lesson.id == id.get_slice(":", 0): return lesson.questions[int(id.get_slice(":", 1))]
	return {}

func correct_text(id: String) -> String:
	var q = item(id)
	return q.choices[q.correct]

func card(rank: int, suit: int) -> int:
	return suit * 13 + rank - 2

func ratio(id: String, calculated: float, expected: float, text: String) -> void:
	verify(absf(calculated - expected) < 0.000001, id + " recomputed ratio")
	verify(correct_text(id).contains(text), id + " correct option contains computed value " + text)

func run() -> void:
	verify(Academy.LESSONS.size() == 12 and Academy.question_ids().size() == 60, "12 lessons and 60 questions")
	verify(LEGACY_QUESTION_IDS.size() == 24 and LEGACY_QUESTION_IDS.all(func(id): return id in Academy.question_ids()), "all HEAD question IDs remain present")
	var positions = {}
	var new_count = 0
	var unique_ids = {}
	for lesson in Academy.LESSONS:
		verify(lesson.questions.size() == 5, lesson.id + " has five questions")
		for i in range(lesson.questions.size()):
			var id: String = lesson.id + ":" + str(i)
			verify(not unique_ids.has(id), id + " unique ID")
			unique_ids[id] = true
			var q = lesson.questions[i]
			verify(q.correct is int and q.correct >= 0 and q.correct <= 2, id + " valid correct index")
			verify(q.choices.size() == 3 and q.choices[0] != q.choices[1] and q.choices[0] != q.choices[2] and q.choices[1] != q.choices[2], id + " three distinct choices")
			if id not in LEGACY_QUESTION_IDS:
				new_count += 1
				verify(q.reason.length() >= 40, id + " new explanation at least 40 characters")
				positions[q.correct] = true
	verify(new_count == 36 and positions.size() == 3, "36 additions distribute correct answers across all three positions")
	_test_hands()
	_test_prices()
	_test_draws()
	_test_combinations()
	_test_table()
	_test_missed()
	print("ACADEMY_CONTENT_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_hands() -> void:
	var board = [card(13, 0), card(9, 2), card(5, 3), card(2, 1), card(2, 2)]
	var a = Evaluator.evaluate(board + [card(13, 1), card(12, 3)])
	var b = Evaluator.evaluate(board + [card(13, 2), card(11, 1)])
	verify(a.category == 2 and b.category == 2 and a.score > b.score and correct_text("start:3") == "甲赢，Q 踢脚大于 J", "start:3 evaluator awards two-pair kicker to player A")
	var flush = Evaluator.evaluate([card(14, 0), card(11, 0), card(8, 0), card(5, 0), card(2, 0), card(3, 1), card(4, 2)])
	var straight = Evaluator.evaluate([card(9, 0), card(8, 1), card(7, 2), card(6, 3), card(5, 0), card(2, 1), card(3, 2)])
	verify(flush.category == 5 and straight.category == 4 and flush.score > straight.score and correct_text("start:4") == "同花更大", "start:4 evaluator ranks flush over straight")

func _test_prices() -> void:
	ratio("price:3", 50.0 / (100 + 50 + 50), 0.25, "25%")
	ratio("price:4", 100.0 / (100 + 100 + 100), 1.0 / 3, "33.3%")
	ratio("sizing:4", 50.0 / (100 + 50), 1.0 / 3, "33.3%")
	ratio("value:2", 100.0 / (100 + 100), 0.5, "50%")
	ratio("value:4", 50.0 / (100 + 50 + 50), 0.25, "25%")
	var pot = 5 + 10 + 10 + 10
	ratio("multiway:2", 10.0 / (pot + 10), 2.0 / 9, "22.2%")
	ratio("spr:1", float(mini(400, 300)) / 100, 3.0, "3")

func _test_draws() -> void:
	# 8♠ 9♦ on 10♣ J♥ 2♠: precisely the four 7s and four Qs make a straight.
	var known = [card(8, 0), card(9, 2), card(10, 3), card(11, 1), card(2, 0)]
	var unknown: Array = []
	var outs: Array = []
	for c in range(52):
		if c in known: continue
		unknown.append(c)
		if Evaluator.evaluate(known + [c]).category == 4: outs.append(c)
	verify(unknown.size() == 47 and outs.size() == 8, "draw:3 concrete open-ended draw has eight engine-verified outs")
	var total = 0
	var hits = 0
	for a in range(unknown.size() - 1):
		for b in range(a + 1, unknown.size()):
			total += 1
			if unknown[a] in outs or unknown[b] in outs: hits += 1
	var probability = float(hits) / total
	verify(total == 47 * 46 / 2 and absf(probability - (1.0 - 39.0 / 47 * 38.0 / 46)) < 0.000001, "draw:3 exhausts every unordered runout and matches complement formula")
	verify(absf(probability * 100 - 31.5) < 0.1 and correct_text("draw:3").contains("31.5%"), "draw:3 enumerated probability matches correct option within 0.1 percentage points")
	verify(9 * 2 == 18 and absf(9.0 / 46 * 100 - 19.6) < 0.1 and correct_text("draw:4").contains("近似快速估计"), "draw:4 rule of two is approximate, not exact turn probability")

func _test_combinations() -> void:
	var aa = 0
	var suited_ak = 0
	var offsuit_ak = 0
	var blocked_aa = 0
	var board_ace = card(14, 0)
	for a in range(51):
		for b in range(a + 1, 52):
			var ra = a % 13 + 2
			var rb = b % 13 + 2
			if ra == 14 and rb == 14:
				aa += 1
				if a != board_ace and b != board_ace: blocked_aa += 1
			if (ra == 14 and rb == 13) or (ra == 13 and rb == 14):
				if int(a / 13) == int(b / 13): suited_ak += 1
				else: offsuit_ak += 1
	verify(aa == 6 and correct_text("range:3").contains("6 种"), "range:3 enumerated AA count equals correct option")
	verify(suited_ak == 4 and offsuit_ak == 12 and item("range:3").reason.contains("4 种") and item("range:3").reason.contains("12 种"), "range:3 enumerated suited and offsuit AK counts match explanation")
	verify(blocked_aa == 3 and correct_text("range:4").contains("3 种"), "range:4 board ace reduces AA combinations to three")
	var board = [card(8, 0), card(8, 2), card(3, 3)]
	var remaining_eights = 0
	for c in range(52):
		if c not in board and c % 13 + 2 == 8: remaining_eights += 1
	verify(remaining_eights == 2 and correct_text("texture:3") == "2 张", "texture:3 enumeration leaves two unknown eights")

func _test_table() -> void:
	var table = Table.new([1000, 1000, 1000, 1000, 1000, 1000], 5, 10, 42)
	verify(table.start_hand(0) == "" and table.act(table.actor, "raise", 30) == "", "sizing:3 create real 5/10 table and raise to 30")
	var legal = table.legal_actions(table.actor)
	verify(legal.raise and legal.min_raise_to == 50 and correct_text("sizing:3") == str(legal.min_raise_to), "sizing:3 legal_actions minimum re-raise is 50")
	verify(table.act(table.actor, "raise", 40) != "" and table.act(table.actor, "raise", 50) == "", "sizing:3 engine rejects short raise and accepts minimum")
	var position_table = Table.new([1000, 1000, 1000, 1000, 1000, 1000], 5, 10, 43)
	position_table.start_hand(0)
	while position_table.phase == "preflop":
		var actions = position_table.legal_actions(position_table.actor)
		position_table.act(position_table.actor, "check" if actions.check else "call")
	var last_actor = -1
	while position_table.phase == "flop":
		last_actor = position_table.actor
		position_table.act(last_actor, "check")
	verify(last_actor == position_table.button and correct_text("position:3") == "庄家（按钮位）", "position:3 button acts last in a six-player flop")

func _test_missed() -> void:
	var store = Store.new("")
	var correct: int = item("start:0").correct
	Academy.answer(store, 0, 0, (correct + 1) % 3)
	verify(Academy.missed(store.data) == ["start:0"] and store.data.academy["start:0"].missed, "wrong answer sets missed")
	Academy.answer(store, 0, 0, correct)
	verify(Academy.missed(store.data) == ["start:0"], "normal lesson success retains missed")
	Academy.answer(store, 0, 0, correct, true)
	verify(Academy.missed(store.data).is_empty() and store.data.academy["start:0"].tries == 3 and store.data.academy["start:0"].correct, "first-try review success clears missed while preserving tries and completion")
	store.data.academy = {"tools:4": {"correct": true, "tries": 2, "date": ""}, "start:3": {"correct": true, "tries": 3, "date": ""}, "start:0": {"correct": true, "tries": 1, "date": ""}}
	verify(Academy.valid(store.data.academy) and Academy.missed(store.data) == ["start:3", "tools:4"], "legacy inference uses tries > 1 and returns curriculum order")
	store.data.academy["start:3"]["missed"] = false
	verify(Academy.missed(store.data) == ["tools:4"], "explicit false overrides legacy retry inference")
	for invalid in [0, "true", null]:
		verify(not Academy.valid({"start:0": {"correct": true, "tries": 1, "date": "", "missed": invalid}}), "non-bool optional missed rejected")
	var all_answers = Store.new("")
	for l in range(Academy.LESSONS.size()):
		for q in range(Academy.LESSONS[l].questions.size()): Academy.answer(all_answers, l, q, Academy.LESSONS[l].questions[q].correct)
	verify(all_answers.data.academy.size() == 60 and Academy.valid(all_answers.data.academy) and Store.valid(all_answers.data), "full 60-answer profile passes academy and store validation")
