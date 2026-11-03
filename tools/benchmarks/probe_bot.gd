extends "res://scripts/poker/local_bot.gd"
## Leak probe: the shipped bot with ONE fixed deviation. Measured against the
## unmodified bot on the same decks, the difference shows whether opponents
## punish (negative) or pay off (positive) that pattern. Not a playing style.

const MODES = ["baseline", "threebet", "barrel", "station", "overfold", "minraise", "jam"]
static var mode: String = "baseline"

func choose(view: Dictionary) -> Dictionary:
	var legal: Dictionary = view.legal
	if legal.is_empty(): return {}
	var preflop = view.board.is_empty()
	var facing = legal.call_amount > 0
	match mode:
		"threebet":
			# Re-raise any two cards against a single open.
			if preflop and legal.raise and _raises(view) == 1:
				return _raise(Sizing.clamp_target(view.current_bet * 3, legal))
		"barrel":
			# Bet two-thirds pot on every street whenever checked to.
			if not preflop and not facing and legal.raise:
				return _raise(Sizing.from_pot(0.66, view))
		"station":
			# Never fold and never raise after the flop.
			if not preflop:
				return {"action": "call"} if facing else {"action": "check"}
		"overfold":
			# Fold to any postflop bet.
			if not preflop and facing: return {"action": "fold"}
		"minraise":
			# Min-raise every postflop bet.
			if not preflop and facing and legal.raise and legal.min_raise_to <= legal.max_raise_to:
				return _raise(legal.min_raise_to)
		"jam":
			# Open-shove the top 40% of starting hands when first in.
			if preflop and _raises(view) == 0 and legal.raise and Ranges.preflop_strength(view.seats[view.actor].hole) >= 0.45:
				return _raise(legal.max_raise_to)
	return super.choose(view)

static func _raises(view: Dictionary) -> int:
	var count = 0
	for a in view.events:
		if a.get("kind") == "street": break
		if a.get("kind") == "action" and a.action == "raise": count += 1
	return count
