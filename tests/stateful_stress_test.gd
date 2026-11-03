extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const History = preload("res://scripts/poker/history.gd")
var checks = 0
var failures = 0
var hands = 0
var actions = 0
var restored = 0
var rng = RandomNumberGenerator.new()
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func normalized(value): return JSON.parse_string(JSON.stringify(value))
func run() -> void:
	rng.seed = 23111049
	for count in range(2, 7):
		for trial in range(64):
			var stacks: Array = []
			for id in range(count): stacks.append(rng.randi_range(1, 2000) if trial % 3 else [1, 5, 9, 10, 11, 19, 100, 1000, 2000][rng.randi_range(0, 8)])
			var game = Table.new(stacks, 5, 10, 9000000 + count * 10000 + trial)
			var total = game.chip_total()
			for hand in range(8):
				if game.start_hand() != "": break
				var moves = 0
				while game.phase != "complete" and moves < 500:
					var actor = game.actor
					var legal: Dictionary = game.legal_actions(actor)
					verify(not legal.is_empty(), "every unfinished hand has a legal actor")
					if legal.is_empty(): break
					var before = normalized(game.record_state())
					verify(game.act((actor + 1) % count, "call") != "" and normalized(game.record_state()) == before, "out-of-turn operation has no side effects")
					verify(game.act(actor, "raise", legal.max_raise_to + 1) != "" and normalized(game.record_state()) == before, "invalid raise has no side effects")
					if moves % 9 == 3:
						var rebuilt = History.replay(before, false)
						verify(not rebuilt.has("error"), "partial state survives disk-like JSON replay")
						if not rebuilt.has("error"):
							for viewer in range(count): verify(normalized(rebuilt.game.view_for(viewer)) == normalized(game.view_for(viewer)), "restored state matches every player's information")
							restored += 1
					var view = game.view_for(actor)
					verify(not view.has("deck") and view.seats.filter(func(s): return s.id != actor).all(func(s): return s.hole.is_empty()), "all other players' hole cards remain private")
					var choices: Array = ["check" if legal.check else "call", "check" if legal.check else "call", "fold"]
					if legal.all_in: choices.append("all_in")
					if legal.raise and legal.min_raise_to <= legal.max_raise_to: choices.append("raise")
					var chosen = choices[rng.randi_range(0, choices.size() - 1)]
					var amount = rng.randi_range(legal.min_raise_to, legal.max_raise_to) if chosen == "raise" else 0
					verify(game.act(actor, chosen, amount) == "", "random legal decision accepted")
					verify(game.chip_total() == total and game.seats.all(func(s): return s.stack >= 0 and s.total_bet >= 0), "every action conserves nonnegative chips")
					moves += 1
					actions += 1
				verify(game.phase == "complete", "bounded action sequence settles")
				var complete = History.replay(normalized(game.completed_record()))
				verify(not complete.has("error") and normalized(complete.final) == normalized(game.view_for(0)), "history reconstruction reproduces showdown and payouts")
				for viewer in range(count):
					var view = game.view_for(viewer)
					for seat in view.seats:
						if seat.id != viewer and (seat.folded or not game.result.showdown): verify(seat.hole.is_empty(), "folded or unshown cards stay private after settlement")
				hands += 1
				if failures: quit(1); return
			if trial % 16 == 0: await process_frame
		print("STRESS_PROGRESS seats=%d hands=%d actions=%d" % [count, hands, actions])
	print("STATEFUL_STRESS_TESTS: %d hands, %d actions, %d partial restores, %d checks, %d failures" % [hands, actions, restored, checks, failures])
	quit(1 if failures else 0)
