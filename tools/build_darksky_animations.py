"""Read the generated atlas and write frame metadata; PNG pixels stay intact.

The figure gutters, rather than equal cells, define the crops. Extended hug
hands can pass a nominal cell boundary while still remaining in clear space.
"""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/characters/darksky'
CANVAS_W, CANVAS_H = 512, 640
FOOT_X, FOOT_Y = 256, 560


def bands(occupied, max_gap, minimum):
    indices = np.flatnonzero(occupied)
    splits = np.flatnonzero(np.diff(indices) > max_gap + 1) + 1
    groups = np.split(indices, splits)
    return [(int(g[0]), int(g[-1]) + 1) for g in groups if len(g) and g[-1] - g[0] + 1 >= minimum]


def main():
    pixels = np.asarray(Image.open(ART / 'darksky_motion.png').convert('RGBA'))
    mask = pixels[:, :, 3] > 32
    rows = bands(mask.any(axis=1), 3, 100)
    assert len(rows) == 2, rows
    frames = []
    for top, bottom in rows:
        columns = bands(mask[top:bottom].any(axis=0), 12, 60)
        assert len(columns) == 4, columns
        for left, right in columns:
            yy, xx = np.where(mask[top:bottom, left:right])
            x, y = left + int(xx.min()), top + int(yy.min())
            w, h = int(xx.max()) + 1-int(xx.min()), int(yy.max()) + 1-int(yy.min())
            torso = pixels[y+round(h*0.43):y+round(h*0.61), x:x+w]
            dark = (torso[:, :, :3].mean(axis=2) < 100) & (torso[:, :, 3] > 150)
            _, dx = np.where(dark)
            anchor = float(np.median(dx))
            ox, oy = round(FOOT_X-anchor), FOOT_Y-h
            assert ox >= 0 and oy >= 0 and ox+w <= CANVAS_W and oy+h <= CANVAS_H, (x,y,w,h,ox,oy)
            frames.append((x, y, w, h, ox, oy))
    lines = ['[gd_resource type="SpriteFrames" format=3]', '',
             '[ext_resource type="Texture2D" path="res://assets/characters/darksky/darksky_motion.png" id="art"]', '']
    for i, (x, y, w, h, ox, oy) in enumerate(frames):
        lines += [f'[sub_resource type="AtlasTexture" id="pose_{i}"]',
                  'atlas = ExtResource("art")', f'region = Rect2({x}, {y}, {w}, {h})',
                  f'margin = Rect2({ox}, {oy}, {CANVAS_W-w}, {CANVAS_H-h})', '']
    definitions = {'idle': (3, True, [0]), 'reach': (3, True, [1]),
                   'hug': (5, False, [2, 3]), 'run': (8, True, [4, 5, 6, 7])}
    animations = []
    for name, (speed, loop, indices) in definitions.items():
        textures = ', '.join('{"duration": 1.0, "texture": SubResource("pose_%d")}' % i for i in indices)
        animations.append('{"name": &"%s", "speed": %s, "loop": %s, "frames": [%s]}' % (name, speed, str(loop).lower(), textures))
    lines += ['[resource]', 'animations = [' + ',\n'.join(animations) + ']',
              f'metadata/foot_origin = Vector2({FOOT_X}, {FOOT_Y})',
              f'metadata/stand_height = {float(frames[0][3])}', '']
    (ART / 'darksky_frames.tres').write_text('\n'.join(lines))
    print('Wrote Darksky idle, reach, embrace and walking frames:', frames)


if __name__ == '__main__':
    main()
