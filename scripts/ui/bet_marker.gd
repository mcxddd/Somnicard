extends "res://scripts/ui/money_display.gd"
## Street contribution; the decorative chip count does not encode denominations.
func _ready() -> void:
	super()
	custom_minimum_size.x = 104
	configure("wager", 19)

func update_amount(chips: int, big_blind: int, bb: bool) -> void:
	set_amount(chips, big_blind, bb)
