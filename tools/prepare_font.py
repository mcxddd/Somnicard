"""Subset Noto Sans CJK SC into the bundled interface font.

Usage: python tools/prepare_font.py <NotoSansCJK-Regular.ttc> [OFL text]
Needs fontTools (pip install fonttools). The source collection is the SIL OFL 1.1
Noto Sans CJK shipped with Android (/system/fonts/NotoSansCJK-Regular.ttc); the
Simplified Chinese face is collection index 2.

Kept characters: every character in the game's scripts, scenes and data, printable
ASCII, general / CJK / full-width punctuation, arrows and card suits. Other Chinese
characters (player-chosen names) fall back to the system font, which renders Han
text fine; only punctuation after Latin text needed a bundled face.
"""
import sys
from pathlib import Path
from fontTools.ttLib import TTCollection
from fontTools import subset

root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1])
out = root / 'assets/fonts/NotoSansSC-Somnicard.otf'

chars = set(chr(c) for c in range(0x20, 0x7F))
for low, high in [(0x2000, 0x206F), (0x2190, 0x21FF), (0x2260, 0x2265), (0x2660, 0x2667), (0x2713, 0x2717),
                  (0x3000, 0x303F), (0xFF00, 0xFFEF), (0x00A0, 0x00FF), (0x2150, 0x215F), (0x2212, 0x2212)]:
    chars.update(chr(c) for c in range(low, high + 1))
for pattern in ['scripts/**/*.gd', 'scenes/**/*.tscn', 'data/*.json', 'project.godot']:
    for path in root.glob(pattern):
        chars.update(path.read_text(encoding='utf-8'))
chars = {c for c in chars if c.isprintable() or c == ' '}
# Noto CJK draws the middle dot full-width; keep the system font's narrow one.
chars.discard('·')

collection = TTCollection(str(source))
face = next(f for f in collection.fonts if f['name'].getDebugName(1) == 'Noto Sans CJK SC')
options = subset.Options()
options.layout_features = ['*']
options.name_IDs = ['*']
options.name_languages = ['*']
options.notdef_outline = True
subsetter = subset.Subsetter(options)
subsetter.populate(text=''.join(sorted(chars)))
subsetter.subset(face)
# Line metrics like Microsoft YaHei (ascent 1.06 em, descent 0.26 em). Godot sizes a
# line from every font in the fallback chain, so Noto's taller 1.16 / 0.29 em would
# grow every label; glyph ink stays below 0.9 em and is not clipped.
upm = face['head'].unitsPerEm
ascent, descent = round(1.06 * upm), round(0.26 * upm)
face['hhea'].ascent, face['hhea'].descent, face['hhea'].lineGap = ascent, -descent, 0
os2 = face['OS/2']
os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = ascent, -descent, 0
os2.usWinAscent, os2.usWinDescent = ascent, descent
out.parent.mkdir(parents=True, exist_ok=True)
face.save(str(out))

notice = face['name'].getDebugName(0)
licence = Path(sys.argv[2]).read_text(encoding='utf-8') if len(sys.argv) > 2 else ''
(root / 'assets/fonts/OFL.txt').write_text(
    f'{notice}\n\nNoto Sans CJK SC, subset for Somnicard (tools/prepare_font.py).\n'
    'This Font Software is licensed under the SIL Open Font License, Version 1.1.\n\n' + licence,
    encoding='utf-8', newline='\n')
print(f'FONT_OK {len(chars)} characters, {out.stat().st_size:,} bytes -> {out.relative_to(root)}')
