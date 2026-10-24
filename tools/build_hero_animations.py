"""Build aligned SpriteFrames metadata; source PNG pixels are kept unchanged.

The extra atlas is image-generated art. Alpha bounds and a torso anchor align
its poses to the original sprite's 320x380 logical canvas / sole at y=342.
"""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/characters/hero'


def atlas_frames(filename, width, height, count):
    pixels = np.asarray(Image.open(ART / filename).convert('RGBA'))
    frames = []
    for i in range(count):
        x, y = i % 4 * width, i // 4 * height
        cell = pixels[y:y+height, x:x+width]
        mask = cell[:, :, 3] > 32
        yy, xx = np.where(mask)
        assert len(xx), (filename, i)
        left, top, right, bottom = int(xx.min()), int(yy.min()), int(xx.max())+1, int(yy.max())+1
        # Dark dress is a steadier horizontal anchor than the flowing hair.
        dark = (cell[:, :, :3].mean(axis=2) < 115) & (cell[:, :, 3] > 150)
        dark[:top + (bottom-top)//3] = False
        dy, dx = np.where(dark)
        anchor_x = float(np.median(dx)) if len(dx) else (left+right)/2
        offset_x = round(160 - (anchor_x-left))
        airborne = filename == 'hero_motion.png' and 8 <= i <= 11
        offset_y = 32 if airborne else 342 - (bottom-top)
        assert right-left <= 320 and bottom-top <= 380, (filename, i, (left, top, right, bottom))
        frames.append((x+left, y+top, right-left, bottom-top, offset_x, offset_y))
    return frames


def main():
    old = atlas_frames('hero_sheet.png', 320, 380, 16)
    motion = atlas_frames('hero_motion.png', 256, 384, 16)
    lines = ['[gd_resource type="SpriteFrames" format=3 uid="uid://ewk67rbhlqef"]', '',
             '[ext_resource type="Texture2D" path="res://assets/characters/hero/hero_sheet.png" id="old"]',
             '[ext_resource type="Texture2D" path="res://assets/characters/hero/hero_motion.png" id="motion"]', '']
    for source, frames in [('old', old), ('motion', motion)]:
        for i, (x, y, w, h, ox, oy) in enumerate(frames):
            lines += [f'[sub_resource type="AtlasTexture" id="{source}_{i}"]',
                      f'atlas = ExtResource("{source}")',
                      f'region = Rect2({x}, {y}, {w}, {h})',
                      f'margin = Rect2({ox}, {oy}, {320-w}, {380-h})', '']
    definitions = {
        'idle': (5, True, [('old', i) for i in range(4)]),
        'run': (10, True, [('motion', i) for i in range(8)]),
        'sprint': (14, True, [('motion', i) for i in range(8)]),
        'jump': (12, False, [('motion', 8), ('motion', 9), ('motion', 10)]),
        'apex': (1, False, [('motion', 10)]),
        'fall': (10, False, [('motion', 10), ('motion', 11)]),
        'land': (18, False, [('motion', 12), ('motion', 13), ('old', 0)]),
        'stop': (15, False, [('motion', 14), ('motion', 13), ('old', 0)]),
        'push': (1, True, [('motion', 15)]),
        'crouch': (1, True, [('old', 12)]),
    }
    animations = []
    for name, (speed, loop, frames) in definitions.items():
        textures = ', '.join('{"duration": 1.0, "texture": SubResource("%s_%s")}' % f for f in frames)
        animations.append('{"name": &"%s", "speed": %s, "loop": %s, "frames": [%s]}' % (name, speed, str(loop).lower(), textures))
    lines += ['[resource]', 'animations = [' + ',\n'.join(animations) + ']', '']
    (ART / 'hero_frames.tres').write_text('\n'.join(lines))
    print('Wrote 8-frame run/sprint, jump/apex/fall, landing, braking and stationary push animations')


if __name__ == '__main__':
    main()
