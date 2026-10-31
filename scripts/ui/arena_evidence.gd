extends VBoxContainer
const UI = preload("res://scripts/ui/style.gd")
var published: Label

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_note("本地电脑三档在固定牌序下的实测结果，仅供了解档位差异，不换算真人段位。")
	add_child(UI.button("查看本版已完成的本地实测", func(): published.visible = not published.visible, UI.GREEN))
	published = UI.label(_published_summary(), 17, UI.TEXT)
	published.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(published)
	published.hide()

func _note(text: String, font_size: int = 18) -> void:
	var label = UI.label(text, font_size, UI.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)

func _published_summary() -> String:
	var path = "res://data/arena-evidence-1.11.0.json"
	if not FileAccess.file_exists(path): return "评测数据缺失"
	var evidence = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not evidence is Dictionary: return "评测数据缺失"
	var lines: Array = ["%s · 已完成 %s 手\n三档均衡：各桌型/深度 128 个独立牌序块；两种偏向风格：9 人 / 100 BB，各 32 块。" % [str(evidence.version), int(evidence.hands)], "\n均衡风格净收益 BB/100（括号为 95% 区间）："]
	for level_id in range(3):
		lines.append("\n" + ["入门", "标准", "进阶"][level_id])
		var r: Dictionary = evidence.reports["level%d-style0" % level_id]
		for depth in [50, 100, 200]:
			for count in [2, 6, 9]:
				var group = "%d人/%dBB" % [count, depth]
				var g: Dictionary = r.groups[group]
				lines.append("%s：%+.1f [%+.1f, %+.1f]" % [group, g.bb100, g.low, g.high])
	lines.append("\n风格实测（9 人 / 100 BB · VPIP / PFR）：")
	for level_id in range(3):
		for style_id in range(3):
			var b: Dictionary = evidence.reports["level%d-style%d" % [level_id, style_id]].groups["9人/100BB"].behavior
			lines.append("%s · %s：%.1f%% / %.1f%%" % [["入门", "标准", "进阶"][level_id], ["均衡", "偏被动", "偏激进"][style_id], 100.0 * int(b.vpip) / int(b.hands), 100.0 * int(b.pfr) / int(b.hands)])
	lines.append("\n进阶相对标准的配对区间在本次多数场景包含零，尚不能认定普遍更强。档位表示决策逻辑，不是已验证的真人段位。范围、牌序和标准对手都会影响结果；风格样本更少。")
	return "\n".join(lines)
