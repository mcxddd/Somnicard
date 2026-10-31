"""Validate exported assets and create a review sheet. Requires Pillow and NumPy."""
from collections import deque
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
DARK = (7, 17, 27)
GREEN = (34, 120, 101)
IVORY = (245, 238, 223)
PNG_SIZES = {
    "icon-1024.png": (1024, 1024),
    "adaptive-foreground.png": (432, 432),
    "adaptive-background.png": (432, 432),
    "adaptive-monochrome.png": (432, 432),
    "splash.png": (512, 512),
}
SVG_SIZES = {"logo-mark.svg": (512, 512), "wordmark.svg": (650, 74), "favicon.svg": (32, 32)}


def closed_holes(alpha):
    transparent = alpha == 0
    visited = np.zeros(transparent.shape, dtype=bool)
    h, w = transparent.shape
    holes = []
    for sy, sx in np.argwhere(transparent):
        if visited[sy, sx]:
            continue
        queue = deque([(int(sy), int(sx))])
        visited[sy, sx] = True
        coords = []
        exterior = False
        while queue:
            y, x = queue.popleft()
            coords.append((x, y))
            exterior |= x == 0 or y == 0 or x == w - 1 or y == h - 1
            for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= yy < h and 0 <= xx < w and transparent[yy, xx] and not visited[yy, xx]:
                    visited[yy, xx] = True
                    queue.append((yy, xx))
        if not exterior:
            points = np.array(coords)
            holes.append({"pixels": len(coords), "bbox": [*points.min(axis=0).tolist(), *points.max(axis=0).tolist()]})
    return sorted(holes, key=lambda item: item["bbox"][1])


def main():
    report = {"status": "PASS", "pngs": {}, "svgs": {}, "checks": {}}
    images = {}
    for name, size in PNG_SIZES.items():
        path = ROOT / name
        im = Image.open(path)
        assert im.size == size, (name, im.size)
        assert im.mode == "RGBA", (name, im.mode)
        rgba = np.array(im)
        images[name] = rgba
        assert np.any(rgba[:, :, 3] == 255), name
        bbox = im.getbbox()
        assert bbox is not None, name
        report["pngs"][name] = {"size": list(size), "mode": im.mode, "alpha_bbox": list(bbox), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        if name not in ("adaptive-background.png", "icon-1024.png"):
            assert np.all(rgba[[0, -1], :, 3] == 0) and np.all(rgba[:, [0, -1], 3] == 0), name
        if name in ("adaptive-foreground.png", "adaptive-monochrome.png"):
            y, x = np.nonzero(rgba[:, :, 3])
            center_radius = np.hypot(x + 0.5 - 216, y + 0.5 - 216).max()
            corner_radius = np.hypot(np.abs(x + 0.5 - 216) + 0.5, np.abs(y + 0.5 - 216) + 0.5).max()
            assert corner_radius <= 132, (name, corner_radius)
            report["pngs"][name]["max_nontransparent_pixel_center_radius"] = float(center_radius)
            report["pngs"][name]["max_nontransparent_pixel_corner_radius"] = float(corner_radius)

    background = images["adaptive-background.png"]
    assert np.all(background == np.array([*GREEN, 255])), "Background must be exactly #227865 with full opacity"
    mono = images["adaptive-monochrome.png"]
    assert np.all(mono[mono[:, :, 3] > 0, :3] == 255), "Monochrome RGB must remain pure white"
    holes = closed_holes(mono[:, :, 3])
    assert len(holes) == 3 and all(h["pixels"] > 30 for h in holes), holes
    foreground = images["adaptive-foreground.png"]
    removed = (foreground[:, :, 3] == 255) & (mono[:, :, 3] == 0)
    removed_colors, color_counts = np.unique(foreground[removed, :3], axis=0, return_counts=True)
    counts = {"#" + "".join(f"{int(n):02X}" for n in color): int(count) for color, count in zip(removed_colors, color_counts)}
    assert counts.get("#07111B", 0) > 100 and counts.get("#227865", 0) > 100, counts
    report["checks"]["monochrome_holes"] = holes
    report["checks"]["cutout_foreground_colors"] = counts
    report["checks"]["background_exact_rgba"] = [*GREEN, 255]
    icon = images["icon-1024.png"]
    for x, y in ((0, 0), (1023, 0), (0, 1023), (1023, 1023)):
        assert icon[y, x, 3] == 0
    assert tuple(icon[0, 512]) == (*GREEN, 255)
    for name in ("icon-1024.png", "adaptive-foreground.png", "splash.png"):
        rgba = images[name]
        opaque = rgba[rgba[:, :, 3] == 255, :3]
        for color in (DARK, GREEN, IVORY):
            assert np.any(np.all(opaque == color, axis=1)), (name, color)
    report["checks"]["icon_round_corners_transparent"] = True
    report["checks"]["specified_colors_present"] = True

    for path in sorted(ROOT.rglob("*.svg")):
        element = ET.fromstring(path.read_text(encoding="utf-8"))
        for node in element.iter():
            assert node.tag.split("}")[-1] in {"svg", "g", "path", "rect"}, (path.name, node.tag)
            assert not any(k.split("}")[-1] in {"href", "font-family"} for k in node.attrib), path.name
        if path.name in SVG_SIZES and path.parent == ROOT:
            expected = SVG_SIZES[path.name]
            actual = tuple(float(element.attrib[k]) for k in ("width", "height"))
            assert actual == expected
            fills = sorted({node.attrib["fill"] for node in element.iter() if "fill" in node.attrib})
            report["svgs"][path.name] = {"size": list(expected), "fills": fills, "paths_only_no_fonts_or_rasters": True}
    assert report["svgs"]["wordmark.svg"]["fills"] == ["#227865", "#F5EEDF"]
    for name in SVG_SIZES:
        preview = Image.open(ROOT / "previews" / (Path(name).stem + ".png"))
        assert preview.mode == "RGBA" and preview.size == SVG_SIZES[name]
        assert preview.getbbox() is not None
    favicon = np.array(Image.open(ROOT / "previews/favicon.png"))
    # At 32px the eye curves are subpixel shapes; inspect their dark coverage
    # instead of requiring large blocks of unblended interior pixels.
    dark_pixels = int(np.count_nonzero((np.max(favicon[:, :, :3], axis=2) < 100) & (favicon[:, :, 3] == 255)))
    green_pixels = int(np.count_nonzero((np.max(np.abs(favicon[:, :, :3].astype(int) - GREEN), axis=2) <= 2) & (favicon[:, :, 3] == 255)))
    assert dark_pixels >= 20 and green_pixels >= 2, (dark_pixels, green_pixels)
    report["checks"]["favicon_32px_rendered"] = True
    report["checks"]["favicon_dark_coverage_pixels"] = dark_pixels
    report["checks"]["eight_requested_deliverables"] = list(SVG_SIZES) + list(PNG_SIZES)
    (ROOT / "validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    make_sheet()
    print(json.dumps(report, indent=2))


def make_sheet():
    sheet = Image.new("RGB", (1440, 1540), DARK)
    draw = ImageDraw.Draw(sheet)
    regular = "C:/Windows/Fonts/segoeui.ttf"
    bold = "C:/Windows/Fonts/segoeuib.ttf"
    def font(size, strong=False):
        try:
            return ImageFont.truetype(bold if strong else regular, size)
        except OSError:
            return ImageFont.load_default(size=size)
    draw.text((44, 30), "SOMNICARD / SLEEPY CARD", fill=IVORY, font=font(34, True))
    draw.text((44, 82), "Measured vector redraw  |  #F5EEDF  #227865  #07111B", fill=(155, 177, 173), font=font(19))
    specs = [
        ("logo-mark.svg", "previews/logo-mark.png", "512 x 512 / transparent"),
        ("wordmark.svg", "previews/wordmark.png", "Outlined lettering / transparent"),
        ("icon-1024.png", "icon-1024.png", "1024 x 1024 / rounded green tile"),
        ("adaptive-foreground.png", "adaptive-foreground.png", "432 x 432 / safe circle radius 132"),
        ("adaptive-background.png", "adaptive-background.png", "432 x 432 / solid #227865"),
        ("adaptive-monochrome.png", "adaptive-monochrome.png", "432 x 432 / white with alpha cutouts"),
        ("splash.png", "splash.png", "512 x 512 / transparent"),
        ("favicon.svg", "previews/favicon.png", "32 x 32 / enlarged and actual size"),
    ]
    for i, (name, relative, note) in enumerate(specs):
        x = 36 + (i % 3) * 468
        y = 140 + (i // 3) * 452
        draw.rounded_rectangle((x, y, x + 440, y + 424), radius=18, fill=(15, 29, 39), outline=(39, 59, 66))
        draw.text((x + 20, y + 18), name, fill=IVORY, font=font(20, True))
        draw.text((x + 20, y + 52), note, fill=(155, 177, 173), font=font(15))
        im = Image.open(ROOT / relative).convert("RGBA")
        if name == "wordmark.svg":
            im.thumbnail((396, 300), Image.Resampling.LANCZOS)
        elif name == "favicon.svg":
            im = im.resize((224, 224), Image.Resampling.NEAREST)
        else:
            im.thumbnail((310, 310), Image.Resampling.LANCZOS)
        if name.startswith("adaptive-") and name != "adaptive-background.png":
            radius = 132 * im.width / 432
            cx, cy = x + 220, y + 246
            draw.ellipse((cx-radius, cy-radius, cx+radius, cy+radius), outline=(80, 113, 112), width=1)
        sheet.paste(im, (x + (440-im.width)//2, y + 88 + (310-im.height)//2), im)
        if name == "favicon.svg":
            native = Image.open(ROOT / relative).convert("RGBA")
            sheet.paste(native, (x+376, y+363), native)
    draw.text((980, 1135), "8 assets verified", fill=IVORY, font=font(27, True))
    draw.text((980, 1180), "SVG paths / no font dependency", fill=(155,177,173), font=font(18))
    draw.text((980, 1215), "PNG exported from SVG with Godot", fill=(155,177,173), font=font(18))
    draw.text((980, 1250), "Adaptive safety and alpha cutouts checked", fill=(155,177,173), font=font(17))
    sheet.save(ROOT / "previews/overview.png")


if __name__ == "__main__":
    main()
