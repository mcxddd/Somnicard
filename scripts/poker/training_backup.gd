extends RefCounted
const History = preload("res://scripts/poker/history.gd")
const Store = preload("res://scripts/poker/training_store.gd")
const MAX_BYTES = 64 * 1024 * 1024

static func export_file(path: String, store, directory: String) -> String:
	var hands: Array = []
	for name in History.files(directory):
		var read = History.read_record(directory.path_join(name))
		if read.has("error") or History.replay(read.record).has("error"): return "存在无法校验的牌局，未导出；请先检查历史记录。"
		hands.append(read.record)
	var payload = JSON.stringify({"format": "somnicard-training", "version": 1, "profile": store.data, "hands": hands})
	if payload.to_utf8_buffer().size() > MAX_BYTES: return "备份超过 64 MB，请暂时保留本机数据。"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null: return "无法写入所选位置。"
	f.store_string(payload)
	f.flush()
	var err = f.get_error()
	f.close()
	return "" if err == OK else "备份写入失败，请检查存储空间。"

static func import_file(path: String, store, directory: String) -> Dictionary:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() > MAX_BYTES: return {"error": "无法读取备份，或文件超过 64 MB。"}
	var payload = JSON.parse_string(f.get_as_text())
	f.close()
	if not payload is Dictionary or payload.get("format") != "somnicard-training" or payload.get("version") != 1 or not Store.valid(payload.get("profile")) or not payload.get("hands") is Array:
		return {"error": "备份格式不受支持，未修改本机记录。"}
	if payload.hands.size() > 5000: return {"error": "备份牌局数量超过本版导入上限。"}
	var incoming = {}
	for r in payload.hands:
		if not r is Dictionary or History.replay(r).has("error"): return {"error": "备份中的牌局未通过规则校验，未导入。"}
		incoming[History.hand_id(r)] = r
	for b in payload.profile.branches.values():
		if History.replay(b.record).has("error"): return {"error": "练习分支未通过校验，未导入。"}
	var merged: Dictionary = store.data.duplicate(true)
	if not merged.has("academy"): merged["academy"] = {}
	for key in payload.profile.get("academy", {}):
		var incoming_answer: Dictionary = payload.profile.academy[key]
		var previous_answer: Dictionary = merged.academy.get(key, {})
		if previous_answer.is_empty(): merged.academy[key] = incoming_answer.duplicate()
		else:
			previous_answer.correct = previous_answer.correct or incoming_answer.correct
			previous_answer.tries = maxi(int(previous_answer.tries), int(incoming_answer.tries))
	for key in payload.profile.marks:
		if not merged.marks.has(key): merged.marks[key] = payload.profile.marks[key]
	for key in payload.profile.branches:
		if not merged.branches.has(key): merged.branches[key] = payload.profile.branches[key]
	if not merged.has("decisions"): merged["decisions"] = {}
	for key in payload.profile.get("decisions", {}):
		if not merged.decisions.has(key): merged.decisions[key] = payload.profile.decisions[key]
	var ids = {}
	for a in merged.attempts: ids[a.id] = true
	for a in payload.profile.attempts:
		if not ids.has(a.id):
			merged.attempts.append(a)
			ids[a.id] = true
	# Imported unfinished sessions are intentionally not resumed without reselecting a lesson.
	if not Store.valid(merged): return {"error": "合并后的档案超过本版容量，未导入。"}
	var existing = {}
	for name in History.files(directory):
		var loaded = History.read_record(directory.path_join(name))
		if not loaded.has("error"): existing[History.hand_id(loaded.record)] = true
	var created: Array = []
	for id in incoming:
		if existing.has(id): continue
		var stamp = int(Time.get_unix_time_from_datetime_string(str(incoming[id].get("saved_at", "")).replace(" ", "T")))
		var filename = "%d-import-%s.json" % [maxi(0, stamp), Store.uid()]
		var target = directory.path_join(filename)
		if History.save(incoming[id], filename, directory) != OK:
			for p in created: DirAccess.remove_absolute(p)
			return {"error": "存储写入失败，已撤回本次新增文件。"}
		created.append(target)
	var failed_before: bool = store.load_failed
	if failed_before and not store.path.is_empty():
		var copy_error = DirAccess.copy_absolute(store.path, store.path + ".corrupt-" + Store.uid())
		if copy_error != OK:
			for p in created: DirAccess.remove_absolute(p)
			return {"error": "无法保留损坏档案的副本，尚未恢复。"}
		store.load_failed = false
	var previous: Dictionary = store.data
	store.data = merged
	if not store.save():
		store.data = previous
		store.load_failed = failed_before
		for p in created: DirAccess.remove_absolute(p)
		return {"error": store.error}
	return {"added": created.size(), "attempts": merged.attempts.size()}
