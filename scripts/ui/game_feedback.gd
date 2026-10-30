extends Node
## Short original cues; no loops, autoplay music, or hidden background audio.
const SOUNDS = {"deal": preload("res://assets/audio/deal.wav"), "chips": preload("res://assets/audio/chips.wav"), "turn": preload("res://assets/audio/turn.wav"), "win": preload("res://assets/audio/win.wav"), "split": preload("res://assets/audio/split.wav")}
var player: AudioStreamPlayer
var volume = 1
var haptics = false
var stamp = ""
var event_count = 0
var actor = -1
var active = true
var last_cue = ""

func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)

func configure(settings: Dictionary) -> void:
	volume = clampi(int(settings.get("sound", 1)), 0, 2)
	haptics = settings.get("haptics", false)
	if volume == 0: player.stop()
	player.volume_db = -8 if volume == 1 else 0

func cue(name: String, vibrate: bool = false) -> void:
	if not active or not SOUNDS.has(name): return
	last_cue = name
	if volume > 0 and DisplayServer.get_name() != "headless":
		player.stream = SOUNDS[name]
		player.play()
	if vibrate and haptics and OS.has_feature("mobile"): Input.vibrate_handheld(35)

func sync(game, session: String, blocked: bool) -> void:
	var new_stamp = session + ":" + str(game.hand_number)
	if new_stamp != stamp:
		stamp = new_stamp
		event_count = game.events.size()
		actor = game.actor
		if not blocked: cue("deal", game.actor == 0)
		return
	if event_count == game.events.size(): return
	event_count = game.events.size()
	if not blocked:
		if game.phase == "complete":
			var split = game.result.pots.any(func(p): return 0 in p.winners and p.winners.size() > 1)
			if split: cue("split")
			elif int(game.result.payouts.get(0, 0)) > int(game.result.contributions[0]): cue("win")
		elif game.actor == 0 and actor != 0: cue("turn", true)
		else: cue("chips")
	actor = game.actor

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		active = false
		if player != null: player.stop()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]: active = true
