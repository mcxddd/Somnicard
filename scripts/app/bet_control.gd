extends Node
## The raise target the player is editing; it is only submitted by the raise button.
## Depends on host: game, prefs, screen, _money.
const Sizing = preload("res://scripts/ui/bet_sizing.gd")
var host
var selected_raise: int = 20
var decision_key: String = ""

func sync(view: Dictionary) -> void:
	var legal = view.legal
	var key = "%d:%s:%d:%d" % [view.hand, view.phase, view.current_bet, view.seats[0].stack]
	if key != decision_key:
		selected_raise = Sizing.clamp_target(legal.min_raise_to, legal)
		decision_key = key
	sync_amount()

func quick_bb(bb_amount: float) -> void:
	var game = host.game
	if game == null or game.actor != 0: return
	var requested = roundi(bb_amount * game.big_blind)
	set_target(Sizing.from_bb(bb_amount, game.big_blind, game.legal_actions(0)))
	if selected_raise != requested: host.screen.amount_note.text += " · 已调整至合法范围"

func quick_minimum() -> void:
	var game = host.game
	if game != null and game.actor == 0:
		set_target(game.legal_actions(0).min_raise_to)

func adjust_bb(delta: int) -> void:
	if host.game != null: set_target(selected_raise + delta * host.game.big_blind)

func quick_pot(fraction: float) -> void:
	var game = host.game
	if game == null or game.actor != 0: return
	var view = game.view_for(0)
	var requested = view.current_bet + roundi((view.pot + view.legal.to_call) * fraction)
	set_target(Sizing.from_pot(fraction, view))
	if selected_raise != requested: host.screen.amount_note.text += " · 已调整至合法范围"

func set_target(requested: int) -> void:
	var game = host.game
	if game == null or game.actor != 0: return
	var target = Sizing.clamp_target(requested, game.legal_actions(0))
	if target == 0: return
	selected_raise = target
	sync_amount()
	if requested != target: host.screen.amount_note.text += " · 已调整至合法范围"

func amount_changed(value: float) -> void:
	var game = host.game
	if game == null or game.actor != 0: return
	set_target(roundi(value * (game.big_blind if host.prefs.use_bb else 1)))

func sync_amount() -> void:
	var game = host.game
	var screen = host.screen
	var use_bb: bool = host.prefs.use_bb
	var legal = game.legal_actions(0)
	if legal.is_empty(): return
	var factor = float(game.big_blind if use_bb else 1)
	screen.amount_input.set_block_signals(true)
	screen.amount_input.step = 1.0 / factor
	screen.amount_input.suffix = "BB" if use_bb else ""
	# Phones open a digit pad; BB amounts also need a decimal point.
	screen.amount_input.get_line_edit().virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL if use_bb else LineEdit.KEYBOARD_TYPE_NUMBER
	screen.amount_input.min_value = mini(legal.min_raise_to, legal.max_raise_to) / factor
	screen.amount_input.max_value = legal.max_raise_to / factor
	screen.amount_input.value = selected_raise / factor
	# SpinBox defers its text refresh. Keep the editor synchronized immediately so
	# apply() during a rapid unit switch cannot reparse the previous displayed value.
	screen.amount_input.get_line_edit().text = ("%.1f BB" % (selected_raise / factor)) if use_bb else str(selected_raise)
	screen.amount_input.set_block_signals(false)
	screen.amount_slider.set_block_signals(true)
	screen.amount_slider.min_value = mini(legal.min_raise_to, legal.max_raise_to)
	screen.amount_slider.max_value = legal.max_raise_to
	screen.amount_slider.step = 1
	screen.amount_slider.value = selected_raise
	screen.amount_slider.set_block_signals(false)
	screen.raise_button.text = ("下注 " if game.current_bet == 0 else "加注到 ") + host._money(selected_raise)
	screen.amount_note.text = "本次再投入 " + host._money(maxi(0, selected_raise - game.seats[0].street_bet))
	# After the flop, sizes are thought of as a share of the pot (counted after calling).
	var view = game.view_for(0)
	var base = view.pot + legal.get("to_call", 0)
	if not view.board.is_empty() and base > 0:
		screen.amount_note.text += " · 约底池的 %d%%" % roundi(100.0 * (selected_raise - view.current_bet) / base)
	if not legal.raise:
		screen.amount_note.text = "当前不可加注；请跟注、过牌或弃牌。"
		screen.raise_button.text = "不可加注"
	elif legal.max_raise_to < legal.min_raise_to: screen.amount_note.text = "筹码不足最小加注，仅可全押到 " + host._money(legal.max_raise_to)
