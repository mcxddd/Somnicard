extends SceneTree
const Arena = preload("res://scripts/ai/arena.gd")
var blocks = 128
var output = "res://.local/arena-1.11.0.json"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--blocks="): blocks = maxi(2, int(arg.trim_prefix("--blocks=")))
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	var reports = {}
	for level in range(3):
		for style in range(3):
			var arena = Arena.new()
			arena.path = ""
			root.add_child(arena)
			arena.set_process(false)
			arena.start({"level": level, "style": style, "blocks": blocks if style == 0 else mini(32, blocks), "counts": [2, 6, 9] if style == 0 else [9], "depths": [50, 100, 200] if style == 0 else [100], "seed": 11102601})
			var checkpoint = -1
			while arena.running:
				for step in range(300):
					if not arena.running: break
					arena.tick()
				var progress = int(arena.data.cursor / 100)
				if progress != checkpoint:
					checkpoint = progress
					print("ARENA_PROGRESS level=%d style=%d hands=%d/%d" % [level, style, arena.data.cursor, arena.plan.size()])
				await process_frame
			reports["level%d-style%d" % [level, style]] = arena.report()
			if not arena.report().completed: printerr("ARENA_FAILED " + arena.status); quit(1); return
			arena.queue_free()
			var file = FileAccess.open(output, FileAccess.WRITE)
			file.store_string(JSON.stringify({"version": Arena.VERSION, "reports": reports}, "\t")); file.close()
	print("ARENA_COMPLETE reports=" + str(reports.size()))
	quit()
