#!/usr/bin/env python3
"""Erzeugt alle Symbole und Store-Grafiken aus einer Vektorbeschreibung (reproduzierbar, nur Pillow).

Motiv: drei leuchtende Knoten (Familie), verbunden zu einem „Nexus“, auf dunklem AURORA-Grund.
Aufruf: python3 tool/make_icons.py
"""
import json, os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BG = (11, 17, 32)
TEAL = (45, 212, 191)
MAGENTA = (244, 114, 182)
VIOLET = (167, 139, 250)
S = 1024  # Arbeitsgröße

def glow_layer(draw_fn, blur):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    return layer.filter(ImageFilter.GaussianBlur(blur))

def motif(scale=1.0):
    """Nur das Motiv (transparent), zentriert; scale<1 für die sichere Zone adaptiver Symbole."""
    c = S / 2
    pts = [(c, c - 215 * scale), (c - 195 * scale, c + 135 * scale), (c + 195 * scale, c + 135 * scale)]
    cols = [TEAL, MAGENTA, VIOLET]
    def lines(d):
        for i in range(3):
            d.line([pts[i], pts[(i + 1) % 3]], fill=TEAL + (255,), width=int(26 * scale))
        for p in pts:
            d.line([p, (c, c)], fill=VIOLET + (255,), width=int(18 * scale))
    def nodes(d):
        for p, col in zip(pts, cols):
            r = 92 * scale
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=col + (255,))
        r = 54 * scale
        d.ellipse([c - r, c - r, c + r, c + r], fill=(248, 250, 252, 255))
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.alpha_composite(glow_layer(lines, 28 * scale))
    out.alpha_composite(glow_layer(nodes, 34 * scale))
    sharp = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(sharp)
    lines(d); nodes(d)
    out.alpha_composite(sharp)
    return out

def background():
    img = Image.new("RGB", (S, S), BG)
    px = img.load()
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * S)
            r = int(BG[0] + (30 - BG[0]) * t * 0.9 + 12 * (1 - t))
            g = int(BG[1] + (22 - BG[1]) * t * 0.5 + 25 * (1 - t))
            b = int(BG[2] + (70 - BG[2]) * t * 0.9 + 18 * (1 - t) * 0)
            px[x, y] = (min(r, 255), min(g, 255), min(b, 255))
    return img

def save(img, path, size, alpha=True):
    p = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im = img.resize((size, size), Image.LANCZOS)
    if not alpha:
        im = im.convert("RGB")
    im.save(p, optimize=True)

bg = background()
full = bg.convert("RGBA"); full.alpha_composite(motif(1.0))         # Vollbild (iOS, Store)
adaptive_fg = motif(0.62)                                            # Android adaptiv: Motiv in der 66-%-Zone
legacy = bg.convert("RGBA"); legacy.alpha_composite(motif(0.9))

# iOS: ohne Alpha, Größen laut Contents.json
ios_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
cj = json.load(open(os.path.join(ROOT, ios_dir, "Contents.json")))
for im in cj["images"]:
    base = float(im["size"].split("x")[0]); scale = int(im["scale"][0])
    save(full, f"{ios_dir}/{im['filename']}", round(base * scale), alpha=False)

# macOS: abgerundetes Quadrat mit Rand wie üblich
mac_dir = "macos/Runner/Assets.xcassets/AppIcon.appiconset"
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([80, 80, S - 80, S - 80], radius=190, fill=255)
mac = Image.new("RGBA", (S, S), (0, 0, 0, 0))
inner = full.resize((S - 160, S - 160), Image.LANCZOS)
mac.paste(inner, (80, 80), mask.crop((80, 80, S - 80, S - 80)))
for n in (16, 32, 64, 128, 256, 512, 1024):
    save(mac, f"{mac_dir}/app_icon_{n}.png", n)

# Android: Legacy-Symbole + adaptives Symbol (Vordergrund PNG, Hintergrund Farbe/Verlauf)
for folder, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    rounded = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, S - 1, S - 1], radius=230, fill=255)
    rounded.paste(legacy, (0, 0), m)
    save(rounded, f"android/app/src/main/res/mipmap-{folder}/ic_launcher.png", size)
    save(adaptive_fg, f"android/app/src/main/res/mipmap-{folder}/ic_launcher_foreground.png", round(size * 108 / 48))
    save(bg, f"android/app/src/main/res/mipmap-{folder}/ic_launcher_background.png", round(size * 108 / 48), alpha=False)

# Store-Grafiken
save(full, "store/graphics/play-icon-512.png", 512, alpha=False)
save(full, "store/graphics/app-store-icon-1024.png", 1024, alpha=False)
feature = Image.new("RGB", (1024, 500), BG)
feature.paste(bg.resize((1024, 1024), Image.LANCZOS).crop((0, 262, 1024, 762)), (0, 0))
m = motif(1.0).resize((420, 420), Image.LANCZOS)
feature = feature.convert("RGBA"); feature.alpha_composite(m, (60, 40))
d = ImageDraw.Draw(feature)
from PIL import ImageFont
def font(size):
    for f in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()
d.text((510, 150), "FamilyNexus", font=font(76), fill=(248, 250, 252))
d.text((512, 250), "Kalender & Messenger", font=font(40), fill=TEAL)
d.text((512, 305), "Ende-zu-Ende-verschlüsselt", font=font(32), fill=(203, 213, 225))
feature.convert("RGB").save(os.path.join(ROOT, "store/graphics/play-feature-graphic-1024x500.png"), optimize=True)
print("Symbole und Grafiken erzeugt")
