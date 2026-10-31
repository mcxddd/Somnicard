# Somnicard sleepy-card logo assets

Measured vector redraw of Somnicard-sleepy-card-refined.png. Card silhouette, spade and both eyelids follow the large reference mark; the wordmark letters are traced outlines, not a substituted font. Raster edge antialiasing and generated-image texture are intentionally replaced with clean curves and exact colors. This is a close vector reconstruction, not the unavailable original vector master.

Colors: midnight #07111B, ivory #F5EEDF, green #227865.

Eight deliverables: logo-mark.svg, wordmark.svg, icon-1024.png, adaptive-foreground.png, adaptive-background.png, adaptive-monochrome.png, splash.png, favicon.svg.

All SVGs contain only geometry, no embedded raster images or external fonts. sources/ contains the exact SVG sources for the PNG files. Run build_assets.py to regenerate SVGs, then export-assets.gd using Godot to regenerate PNGs. An Inkscape export option is also supported by build_assets.py --inkscape.

Adaptive foreground and monochrome are centered at (216,216) and fitted within radius 130px, leaving 2px antialiasing tolerance inside the required 132px radius. Monochrome uses even-odd path holes for eyes and spade. Favicon thickens the eye and spade shapes only for 32px clarity. Icon rounded corners are transparent outside the green rounded square. No game configuration was changed.

## 接入位置

品牌源目录通过空的 `.gdignore` 排除 Godot 导入和游戏打包，保留源 SVG、脚本、预览与说明；运行时文件从此目录复制，只有 192 像素安卓图标需要缩放。

- `icon-1024.png` → `assets/icon.png`（`project.godot` 的 `config/icon`），并使用 Pillow LANCZOS 缩放到 `assets/android/icon-192.png`。
- `splash.png` → `assets/boot.png`（512×512 启动画面）；`project.godot` 的启动背景为 #07111B。
- `adaptive-foreground.png`、`adaptive-background.png`、`adaptive-monochrome.png` → `assets/android/` 下同名文件。
- `export_presets.cfg` 的 `launcher_icons/main_192x192`、`launcher_icons/adaptive_foreground_432x432`、`launcher_icons/adaptive_background_432x432`、`launcher_icons/adaptive_monochrome_432x432` 分别使用上述四个安卓图标文件。
- `logo-mark.svg`、`wordmark.svg` → `assets/` 下同名文件，由 `scripts/ui/home.gd` 和 `scripts/ui/table_screen.gd` 加载；牌桌中央文字水印保持原样。
- `logo-mark.svg`、`favicon.svg` → `site/images/` 下同名文件，供 `site/index.html` 导航和浏览器图标使用；`site/style.css` 设置导航图标尺寸。`tools/prepare-site.py` 会复制整个 `site/images/`，无需额外列出新文件。
