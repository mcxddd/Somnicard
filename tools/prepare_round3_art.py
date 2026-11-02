"""Make runtime copies of the round-3 artwork from the 512 px originals.

Icons are fitted into 128x128 with the same 13 px margin as the earlier set.
Avatars are cropped to a square around the head, masked to a circle and saved at
128x128, because seats draw them inside a round frame.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ICONS = ["help-start", "help-table", "help-coach", "help-opponents", "help-privacy", "help-install", "help-about", "home"]
AVATARS = ["xiaoxia", "alan", "milo", "qinghe", "noah", "chengzi", "ache", "xingye"]


def fit_icon(name: str) -> None:
    source = ROOT / "assets/icons/source" / f"{name}.png"
    if not source.exists():
        print("missing", source.name)
        return
    image = Image.open(source).convert("RGBA")
    image = image.crop(image.getchannel("A").getbbox())
    scale = 102 / max(image.size)
    image = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    canvas.paste(image, ((128 - image.width) // 2, (128 - image.height) // 2), image)
    canvas.save(ROOT / "assets/icons" / f"{name}.png")
    print("icon", name)


def circle_avatar(name: str) -> None:
    source = ROOT / "assets/art/source/avatars" / f"{name}.png"
    if not source.exists():
        print("missing", source.name)
        return
    image = Image.open(source).convert("RGBA")
    left, top, right, _ = image.getchannel("A").getbbox()
    # The face sits in the upper half of the card; a square from just above the
    # accessory keeps hat, eyes and mouth together.
    side = min(512, max(right - left, 360) + 24)
    centre = (left + right) / 2
    x0 = int(max(0, min(512 - side, centre - side / 2)))
    y0 = int(max(0, min(512 - side, top - 12)))
    square = image.crop((x0, y0, x0 + side, y0 + side)).resize((256, 256), Image.LANCZOS)
    mask = Image.new("L", (256, 256), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, 255, 255), fill=255)
    square.putalpha(Image.composite(square.getchannel("A"), mask, mask))
    out = ROOT / "assets/art/avatars"
    out.mkdir(exist_ok=True)
    square.resize((128, 128), Image.LANCZOS).save(out / f"{name}.png")
    print("avatar", name)


if __name__ == "__main__":
    for name in ICONS: fit_icon(name)
    for name in AVATARS: circle_avatar(name)
