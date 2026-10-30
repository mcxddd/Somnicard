extends SceneTree
## Format conversion of the project's original vector icon for Godot's PNG-only splash.
func _initialize() -> void:
	var icon = Image.new()
	var error = icon.load_svg_from_string(FileAccess.get_file_as_string("res://assets/icon.svg"))
	if error != OK:
		printerr("BOOT_ICON_CONVERSION_FAILED")
		quit(1)
		return
	error = icon.save_png("res://assets/boot.png")
	print("BOOT_ICON_READY" if error == OK else "BOOT_ICON_SAVE_FAILED")
	quit(0 if error == OK else 1)
