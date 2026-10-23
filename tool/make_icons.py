"""Erzeugt alle Symbole und Store-Grafiken aus assets/icon/app_icon.png (reproduzierbar, nur Pillow).

Quelle: quadratisches Emblem (Familienkalender, Glas/Neon auf dunklem AURORA-Grund), mindestens 1024 x 1024.
Aufruf: python3 tool/make_icons.py
"""
import json, os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 1024  # Arbeitsgröße
BG = (4, 22, 52)
TEAL = (45, 212, 191)
SRC = Image.open(os.path.join(ROOT, "assets/icon/app_icon.png")).convert("RGB").resize((S, S), Image.LANCZOS)

def save(img, path, size, alpha=True):
    p = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im = img.resize((size, size), Image.LANCZOS)
    if not alpha:
        im = im.convert("RGB")
    im.save(p, optimize=True)

full = SRC.convert("RGBA")                                           # Vollbild (iOS, Store)
legacy = full

# Android adaptiv: Hintergrund = mittlere Randfarbe, Vordergrund = Emblem in der 66-%-Zone
def edge_color():
    px = [SRC.getpixel((x, y)) for x in (4, S - 5) for y in (4, S - 5)]
    return tuple(sum(c[i] for c in px) // 4 for i in range(3))
bg = SRC.filter(ImageFilter.GaussianBlur(90))                       # weicher Hintergrund ohne sichtbare Naht
zone = round(S * 72 / 108)
adaptive_fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
adaptive_fg.paste(SRC.resize((zone, zone), Image.LANCZOS), ((S - zone) // 2, (S - zone) // 2))
# Monochrom (Android 13 Themed Icons): Helligkeit des Emblems als Alpha, weiß eingefärbt
gray = SRC.resize((zone, zone), Image.LANCZOS).convert("L").point(lambda v: max(0, min(255, (v - 105) * 255 // 70)))
mono_alpha = Image.new("L", (S, S), 0)
mono_alpha.paste(gray, ((S - zone) // 2, (S - zone) // 2))
mono = Image.new("RGBA", (S, S), (255, 255, 255, 0))
mono.putalpha(mono_alpha)

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

# Linux (Flatpak, hicolor): gleiches abgerundetes Quadrat wie macOS
for n in (128, 256, 512):
    save(mac, f"flatpak/icons/{n}x{n}/de.inneso.familynexus.png", n)

# Web (PWA): abgerundetes Quadrat, maskable vollflächig
for n in (192, 512):
    mac.resize((n, n), Image.LANCZOS).save(os.path.join(ROOT, f"web/icons/Icon-{n}.png"))
    SRC.resize((n, n), Image.LANCZOS).save(os.path.join(ROOT, f"web/icons/Icon-maskable-{n}.png"))
mac.resize((64, 64), Image.LANCZOS).save(os.path.join(ROOT, "web/favicon.png"))

# Windows: .ico mit mehreren Größen aus demselben abgerundeten Quadrat
mac.convert("RGBA").save(os.path.join(ROOT, "windows/runner/resources/app_icon.ico"),
                         sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

# Android: Legacy-Symbole + adaptives Symbol (Vordergrund PNG, Hintergrund Farbe/Verlauf)
for folder, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    rounded = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, S - 1, S - 1], radius=230, fill=255)
    rounded.paste(legacy, (0, 0), m)
    save(rounded, f"android/app/src/main/res/mipmap-{folder}/ic_launcher.png", size)
    save(adaptive_fg, f"android/app/src/main/res/mipmap-{folder}/ic_launcher_foreground.png", round(size * 108 / 48))
    save(bg, f"android/app/src/main/res/mipmap-{folder}/ic_launcher_background.png", round(size * 108 / 48), alpha=False)
    save(mono, f"android/app/src/main/res/mipmap-{folder}/ic_launcher_monochrome.png", round(size * 108 / 48))

# Store-Grafiken
save(full, "store/graphics/play-icon-512.png", 512, alpha=False)
save(full, "store/graphics/app-store-icon-1024.png", 1024, alpha=False)
feature = Image.new("RGB", (1024, 500), edge_color())
feature.paste(bg.crop((0, 262, 1024, 762)), (0, 0))
feature = feature.convert("RGBA")
badge = SRC.resize((420, 420), Image.LANCZOS).convert("RGBA")
bm = Image.new("L", (420, 420), 0)
ImageDraw.Draw(bm).rounded_rectangle([0, 0, 419, 419], radius=96, fill=255)
feature.paste(badge, (60, 40), bm)
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
