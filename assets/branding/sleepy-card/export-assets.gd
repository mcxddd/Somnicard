extends SceneTree
func _init():
    var args = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Usage: godot --headless --script export-assets.gd -- OUTPUT_DIR")
        quit(1)
        return
    var root = args[0]
    for stem in ["icon-1024", "adaptive-foreground", "adaptive-background", "adaptive-monochrome", "splash"]:
        var source = root.path_join("sources/" + stem + ".svg")
        var image = Image.new()
        var result = image.load_svg_from_string(FileAccess.get_file_as_string(source))
        if result != OK:
            push_error("SVG render failed: " + source)
            quit(1)
            return
        result = image.save_png(root.path_join(stem + ".png"))
        if result != OK:
            push_error("PNG save failed: " + stem)
            quit(1)
            return
    quit(0)
