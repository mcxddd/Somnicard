# Local export and verification

Run from PowerShell:

```powershell
& 'C:\Users\macxd\Documents\Proj\Somnicard\assets\branding\sleepy-card\export.ps1'
python 'C:\Users\macxd\Documents\Proj\Somnicard\assets\branding\sleepy-card\verify_assets.py'
```

`export.ps1` regenerates the SVG files from the supplied measured geometry and
exports the five PNG assets through Godot's SVG renderer. It also renders the
three standalone SVGs into `previews/` for inspection. The helper project lives
under `tools/`; the main game's `project.godot` is not used or changed.

Defaults: Python 3.12.10, Godot 4.7.2. Override Godot with `-GodotExe` or the
`SOMNICARD_GODOT` environment variable. Source writing uses Python's standard
library only. Verification and the overview sheet use Pillow and NumPy.

`verify_assets.py` writes `validation.json` and `previews/overview.png`. It checks
the eight requested deliverables, SVG geometry without fonts or raster links,
PNG dimensions and RGBA mode, palette, transparency, adaptive safe bounds, and
three actual alpha holes in the monochrome image. Favicon is rendered at its
native 32px size; the overview includes both native and pixel-enlarged views.

Local result: PASS. Adaptive nontransparent pixel centers reach radius
130.523944px from (216,216); even their outer corners stay within 131.183079px,
under the required 132px. Monochrome has exactly three enclosed transparent
regions (spade and two eyes), with every nontransparent RGB pixel pure white.
Adaptive background is exactly RGBA (34,120,101,255) throughout.

The geometry was measured and traced from the approved reference in the parent
task, then transferred here as vector source. This Windows environment validated
the resulting files and renderings. It did not obtain a local copy of the raster
reference because the official Library transfer helper does not support Windows
extended attributes. The deliverables are a high-fidelity vector reconstruction,
not the unavailable original vector master; generated texture was removed and
the favicon alone uses heavier strokes for small-size clarity.
