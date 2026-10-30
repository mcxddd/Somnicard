extends RefCounted
## Versioned local records. Rebuild through the rules engine before trusting a file.
const Table = preload("res://scripts/poker/table.gd")
const DIRECTORY = "user://hands"
const MAX_BYTES = 3 * 1024 * 1024

static func hand_id(record: Dictionary) -> String:
	# Stable across JSON roundtrips, partial sessions and older records. Not a deck encoding.
	if not record.get("starting_stacks") is Array or not record.get("deck") is Array: return "待校验"
	var stacks: Array = []
	var deck: Array = []
	for chips in record.get("starting_stacks", []): stacks.append(int(chips) if chips is float or chips is int else str(chips))
	for card in record.get("deck", []): deck.append(int(card) if card is float or card is int else str(card))
	var identity = [int(record.get("hand", 0)), int(record.get("button", 0)), int(record.get("small_blind", 5)), int(record.get("big_blind", 10)), stacks, deck]
	return "SC-" + JSON.stringify(identity).sha256_text().left(16).to_upper()

static func save(record: Dictionary, filename: String, directory: String = DIRECTORY) -> Error:
	if filename.get_file() != filename or not filename.ends_with(".json"): return ERR_INVALID_PARAMETER
	var err = DirAccess.make_dir_recursive_absolute(directory)
	if err != OK: return err
	var path = directory.path_join(filename)
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(record))
	file.flush()
	err = file.get_error()
	file.close()
	if err != OK: return err
	return DirAccess.rename_absolute(path + ".tmp", path)

static func files(directory: String = DIRECTORY) -> Array:
	var found: Array = []
	if not DirAccess.dir_exists_absolute(directory): return found
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".json"): found.append(name)
	found.sort()
	found.reverse()
	return found

static func read_record(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null: return {"error": "无法读取牌局文件"}
	if file.get_length() > MAX_BYTES: return {"error": "牌局文件过大"}
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary: return {"error": "记录格式损坏"}
	return {"record": parser.data}

static func _integer(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == int(value) and value >= low and value <= high

static func replay(record: Dictionary, require_complete: bool = true) -> Dictionary:
	if record.get("schema_version") != 1: return {"error": "暂不支持此版本的记录"}
	var stacks = record.get("starting_stacks")
	var deck = record.get("deck")
	var events = record.get("events")
	if not stacks is Array or stacks.size() < 2 or stacks.size() > 9: return {"error": "座位数据无效"}
	for chips in stacks:
		if not _integer(chips, 0, 100000000): return {"error": "筹码数据无效"}
	if not _integer(record.get("small_blind"), 1, 1000000) or not _integer(record.get("big_blind"), 1, 1000000): return {"error": "盲注数据无效"}
	if record.big_blind < record.small_blind: return {"error": "盲注大小无效"}
	if not _integer(record.get("button"), 0, stacks.size() - 1) or not _integer(record.get("hand"), 1, 100000000): return {"error": "牌局编号无效"}
	if not deck is Array or deck.size() != 52: return {"error": "牌堆数据无效"}
	var cards: Array = []
	for card in deck:
		if not _integer(card, 0, 51): return {"error": "牌堆数据无效"}
		cards.append(int(card))
	if not events is Array or events.size() > 1000: return {"error": "操作记录无效"}
	var game = Table.new(stacks, int(record.small_blind), int(record.big_blind))
	if record.get("seat_names") is Array:
		for i in range(mini(stacks.size(), record.seat_names.size())):
			var name = preload("res://scripts/ai/config.gd").clean(record.seat_names[i], 12)
			if name != "": game.seats[i].name = name
	game.hand_number = int(record.hand) - 1
	var frames: Array = []
	game.event_observer = func(event, snapshot):
		# An event may be emitted between rule transitions: only explicit decision
		# frames are actionable. Public runout streets remain separate visible steps.
		snapshot.actor = -1
		snapshot.legal = {}
		frames.append({"event": event, "view": snapshot, "decision": false})
	var err = game.start_hand(int(record.button), cards)
	if err != "": return {"error": err}
	for event in events:
		if not event is Dictionary: return {"error": "操作格式损坏"}
		if event.get("kind") != "action": continue
		if not _integer(event.get("seat"), 0, stacks.size() - 1) or not _integer(event.get("to"), 0, 900000000): return {"error": "下注格式损坏"}
		if event.get("action") not in ["fold", "check", "call", "raise"]: return {"error": "未知操作"}
		frames.append({"event": {"kind": "decision", "seat": game.actor}, "view": game.view_for(0), "decision": true})
		err = game.act(int(event.seat), event.action, int(event.to))
		if err != "": return {"error": "无法重建牌局：" + err}
	game.event_observer = Callable()
	if require_complete and game.phase != "complete": return {"error": "记录尚未完成"}
	# JSON normalization makes integer dictionary keys comparable after loading.
	var actual = JSON.parse_string(JSON.stringify(game.record_state()))
	var expected = JSON.parse_string(JSON.stringify(record))
	if actual.events != expected.events or actual.result != expected.get("result"): return {"error": "记录与规则重算结果不一致"}
	return {"frames": frames, "record": record, "net": game.seats[0].stack - int(stacks[0]), "final": game.view_for(0), "game": game}
