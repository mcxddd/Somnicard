extends RefCounted
## Pure conversion helpers. All targets are STREET TOTALS in integer chips.

static func clamp_target(target: int, legal: Dictionary) -> int:
	if legal.is_empty() or not legal.get("raise", false): return 0
	return clampi(target, mini(legal.min_raise_to, legal.max_raise_to), legal.max_raise_to)

static func from_bb(bb_amount: float, bb: int, legal: Dictionary) -> int:
	return clamp_target(roundi(bb_amount * bb), legal)

static func from_pot(fraction: float, view: Dictionary) -> int:
	# A raise is sized against the pot AFTER a hypothetical call, then added to the
	# current bet. E.g. pot 100, facing 20: half pot raise-to = 20 + .5 * 120 = 80.
	var legal = view.legal
	if legal.is_empty(): return 0
	return clamp_target(view.current_bet + roundi((view.pot + legal.to_call) * fraction), legal)
