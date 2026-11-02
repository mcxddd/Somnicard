# 第三批素材提示词

生成后放到下面写的文件夹里，文件名照抄。我会缩放、裁切后接进游戏。

## 一、电脑对手头像（8 张）

放到 `assets/art/source/avatars/`。每张单独生成，都附上 logo（`assets/branding/sleepy-card/previews/logo-mark.png`）和教练图（`assets/art/source/coach.png`）作为参考图。

### 共用部分（每张都放在最前面）

```
Use case: game character avatar.
Input image 1 is the brand logo: an ivory playing-card character with a tiny green spade at the upper-left and two simple dark crescent CLOSED sleepy eyes. Input image 2 is the existing coach character in the same style. Keep this exact character design: same ivory card body #F5EEDF, same rounded card shape, same closed crescent eyes, same tiny green spade, same flat vector style and line weight as the coach.
Composition: square 512x512, ONE character only, upright front view, head and upper card body filling about 80% of the canvas, centered. The character must read clearly when shown as a 48-pixel circle, so keep the face large and the accessory bold and simple.
Background: genuine alpha transparency everywhere outside the character. No circle, badge, frame, plate, scene or shadow behind it.
Style: crisp flat vector illustration, solid fills, clean dark-navy #07111B outlines, no gradients, no textures, no 3D, no text, no letters, no numbers, no watermark.
Palette: #07111B, #F5EEDF, #227865, #E5C17A plus the single accent colour named below.
```

### 每张的单独部分（接在共用部分后面）

| 文件名 | 单独部分 |
|---|---|
| `xiaoxia.png` | `Character: Xiaoxia, cheerful summer player. Accessory: a small straw sun hat with one coral flower. Accent colour coral #F28C6B. Tiny relaxed smile.` |
| `alan.png` | `Character: Alan, calm and careful. Accessory: a soft knit beanie and a short scarf. Accent colour mist blue #7FA7C9. Neutral calm mouth.` |
| `milo.png` | `Character: Milo, focused music lover. Accessory: round over-ear headphones. Accent colour violet #A08BD8. Small content smile.` |
| `qinghe.png` | `Character: Qinghe, gentle beginner. Accessory: a two-leaf green sprout growing from the top edge of the card. Accent colour leaf green #7CD7B7. Small shy smile with tiny blush marks.` |
| `noah.png` | `Character: Noah, steady and patient. Accessory: a small navy-and-white sailor captain cap. Accent colour sea teal #4FB3B0. Calm straight mouth.` |
| `chengzi.png` | `Character: Chengzi, playful and bold. Accessory: an orange-slice hair clip at one top corner. Accent colour orange #F2A63B. Mischievous grin.` |
| `ache.png` | `Character: Ache, cool and aggressive. Accessory: dark rounded sunglasses pushed up onto the top edge of the card, eyes still closed crescents below. Accent colour crimson #E0697A. Confident smirk.` |
| `xingye.png` | `Character: Xingye, night owl. Accessory: a floppy night cap with a small gold star at its tip. Accent colour deep indigo #5B6FC7. Sleepy little yawn mouth.` |

## 二、帮助主题图标（7 个）

放到 `assets/icons/source/`。共用部分直接复制 `assets/icons/source/generation-prompts.json` 里的 `shared_prompt`（和上一批图标一样），后面接下面的主题。

| 文件名 | 主题 |
|---|---|
| `help-start.png` | `Subject: a rounded playing card with a simple play triangle in its center, the triangle filled solid green.` |
| `help-table.png` | `Subject: a short stack of two poker chips seen from the side, with a small hand-pointer tapping the top chip; green accent on the chip edge stripes.` |
| `help-coach.png` | `Subject: a magnifying glass over a rounded playing card; small green spade inside the lens.` |
| `help-opponents.png` | `Subject: two overlapping rounded playing cards facing each other like opponents, one with a tiny green spade.` |
| `help-privacy.png` | `Subject: a rounded shield with a simple padlock in the center; green accent on the lock shackle.` |
| `help-install.png` | `Subject: a smartphone outline with a downward arrow entering its screen; green accent on the arrow.` |
| `help-about.png` | `Subject: a speech bubble containing a small lowercase information i made of a dot and a short line, with the dot solid green.` |
