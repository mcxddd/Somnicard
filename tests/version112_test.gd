extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const Config = preload("res://scripts/ai/config.gd")
const Protocol = preload("res://scripts/ai/protocol.gd")
const History = preload("res://scripts/poker/history.gd")
var checks = 0
var failures = 0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)
func run() -> void:
	var game = Table.new([1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000], 5, 10, 112)
	game.start_hand(0)
	var names = []
	for seat in game.seats:
		verify(not seat.name.begins_with("电脑") and not seat.name.is_empty() and seat.name not in names, "offline seats start with distinct names")
		names.append(seat.name)
	var actor: int = game.actor
	game.act(actor, "call")
	var secret_view: Dictionary = game.view_for(actor)
	var messages = Protocol.messages(secret_view, actor, Config.seats([])[actor - 1], {"difficulty": 1, "aggression": 2}, {}, true, [{"name": "小夏", "text": "这注我跟了。", "private": "SECRET"}])
	var data: Dictionary = JSON.parse_string(messages[1].content)
	verify(data.observation.seats.all(func(s): return not s.has("your_hole")), "table talk has no private cards, including its own")
	verify(not data.observation.has("legal") and not data.has("deck"), "speech does not receive private decision context")
	verify(data.your_last_action.seat == actor and data.your_last_action.action == "call", "talk anchored to speaker's actual public action")
	verify(data.recent_table_talk.size() == 1 and not JSON.stringify(data).contains("SECRET"), "recent speech uses public allowlist")
	for text in ["这注我跟了。", "这点筹码就想把我赶走？", "行，这口先让你。", "河牌还真会挑时候。"]:
		verify(Protocol.table_talk(JSON.stringify({"text": text})).get("text") == text, "natural table reactions survive unchanged")
	for text in ["你好，大家好！", "祝大家好运", "作为 AI，我会谨慎操作", "As an AI, I suggest calling", "根据分析，我建议你跟注", "这手有意思，继续观察。", "这手有意思。", "**我加注**", "<think>分析</think>", "http://example.invalid", "第一句\n第二句", "长".repeat(37)]:
		verify(Protocol.table_talk(JSON.stringify({"text": text})).has("error"), "greetings, role labels and filler are suppressed")
	verify(Protocol.table_talk('{"text":"这注我跟了！"}', ["这注我跟了。"]).has("error"), "punctuation changes do not bypass repetition filter")
	verify(Protocol.table_talk('{"text":""}').get("text", "bad") == "", "silence is valid")
	verify(Protocol.table_talk('{"text":12}').has("error"), "non-text speech is rejected")
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	verify(not quit_on_go_back, "Android back does not automatically terminate the SceneTree")
	ui._start_table(9)
	ui._open_settings()
	ui.settings._select_page(4)
	ui._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	verify(ui.settings.visible and ui.settings.current_page == -1, "Android back returns from setting detail to categories")
	ui.settings._select_page(4)
	var editor = ui.settings.opponent_editor
	editor.select(1)
	verify(editor.name_edit.is_visible_in_tree() and not editor.ai_fields.visible, "local opponents expose rename without online fields")
	for i in range(8): await process_frame
	ui.settings._layout(280)
	for i in range(8): await process_frame
	ui.settings._reveal_editor(editor.name_edit)
	for i in range(8): await process_frame
	verify(ui.settings.panel.get_rect().end.y <= ui.settings.size.y - 280, "settings panel avoids keyboard including footer: %s / %s" % [ui.settings.panel.get_rect(), ui.settings.size])
	verify(ui.settings.scroll.get_global_rect().grow(1).encloses(editor.name_edit.get_global_rect()), "focused editor scrolls above keyboard")
	ui.settings._layout(0)
	editor.name_edit.text = "阿北"
	editor.name_edit.text_changed.emit("阿北")
	ui.settings.cancel()
	verify(ui.game.seats[1].name != "阿北", "cancelled local rename stays a draft")
	ui._open_settings()
	ui.settings._select_page(4)
	editor.select(1)
	editor.name_edit.text = "阿北"
	editor.name_edit.text_changed.emit("阿北")
	ui._apply_settings(ui.settings.values())
	verify(ui.game.seats[1].name == "阿北" and not ui.ai_seats[0].enabled, "saving rename updates local table without enabling network")
	ui.settings.cancel()
	while ui.game.phase != "complete": ui.game.act(ui.game.actor, "check" if ui.game.legal_actions(ui.game.actor).check else "call")
	var replay = History.replay(ui.game.completed_record())
	verify(not replay.has("error") and replay.game.seats[1].name == "阿北", "replay preserves renamed local identity")
	ui._next_hand()
	ui.speech_actor = 1
	ui.speech_event = ui.game.events.size()
	ui.speech_stamp = "%s:%d" % [ui.session_id, ui.game.hand_number]
	ui.speech_phase = "river" if ui.game.phase != "river" else "flop"
	ui._speech_received({"content": '{"text":"这注我跟了。"}'})
	verify(ui.ai_dialogue.is_empty(), "late speech from another street is discarded")
	ui.speech_phase = ui.game.phase
	ui._speech_received({"content": '{"text":"这注我跟了。"}'})
	verify(ui.ai_dialogue.size() == 1 and ui.ai_dialogue[0].event == ui.speech_event, "speech preserves original event anchor")
	ui._speech_received({"content": '{"text":"你好，祝你好运。"}'})
	verify(ui.ai_dialogue.size() == 1, "greeting is not displayed")
	ui.queue_free()
	await process_frame
	print("VERSION112_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
