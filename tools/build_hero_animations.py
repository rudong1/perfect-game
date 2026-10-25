"""Build aligned SpriteFrames metadata; source PNG pixels are kept unchanged.

The new atlases are image-generated art. Alpha bounds and a torso anchor align
locomotion to the original 320x380 canvas / sole at y=342. The higher-resolution
farewell uses a 400x500 canvas / sole at y=464, normalized by HeroAnimation.
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


def generated_frames(filename, lift, foot_y=342, canvas_h=380, canvas_w=320):
    """Read a new pose atlas without changing any generated PNG pixels.

    Detect the actual row gutters: generated sheets need not divide evenly at
    their midpoint. Slicing that midpoint cuts shoes into the following row.
    """
    pixels = np.asarray(Image.open(ART / filename).convert('RGBA'))
    occupied = (pixels[:, :, 3] > 32).any(axis=1)
    transitions = np.diff(np.r_[False, occupied, False].astype(int))
    rows = [(start, end) for start, end in zip(np.where(transitions == 1)[0], np.where(transitions == -1)[0]) if end-start > 20]
    assert len(rows) == 2, rows
    frames = []
    # Running supplies a small lift for passing/flight; the farewell supplies
    # zero lift because its calm gesture keeps both soles on the ground.
    for i in range(8):
        x0, x1 = [round(c * pixels.shape[1] / 4) for c in (i % 4, i % 4 + 1)]
        y0, y1 = rows[i // 4]
        cell = pixels[y0:y1, x0:x1]
        yy, xx = np.where(cell[:, :, 3] > 32)
        left, top, right, bottom = int(xx.min()), int(yy.min()), int(xx.max())+1, int(yy.max())+1
        w, h = right-left, bottom-top
        # Use the waist strip, excluding swinging hands and trailing hair,
        # instead of letting their bounding box move the entire character.
        torso = cell[top + round(h * 0.43):top + round(h * 0.58)]
        dark = (torso[:, :, :3].mean(axis=2) < 100) & (torso[:, :, 3] > 150)
        _, dx = np.where(dark)
        anchor_x = float(np.median(dx))
        assert left > 0 and right < x1-x0, (i, 'pose crosses a column gutter')
        offset_x = round(canvas_w/2-(anchor_x-left))
        assert w <= canvas_w and h <= canvas_h, (i, w, h)
        assert offset_x >= 0 and offset_x+w <= canvas_w, (i, 'hair crosses the logical canvas')
        assert foot_y-h-lift[i] >= 0, (i, 'head crosses the logical canvas')
        frames.append((x0+left, y0+top, w, h, offset_x, foot_y-h-lift[i]))
    return frames


def main():
    old = atlas_frames('hero_sheet.png', 320, 380, 16)
    motion = atlas_frames('hero_motion.png', 256, 384, 16)
    run = generated_frames('hero_run.png', [0, 3, 7, 4, 0, 3, 7, 4])
    reach = generated_frames('hero_reach.png', [0] * 8, foot_y=464, canvas_h=500, canvas_w=400)
    lines = ['[gd_resource type="SpriteFrames" format=3 uid="uid://ewk67rbhlqef"]', '',
             '[ext_resource type="Texture2D" path="res://assets/characters/hero/hero_sheet.png" id="old"]',
             '[ext_resource type="Texture2D" path="res://assets/characters/hero/hero_motion.png" id="motion"]',
             '[ext_resource type="Texture2D" path="res://assets/characters/hero/hero_run.png" id="run"]',
             '[ext_resource type="Texture2D" path="res://assets/characters/hero/hero_reach.png" id="reach"]', '']
    for source, frames in [('old', old), ('motion', motion), ('run', run), ('reach', reach)]:
        canvas_h = 500 if source == 'reach' else 380
        canvas_w = 400 if source == 'reach' else 320
        for i, (x, y, w, h, ox, oy) in enumerate(frames):
            lines += [f'[sub_resource type="AtlasTexture" id="{source}_{i}"]',
                      f'atlas = ExtResource("{source}")',
                      f'region = Rect2({x}, {y}, {w}, {h})',
                      f'margin = Rect2({ox}, {oy}, {canvas_w-w}, {canvas_h-h})', '']
    definitions = {
        'idle': (5, True, [('old', i) for i in range(4)]),
        'run': (10, True, [('run', i) for i in range(8)]),
        'sprint': (14, True, [('run', i) for i in range(8)]),
        'jump': (12, False, [('motion', 8), ('motion', 9), ('motion', 10)]),
        'apex': (1, False, [('motion', 10)]),
        'fall': (10, False, [('motion', 10), ('motion', 11)]),
        'land': (18, False, [('motion', 12), ('motion', 13), ('old', 0)]),
        'stop': (15, False, [('motion', 14), ('motion', 13), ('old', 0)]),
        'push': (1, True, [('motion', 15)]),
        'reach': (12, False, [('reach', i) for i in range(8)]),
        'crouch': (1, True, [('old', 12)]),
    }
    animations = []
    for name, (speed, loop, frames) in definitions.items():
        textures = ', '.join('{"duration": 1.0, "texture": SubResource("%s_%s")}' % f for f in frames)
        animations.append('{"name": &"%s", "speed": %s, "loop": %s, "frames": [%s]}' % (name, speed, str(loop).lower(), textures))
    lines += ['[resource]', 'animations = [' + ',\n'.join(animations) + ']', '']
    (ART / 'hero_frames.tres').write_text('\n'.join(lines))
    print('Wrote new 8-frame arm swing and single-palm gesture; retained jump, landing, braking and stationary push poses')


if __name__ == '__main__':
    main()
