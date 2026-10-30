extends VBoxContainer
signal changed
signal library_action(action: String, id: String, name: String)
signal picker_opened(value: bool)
const Services = preload("res://scripts/ai/services.gd")
const Vault = preload("res://scripts/ai/vault.gd")
var profiles: Array = []
var secrets: Dictionary = {}
var profile_id = "default"
var profile_picker: OptionButton
var profile_name: LineEdit
var remember: CheckButton
var delete_profile: Button
const UI = preload("res://scripts/ui/style.gd")
const Config = preload("res://scripts/ai/config.gd")
const Client = preload("res://scripts/ai/client.gd")
const Providers = preload("res://scripts/ai/providers.gd")
const Catalog = preload("res://scripts/ai/catalog.gd")
const Protocol = preload("res://scripts/ai/protocol.gd")
var usage_label: Label
var provider_picker: OptionButton
var provider_hint: Label
var filling = false
var last_origin = ""
var endpoint: LineEdit
var model: LineEdit
var key: LineEdit
var speech: CheckButton
var status: Label
var test_button: Button
var fetch_button: Button
var model_picker: Button
var model_sheet
var model_count: Label
var model_rows: VBoxContainer
var model_limit: int = 60
var model_search: LineEdit
var manual_button: Button
var library: VBoxContainer
var client
var models_client
var fetch_timer: Timer
var models: Array = []
var filtered: Array = []
var selected_api = "chat"

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_note("保存不同的模型档案，供每位对手和教练分别选择。地址与密钥填好后自动获取模型。")
	profile_picker = OptionButton.new()
	profile_picker.fit_to_longest_item = false
	profile_picker.custom_minimum_size.y = 52
	profile_picker.item_selected.connect(_switch_profile)
	add_child(profile_picker)
	profile_name = _field("模型档案名称", "例如：深海陪练 / 讲解教练")
	profile_name.max_length = 24
	profile_name.text_changed.connect(func(_v): changed.emit())
	var bank_row = HBoxContainer.new()
	add_child(bank_row)
	bank_row.add_child(UI.button("新增模型档案", _add_profile))
	delete_profile = UI.button("删除此档案", _delete_profile)
	bank_row.add_child(delete_profile)
	provider_picker = OptionButton.new()
	provider_picker.custom_minimum_size.y = 52
	provider_picker.fit_to_longest_item = false
	for preset in Providers.PRESETS: provider_picker.add_item(preset.label)
	add_child(provider_picker)
	provider_picker.item_selected.connect(_preset)
	provider_hint = UI.label("", 17, UI.MUTED)
	provider_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(provider_hint)
	endpoint = _field("接口地址", "https://你的服务/v1")
	key = _field("API 密钥", "粘贴密钥；免密服务可留空")
	key.secret = true
	remember = CheckButton.new()
	remember.text = "在本机安全记住密钥"
	remember.custom_minimum_size.y = 48
	remember.disabled = not Vault.available()
	remember.toggled.connect(func(_v): changed.emit())
	add_child(remember)
	endpoint.text_changed.connect(_credentials_changed)
	key.text_changed.connect(_credentials_changed)
	fetch_button = UI.button("获取模型", fetch_models, UI.GREEN)
	add_child(fetch_button)
	model_picker = UI.button("选择模型  ›", _open_models)
	model_picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(model_picker)
	_build_model_sheet()
	manual_button = UI.button("未找到模型？手动填写", func():
		model.visible = not model.visible
		if model.visible: model.grab_focus())
	add_child(manual_button)
	model = LineEdit.new()
	model.placeholder_text = "手动填写服务支持的模型 ID"
	model.max_length = 120
	model.custom_minimum_size.y = 52
	model.text_changed.connect(_manual_model)
	add_child(model)
	model.hide()
	test_button = UI.button("测试所选模型", _test)
	add_child(test_button)
	status = UI.label("填完后会自动获取；免密服务请点击“获取模型”。", 17, UI.GOLD)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	usage_label = UI.label("", 16, UI.MUTED)
	usage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(usage_label)
	add_child(UI.button("查看本次运行的用量", _usage))
	speech = CheckButton.new()
	speech.text = "允许 AI 桌边发言"
	speech.custom_minimum_size.y = 48
	speech.add_theme_font_size_override("font_size", 18)
	speech.toggled.connect(func(_v): changed.emit())
	add_child(speech)
	_note("获取列表不发送牌局。测试会调用所选模型；对局会发送该 AI 的底牌、公开行动和记忆。勾选记住后由系统加密保存；密钥不会进入牌局、备份或报告。关闭记住并保存会删除已保存的密钥。")
	client = Client.new()
	add_child(client)
	client.finished.connect(_tested)
	models_client = Client.new()
	add_child(models_client)
	models_client.finished.connect(_models_received)
	fetch_timer = Timer.new()
	fetch_timer.one_shot = true
	fetch_timer.wait_time = 1.2
	add_child(fetch_timer)
	fetch_timer.timeout.connect(func():
		if is_visible_in_tree(): fetch_models())
	visibility_changed.connect(func():
		if not is_visible_in_tree(): stop())
	add_child(UI.label("长期陪练", 24, UI.GOLD))
	_note("在“电脑对手”保存身份。以下档案操作立即生效，不受“取消设置”影响。")
	library = VBoxContainer.new()
	library.add_theme_constant_override("separation", 12)
	add_child(library)
	_render_models()

func _field(title: String, hint: String) -> LineEdit:
	add_child(UI.label(title, 18, UI.MUTED))
	var edit = LineEdit.new()
	edit.placeholder_text = hint
	edit.custom_minimum_size.y = 52
	edit.max_length = 512
	add_child(edit)
	return edit

func _note(text: String) -> void:
	var label = UI.label(text, 17, UI.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)

func fill(service: Dictionary, secret: String) -> void:
	stop()
	filling = true
	var p = Config.service(service)
	endpoint.text = p.endpoint
	model.text = p.model
	key.text = secret
	selected_api = p.api
	speech.set_pressed_no_signal(p.speech)
	provider_picker.select(Providers.identify(p.endpoint))
	provider_hint.text = Providers.PRESETS[provider_picker.selected].hint
	last_origin = Providers.origin(p.endpoint)
	models.clear()
	model_search.text = ""
	model.hide()
	filling = false
	_render_models()
	status.text = "已保留所选模型。可刷新列表或测试连接。" if not model.text.is_empty() else "填完后会自动获取；免密服务请点击“获取模型”。"

func values() -> Dictionary:
	# Preserve an explicitly pasted full route, including services with no /v1 prefix.
	return Config.service({"endpoint": endpoint.text, "model": model.text, "speech": speech.button_pressed, "api": selected_api})

func _preset(index: int) -> void:
	stop()
	provider_picker.select(index)
	var preset = Providers.PRESETS[index]
	provider_hint.text = preset.hint
	if index == 0: return
	filling = true
	if Providers.origin(endpoint.text) != Providers.origin(preset.endpoint): key.text = ""
	endpoint.text = preset.endpoint
	model.text = ""
	model.hide()
	selected_api = "chat"
	last_origin = Providers.origin(endpoint.text)
	models.clear()
	model_search.text = ""
	filling = false
	_render_models()
	status.text = "填入此服务的密钥后会自动获取模型。"
	remember.set_pressed_no_signal(false)
	changed.emit()
	_schedule_fetch()

func _credentials_changed(_value: String) -> void:
	if filling: return
	stop()
	var origin = Providers.origin(endpoint.text)
	if origin != last_origin:
		key.text = ""
		model.text = ""
		selected_api = "chat"
	last_origin = origin
	models.clear()
	model_search.text = ""
	provider_picker.select(Providers.identify(endpoint.text))
	provider_hint.text = Providers.PRESETS[provider_picker.selected].hint
	_render_models()
	status.text = "配置已修改，等待获取模型。"
	remember.set_pressed_no_signal(false)
	changed.emit()
	_schedule_fetch()

func _schedule_fetch() -> void:
	if not Config.base_endpoint(endpoint.text).has("error") and not key.text.strip_edges().is_empty() and is_visible_in_tree(): fetch_timer.start()

func fetch_models() -> void:
	if models_client.busy:
		stop()
		status.text = "已取消获取，当前选择保留。"
		return
	stop()
	fetch_button.text = "取消获取"
	status.text = "正在获取模型…"
	models_client.list_models(values(), key.text)

func _models_received(result: Dictionary) -> void:
	fetch_button.text = "刷新模型"
	if result.has("error"):
		status.text = result.error
		if result.get("status", 0) not in [401, 403, 429] and not Config.base_endpoint(endpoint.text).has("error"):
			status.text += "；服务不提供列表时可手动填写模型。"
			model.show()
		return
	models = result.models
	var chosen = Catalog.initial(models, model.text, endpoint.text)
	if chosen >= 0:
		model.text = models[chosen].id
		selected_api = models[chosen].api
	else:
		model.show()
	_render_models()
	status.text = "已获取 %d 个可选模型。可以直接保存，或先测试所选模型。" % models.size() if chosen >= 0 else "没有找到适用的对话模型，可手动填写模型 ID。"
	if result.get("skipped", 0) > 0: status.text += "\n已隐藏 %d 个不适用的模型。" % result.skipped
	changed.emit()

func _render_models() -> void:
	if model_picker == null or model == null: return
	filtered.clear()
	var query = model_search.text.strip_edges().to_lower()
	for item in models:
		if query.is_empty() or query in (item.id + " " + item.name).to_lower(): filtered.append(item)
	model_picker.text = (model.text if not model.text.is_empty() else "等待获取模型" if models.is_empty() else "选择模型") + "  ›"
	model_picker.disabled = models.is_empty()
	model_picker.tooltip_text = model.text
	test_button.visible = not model.text.is_empty()
	if model_sheet.visible: _render_model_rows()

func _build_model_sheet() -> void:
	model_sheet = preload("res://scripts/ui/sheet.gd").new()
	model_sheet.touch_scroll = true
	model_sheet.preferred_height = 900
	# Outside the settings scroller: only the model list owns a drag gesture.
	var owner_control: Node = self
	while not owner_control.has_method("back_action"): owner_control = owner_control.get_parent()
	owner_control.add_child(model_sheet)
	model_sheet.z_index = 5
	model_sheet.closed.connect(func():
		picker_opened.emit(false)
		model_picker.grab_focus())
	model_search = LineEdit.new()
	model_search.placeholder_text = "搜索名称或模型 ID"
	model_search.custom_minimum_size.y = 50
	model_search.text_changed.connect(func(_v):
		model_limit = 60
		model_sheet.scroll.reset_scroll()
		_render_models())
	var column = model_sheet.panel.get_child(0)
	column.add_child(model_search)
	column.move_child(model_search, 1)
	model_count = UI.label("", 16, UI.MUTED)
	column.add_child(model_count)
	column.move_child(model_count, 2)
	model_rows = VBoxContainer.new()
	model_rows.add_theme_constant_override("separation", 10)
	model_sheet.content.add_child(model_rows)

func _open_models() -> void:
	if models.is_empty(): return
	model_limit = 60
	model_search.text = ""
	model_sheet.open("选择模型")
	picker_opened.emit(true)
	_render_models()

func _render_model_rows() -> void:
	UI.clear(model_rows)
	model_count.text = "%d 个结果 · 上下滑动浏览，点选后返回" % filtered.size()
	for i in range(mini(model_limit, filtered.size())):
		var item = filtered[i]
		var text = ("✓  " if item.id == model.text else "") + (item.name if item.name != "" else item.id)
		if item.name != "" and item.name != item.id: text += "\n" + item.id
		var button = UI.button(text, func():
			if model_sheet.scroll.can_activate():
				_choose_model(i)
				model_sheet.close(), UI.GREEN if item.id == model.text else Color("20313d"), 68)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 18)
		model_rows.add_child(button)
	if filtered.is_empty(): model_rows.add_child(UI.label("没有匹配的模型，换个关键词试试。", 18, UI.MUTED))
	if filtered.size() > model_limit:
		model_rows.add_child(UI.button("继续显示更多模型", func():
			if model_sheet.scroll.can_activate():
				model_limit += 60
				_render_model_rows()))

func _choose_model(index: int) -> void:
	if index >= filtered.size(): return
	client.cancel()
	model.text = filtered[index].id
	selected_api = filtered[index].api
	test_button.disabled = false
	test_button.show()
	status.text = "已选择 " + model.text + "，保存后生效。"
	model_picker.text = model.text + "  ›"
	changed.emit()

func _manual_model(_value: String) -> void:
	client.cancel()
	selected_api = "chat"
	for item in models:
		if item.id == model.text: selected_api = item.api
	test_button.disabled = false
	_render_models()
	status.text = "已修改模型，可测试后保存。"
	changed.emit()

func _test() -> void:
	stop()
	status.text = "正在测试所选模型…"
	test_button.disabled = true
	client.send(values(), key.text, [{"role": "system", "content": "Return only a JSON object: {\"ok\":true}"}, {"role": "user", "content": "Connection test, no game data."}])

func _tested(result: Dictionary) -> void:
	test_button.disabled = false
	if result.has("error"):
		status.text = result.error
		return
	var parsed = Protocol.object(result.content)
	status.text = "连接成功，模型可用。保存后到“电脑对手”启用。" if not parsed.has("error") and parsed.value.get("ok") == true else "服务已响应，但未通过回复检查；请重试或选择其他模型。"

func stop(close_picker: bool = true) -> void:
	if close_picker and model_sheet != null and model_sheet.visible: model_sheet.close()
	if fetch_timer != null: fetch_timer.stop()
	var working = (client != null and client.busy) or (models_client != null and models_client.busy)
	if client != null: client.cancel()
	if models_client != null: models_client.cancel()
	if test_button != null: test_button.disabled = false
	if fetch_button != null: fetch_button.text = "刷新模型" if not models.is_empty() else "获取模型"
	if working and status != null: status.text = "已取消连接，当前选择保留。"

func fill_library(companions: Dictionary) -> void:
	for child in library.get_children():
		library.remove_child(child)
		child.queue_free()
	if companions.is_empty():
		library.add_child(UI.label("尚未保存陪练", 18, UI.MUTED))
	for id in companions:
		var p = companions[id]
		var box = VBoxContainer.new()
		library.add_child(box)
		var name_edit = LineEdit.new()
		name_edit.text = p.name
		name_edit.max_length = 12
		name_edit.custom_minimum_size.y = 48
		box.add_child(name_edit)
		box.add_child(UI.label("记忆：%d 手 · 最近保留 8 手摘要" % p.memory.hands, 16, UI.MUTED))
		var row = HBoxContainer.new()
		box.add_child(row)
		for pair in [["重命名", "rename"], ["清空记忆", "clear"], ["删除", "delete"]]:
			var button = UI.button(pair[0], func(): library_action.emit(pair[1], id, name_edit.text))
			button.add_theme_font_size_override("font_size", 17)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(button)


func fill_bank(raw: Variant, keys: Dictionary, legacy: Dictionary, secret: String) -> void:
	profiles = Services.normalize(raw, legacy)
	secrets = keys.duplicate()
	if not secrets.has("default"): secrets["default"] = secret
	profile_id = "default"
	_load_profile()

func _store_profile() -> void:
	var p = Services.find(profiles, profile_id)
	if p.is_empty(): return
	p.service = values()
	p.label = Config.clean(profile_name.text, 24)
	p.remember = remember.button_pressed
	secrets[profile_id] = key.text.strip_edges()

func profile_values() -> Array:
	_store_profile()
	return Services.normalize(profiles, values())

func key_values() -> Dictionary:
	_store_profile()
	return secrets.duplicate()

func _load_profile() -> void:
	var p = Services.find(profiles, profile_id)
	fill(p.service, str(secrets.get(profile_id, "")))
	profile_name.text = p.label
	remember.set_pressed_no_signal(p.remember)
	profile_picker.clear()
	for item in profiles: profile_picker.add_item(item.label if not item.label.is_empty() else "未命名模型")
	profile_picker.select(profiles.find(p))
	delete_profile.disabled = profile_id == "default"

func _switch_profile(index: int) -> void:
	_store_profile()
	profile_id = profiles[index].id
	_load_profile()
	changed.emit()

func _add_profile() -> void:
	_store_profile()
	if profiles.size() >= 16:
		status.text = "最多保存 16 个模型档案。"
		return
	# Duplicating the current endpoint/key makes choosing a second model easy.
	var old = profile_id
	profile_id = "model-" + str(Time.get_ticks_usec())
	profiles.append({"id": profile_id, "label": "新模型档案", "service": values(), "remember": false})
	secrets[profile_id] = secrets.get(old, "")
	_load_profile()
	changed.emit()

func _delete_profile() -> void:
	if profile_id == "default": return
	profiles = profiles.filter(func(p): return p.id != profile_id)
	secrets.erase(profile_id)
	profile_id = "default"
	_load_profile()
	status.text = "保存设置后删除；使用此档案的对手需要重新选择。"
	changed.emit()

func _usage() -> void:
	var lines: Array = []
	for id in Client.usage:
		var u = Client.usage[id]
		lines.append("%s\nHTTP 请求 %d · 完成任务 %d · 失败任务 %d\n平均 %.2f 秒 · 已报告 %d tokens（%d 次返回用量，含重试）" % [str(id).get_slice(" | ", 1), u.requests, u.completed, u.errors, u.milliseconds / 1000.0 / maxi(1, u.completed), u.tokens, u.usage_reports])
	usage_label.text = "\n\n".join(lines) + "\n未返回用量的部分未知，具体费用以服务商账单为准。" if not lines.is_empty() else "本次运行尚无模型请求。"
