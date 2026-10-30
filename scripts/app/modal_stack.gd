extends Node
var host
var layers = []
var background_focus: Dictionary = {}
var last_system_back_ms: int = -1000

func setup(main):
	host = main
	layers = [
		{"node": func(): return host.confirmation, "back": func(): host.confirmation.cancel(), "focus": func(): return host.confirmation.cancel_button},
		{"node": func(): return host.learning_center, "back": func(): host.learning_center.back_action(), "focus": func(): return host.learning_center.back_button},
		{"node": func(): return host.support_center, "back": func(): host.support_center.back_action(), "focus": func(): return host.support_center.back_button},
		{"node": func(): return host.settings, "back": func(): host.settings.back_action(), "focus": func(): return host.settings.cancel_button},
		{"node": func(): return host.training, "back": func(): host.training.back_action(), "focus": func(): return host.training.close_button},
		{"node": func(): return host.review, "back": func(): host.review.back_action(), "focus": func(): return host.review.close_button},
		{"node": func(): return host.screen.info_sheet, "back": func(): host.screen.info_sheet.close(), "focus": func(): return host.screen.info_sheet.close_button},
		{"node": func(): return host.screen.menu_sheet, "back": func(): host.screen.menu_sheet.close(), "focus": func(): return host.screen.menu_sheet.close_button},
		{"node": func(): return host.screen.bet_sheet, "back": func(): host.screen.bet_sheet.close(), "focus": func(): return host.screen.bet_sheet.close_button},
		{"node": func(): return host.screen.lobby, "back": func(): host._close_lobby(), "focus": func(): return host.screen.start_button},
		{"node": func(): return host.home, "back": func(): host._request_confirmation("退出 Somnicard？", "当前牌桌与已完成的记录会保留在本机。", "退出", func(): host._save_session(); host.get_tree().quit()), "focus": func(): return host.home.primary}
	]

func top() -> Control:
	for layer in layers:
		var node = layer.node.call()
		if node != null and node.visible: return node
	return null

func is_open() -> bool:
	return top() != null

func back() -> void:
	for layer in layers:
		var node = layer.node.call()
		if node == host.screen.lobby and host.coach.expanded:
			host.coach.collapse()
			return
		if node != null and node.visible:
			layer.back.call()
			return
	host._open_home()

func sync_focus() -> void:
	restore_background()
	if is_open():
		block_background(host)
		for layer in layers:
			var node = layer.node.call()
			if node != null and node.visible:
				layer.focus.call().grab_focus()
				return

func block_background(node: Node) -> void:
	# A mouse-blocking overlay alone does not trap Tab navigation. Keep background
	# controls out of the keyboard focus chain until this modal is dismissed.
	if node == top(): return
	if node is Control and not background_focus.has(node):
		background_focus[node] = node.focus_mode
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children(): block_background(child)

func restore_background() -> void:
	for node in background_focus:
		if is_instance_valid(node): node.focus_mode = background_focus[node]
	background_focus.clear()

func system_back(now_ms: int = -1) -> void:
	# Notification may arrive before or after the BACK key event on Android 16.
	# Deduplicate notifications themselves instead of depending on key ordering.
	var now = Time.get_ticks_msec() if now_ms < 0 else now_ms
	if now - last_system_back_ms < 350: return
	last_system_back_ms = now
	back()
