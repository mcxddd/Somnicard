extends Node
## Depends on host: ai, game, smoke_mode, player_count, difficulty, opponent_profiles, opponent_changes, training, starting_bb.
var host
const History = preload("res://scripts/poker/history.gd")
const LocalBot = preload("res://scripts/poker/local_bot.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const Session = preload("res://scripts/poker/session.gd")
var session_id: String = ""
var saved_hand: int = -1
var save_status: String = ""
var session_stamp: String = ""
var session_save_error: bool = false

func save_record() -> void:
	host.ai.finish_hand()
	if saved_hand == host.game.hand_number: return
	if host.smoke_mode:
		save_status = "测试模式"
		saved_hand = host.game.hand_number
		return
	var record = host.game.completed_record()
	record["seat_names"] = host.game.seats.map(func(s): return s.name)
	record["ai_dialogue"] = host.ai.dialogue.duplicate(true)
	record["online_seats"] = host.ai.seats.slice(0, host.player_count - 1).map(func(p): return p.enabled)
	record["id"] = History.hand_id(record)
	record["difficulty"] = host.difficulty
	record["bot_version"] = LocalBot.VERSION
	record["opponents"] = Profiles.snapshot(host.opponent_profiles, host.player_count, host.difficulty)
	record["opponent_changes"] = host.opponent_changes.duplicate(true)
	record["table_size"] = host.player_count
	record["saved_at"] = Time.get_datetime_string_from_system().replace("T", " ")
	if History.save(record, "%s-%04d.json" % [session_id, host.game.hand_number]) != OK:
		save_status = "保存失败 · 请检查存储空间；返回此页会重试"
		return
	saved_hand = host.game.hand_number
	save_status = "记录已保存"
	if host.training.store != null: host.training.store.suggest_hand(record)

func enabled() -> bool:
	return not host.smoke_mode and DisplayServer.get_name() != "headless" and "--capture-test" not in OS.get_cmdline_user_args()

func save_session() -> void:
	if not enabled() or host.game == null or host.game.phase == "idle": return
	var stamp = "%s:%d:%d:%d" % [session_id, host.game.hand_number, host.game.events.size(), saved_hand]
	if stamp == session_stamp: return
	session_save_error = Session.save(host.game, session_id, host.starting_bb, saved_hand, "user://", Profiles.snapshot(host.opponent_profiles, host.player_count, host.difficulty), host.opponent_changes, host.opponent_profiles, host.difficulty, host.ai.session_state()) != OK
	if not session_save_error: session_stamp = stamp
