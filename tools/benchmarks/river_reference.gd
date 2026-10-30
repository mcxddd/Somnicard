extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const River = preload("res://scripts/poker/river_cfr.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cases: Array = []
	for scenario in range(3):
		for detail in range(2):
			var game = Table.new([1000, 1000], 5, 10, 119110 + scenario)
			game.start_hand(1 if scenario == 0 else 0)
			while game.phase != "river": game.act(game.actor, "check" if game.legal_actions(game.actor).check else "call")
			if scenario == 1: game.act(1, "check")
			if scenario == 2: game.act(1, "raise", 20)
			var solver = River.new(Advisor.information(game.view_for(0)), 2400 if detail else 1200, detail)
			var start = Time.get_ticks_msec()
			var max_step = 0
			while solver.supported and (not solver.ready or solver.iterations < solver.target):
				var begin = Time.get_ticks_usec()
				solver.step()
				max_step = maxi(max_step, Time.get_ticks_usec() - begin)
				if solver.iterations % 20 == 0: await process_frame
			if not solver.supported: printerr("REFERENCE_UNSUPPORTED"); quit(1); return
			cases.append({"scenario": scenario, "detail": detail, "buckets": solver.bucket_count, "nodes": solver.nodes, "terminals": solver.terminals, "joint": solver.joint, "outcomes": solver.outcomes, "average": solver.profile(), "result": solver.result(), "epsilon": solver.exploitability(), "duration_ms": Time.get_ticks_msec() - start, "max_step_us": max_step})
			print("REFERENCE_PROGRESS scenario=%d detail=%d epsilon=%.6f" % [scenario, detail, solver.exploitability()])
			var file = FileAccess.open("res://.local/river-reference-111.json", FileAccess.WRITE)
			file.store_string(JSON.stringify(cases)); file.close()
	print("REFERENCE_EXPORT_COMPLETE")
	quit()
