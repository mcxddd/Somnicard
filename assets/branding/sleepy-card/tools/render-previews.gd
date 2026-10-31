extends SceneTree

func _init():
    var args = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Provide the absolute branding directory")
        quit(1)
        return
    var root = args[0]
    var destination = root.path_join("previews")
    DirAccess.make_dir_recursive_absolute(destination)
    for stem in ["logo-mark", "wordmark", "favicon"]:
        var image = Image.new()
        var result = image.load_svg_from_string(FileAccess.get_file_as_string(root.path_join(stem + ".svg")))
        if result != OK:
            push_error("Cannot render preview: " + stem)
            quit(1)
            return
        result = image.save_png(destination.path_join(stem + ".png"))
        if result != OK:
            push_error("Cannot save preview: " + stem)
            quit(1)
            return
    quit(0)
