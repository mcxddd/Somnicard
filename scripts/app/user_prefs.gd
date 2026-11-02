extends RefCounted
var sound_level = 1
var haptics_enabled = false
var performance_mode = 0
var use_bb: bool = true
var speed_index: int = 1
var fast_fold_enabled: bool = true
var show_sidebar: bool = true
var felt_theme: int = 0
var four_color: bool = false
var motion: bool = true
var confirm_all_in: bool = true
var live_teaching: bool = true
var review_teaching: bool = true
var coach_after: bool = false
var coach_auto: bool = false
var coach_detail: int = 0
var coach_side: int = 1
## 0 small, 1 standard, 2 large: scales the whole interface, text and controls together.
var text_size: int = 1

func load(p: Dictionary) -> void:
	sound_level = p.sound
	haptics_enabled = p.haptics
	performance_mode = p.performance
	use_bb = p.bb
	speed_index = p.speed
	fast_fold_enabled = p.fast_fold
	show_sidebar = p.sidebar
	felt_theme = p.felt
	four_color = p.four_color
	motion = p.motion
	confirm_all_in = p.confirm_all_in
	live_teaching = p.live_teaching
	review_teaching = p.review_teaching
	coach_after = p.coach_after
	coach_auto = p.coach_auto
	coach_detail = p.coach_detail
	coach_side = p.coach_side
	text_size = p.get("text_size", 1)

func assign(values: Dictionary) -> void:
	sound_level = int(values.get("sound", 1))
	haptics_enabled = bool(values.get("haptics", false))
	performance_mode = int(values.get("performance", 0))
	use_bb = values.bb
	speed_index = values.speed
	fast_fold_enabled = values.fast_fold
	show_sidebar = values.sidebar
	felt_theme = values.felt
	four_color = values.four_color
	motion = values.motion
	confirm_all_in = values.confirm_all_in
	live_teaching = values.get("live_teaching", true)
	review_teaching = values.get("review_teaching", true)
	coach_after = values.get("coach_after", false)
	coach_auto = values.get("coach_auto", false)
	coach_detail = values.get("coach_detail", 0)
	coach_side = values.get("coach_side", 1)
	text_size = values.get("text_size", 1)

func values() -> Dictionary:
	return {"sound": sound_level, "haptics": haptics_enabled, "performance": performance_mode, "bb": use_bb, "speed": speed_index, "fast_fold": fast_fold_enabled, "sidebar": show_sidebar,
		"felt": felt_theme, "four_color": four_color, "motion": motion, "confirm_all_in": confirm_all_in,
		"live_teaching": live_teaching, "review_teaching": review_teaching,
		"coach_after": coach_after, "coach_auto": coach_auto, "coach_detail": coach_detail, "coach_side": coach_side, "text_size": text_size}
