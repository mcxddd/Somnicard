extends RefCounted
## Only ciphertext reaches disk; Windows helper receives input through a pipe, not argv.
const Services = preload("res://scripts/ai/services.gd")
const PATH = "user://ai/credentials.bin"

static func available() -> bool:
	return Engine.has_singleton("SomnicardVault") or OS.get_name() == "Windows"

static func _windows(data: PackedByteArray, encrypt: bool) -> Dictionary:
	var operation = "Protect" if encrypt else "Unprotect"
	var script = "try { Add-Type -AssemblyName System.Security; $b=[Convert]::FromBase64String([Console]::ReadLine()); $e=[Text.Encoding]::UTF8.GetBytes('Somnicard-v1'); $r=[Security.Cryptography.ProtectedData]::%s($b,$e,[Security.Cryptography.DataProtectionScope]::CurrentUser); [Console]::WriteLine([Convert]::ToBase64String($r)) } catch { [Console]::WriteLine('ERROR') }" % operation
	var process = OS.execute_with_pipe("powershell.exe", ["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-EncodedCommand", Marshalls.raw_to_base64(script.to_utf16_buffer())], false)
	if process.is_empty(): return {"error": "无法启动系统密钥保护"}
	process.stdio.store_line(Marshalls.raw_to_base64(data))
	process.stdio.flush()
	var response = PackedByteArray()
	var deadline = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		var part: PackedByteArray = process.stdio.get_buffer(65536)
		response.append_array(part)
		if 10 in response: break
		if not OS.is_process_running(process.pid): break
		OS.delay_msec(10)
	process.stdio.close()
	process.stderr.close()
	if OS.is_process_running(process.pid): OS.kill(process.pid)
	var text = response.get_string_from_utf8().strip_edges()
	if text.is_empty() or text == "ERROR": return {"error": "系统密钥保护失败，请重新输入密钥"}
	return {"data": Marshalls.base64_to_raw(text)}

static func save(profiles: Array, secrets: Dictionary, path: String = PATH) -> String:
	var payload: Dictionary = {}
	for p in profiles:
		if p.remember and not str(secrets.get(p.id, "")).is_empty():
			payload[p.id] = {"binding": Services.binding(p.service), "key": str(secrets[p.id])}
	if payload.is_empty():
		if Engine.has_singleton("SomnicardVault"):
			return "" if Engine.get_singleton("SomnicardVault").clear() else "系统密钥删除失败"
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK: return "密钥删除失败"
		return ""
	if Engine.has_singleton("SomnicardVault"):
		return "" if Engine.get_singleton("SomnicardVault").save(JSON.stringify(payload)) else "系统加密保存失败，设置未应用"
	if OS.get_name() != "Windows": return "当前平台不支持安全保存，请关闭记住密钥"
	var encrypted = _windows(JSON.stringify(payload).to_utf8_buffer(), true)
	if encrypted.has("error"): return encrypted.error
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return "无法写入加密密钥"
	file.store_buffer(encrypted.data)
	file.close()
	return "" if DirAccess.rename_absolute(path + ".tmp", path) == OK else "加密密钥保存失败"

static func load_keys(profiles: Array, path: String = PATH) -> Dictionary:
	var text = ""
	if Engine.has_singleton("SomnicardVault"):
		text = Engine.get_singleton("SomnicardVault").load()
	elif OS.get_name() == "Windows" and FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 131072: return {}
		var decrypted = _windows(file.get_buffer(file.get_length()), false)
		if decrypted.has("error"): return {}
		text = decrypted.data.get_string_from_utf8()
	if text.is_empty(): return {}
	var parser = JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary: return {}
	var out: Dictionary = {}
	for p in profiles:
		var entry = parser.data.get(p.id, {})
		if p.remember and entry is Dictionary and entry.get("binding") == Services.binding(p.service) and entry.get("key") is String:
			out[p.id] = entry.key
	return out
