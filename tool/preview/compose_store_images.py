#!/usr/bin/env python3
"""Baut aus den Roh-Screenshots das App-Store-Bilderpaket (kurze Bildunterschrift + Screenshot auf Markenhintergrund).

Eingabe: je Sprache und Größe ein Ordner mit 1-heute.png … 6-familie.png (siehe store/screenshots/README.md).
Aufruf:  python3 tool/preview/compose_store_images.py <Roh-Ordner> <Ausgabe-Ordner>
         <Roh-Ordner> enthält <breite>-<sprache>/ (z. B. 1206-de/, 1320-en/).
Ausgabe: <Ausgabe-Ordner>/<de-DE|en-US>/<breite>x<höhe>/<nn>-<name>.png (PNG, ohne Alpha).
Apple-Vorgaben (docs/STORE.md): höchstens 10 Bilder je Größe, Text knapp, Motiv mittig, keine Preise/URLs/Auszeichnungen.

Play-Modus: python3 tool/preview/compose_store_images.py --play <Roh-Ordner> [<Ausgabe-Ordner>]
         <Roh-Ordner> enthält <de|en>/<nr>-<motiv>.png (Ausgabe von tool/preview/decode_shots.py, 1-heute … 7-datenschutz).
Ausgabe: <Ausgabe-Ordner>/<de-DE|en-US>/phoneScreenshots/<nn>-<name>.png, 1080×1920, PNG RGB ohne Alpha
         (Standard-Ausgabe: store/screenshots/android). Motive, Reihenfolge und Überschriften: tool/preview/play_captions.json;
         Überschriften höchstens 2 Zeilen. Der iOS-Modus (ohne --play) bleibt unverändert.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'fonts', 'SpaceGrotesk-Variable.ttf')
LOCALES = {'de': 'de-DE', 'en': 'en-US'}

# Reihenfolge = Geschichte der Nutzung: Termine → Tag → Chat → privat → Einkauf → Familie.
SHOTS = [
    ('2-kalender', {'de': 'Der Familienkalender für alle', 'en': 'One calendar for the whole family'}),
    ('1-heute', {'de': 'Der Tag der Familie im Blick', 'en': 'Your family’s day at a glance'}),
    ('3-chat', {'de': 'Verschlüsselter Familienchat', 'en': 'Chat, end-to-end encrypted'}),
    ('4-einzelchat', {'de': 'Auch persönlich: Einzelchats', 'en': 'Private one-to-one chats'}),
    ('5-einkauf', {'de': 'Einkaufszettel, den alle sehen', 'en': 'A shopping list everyone shares'}),
    ('6-familie', {'de': 'Familie einfach einladen', 'en': 'Invite your family in seconds'}),
]

TOP, BOTTOM = (11, 26, 34), (24, 14, 52)   # Farben aus dem App-Hintergrund
ACCENT = (45, 212, 191)                    # Teal der App


def gradient(w, h):
    img = Image.new('RGB', (w, h))
    px = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        px.line([(0, y), (w, y)], fill=tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
    return img


def wrap(draw, text, font, max_w):
    lines, cur = [], ''
    for word in text.split():
        trial = (cur + ' ' + word).strip()
        if draw.textlength(trial, font=font) <= max_w or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    return lines + [cur]


PLAY_SIZE = (1080, 1920)   # 9:16, innerhalb der Play-Grenzen (320–3840 px, Seitenverhältnis höchstens 2:1)
PLAY_CAPTIONS = os.path.join(os.path.dirname(__file__), 'play_captions.json')
REPO_ROOT = os.path.join(os.path.dirname(__file__), '..', '..')


def compose(raw_path, caption, size, max_lines=None):
    """max_lines=None: bisheriges Verhalten (iOS). Sonst wird die Schrift verkleinert, bis die Überschrift in max_lines Zeilen passt."""
    w, h = size
    canvas = gradient(w, h)
    d = ImageDraw.Draw(canvas)
    size_px = round(w * 0.075)
    while True:   # Schrift verkleinern, bis auch das längste Wort in die Breite passt
        font = ImageFont.truetype(FONT, size_px)
        font.set_variation_by_name('Bold')
        fits = max(d.textlength(word, font=font) for word in caption.split()) <= w * 0.86
        if fits and max_lines is not None:
            fits = len(wrap(d, caption, font, w * 0.86)) <= max_lines
        if fits:
            break
        size_px -= 2
    lines = wrap(d, caption, font, w * 0.86)
    line_h = round(font.size * 1.18)
    cap_h = round(h * 0.075) + round(w * 0.075 * 1.18) * 2   # feste Höhe, damit alle Bilder gleich aufgebaut sind
    y = round(h * 0.055)
    if max_lines is not None:   # Play: Überschrift mittig in einem Block aus max_lines Zeilen, Akzentstrich immer an derselben Stelle
        y0 = y
        y += round((max_lines - len(lines)) * line_h / 2)
    for line in lines:
        d.text((w / 2, y), line, font=font, fill=(255, 255, 255), anchor='ma')
        y += line_h
    if max_lines is not None:
        y = y0 + max_lines * line_h
    d.rounded_rectangle([w / 2 - w * 0.06, y + w * 0.012, w / 2 + w * 0.06, y + w * 0.012 + 8], 4, fill=ACCENT)

    shot = Image.open(raw_path).convert('RGB')
    top = cap_h + round(h * 0.03)
    avail_h = h - top - round(h * 0.035)
    scale = min(avail_h / shot.height, w * 0.88 / shot.width)
    shot = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.LANCZOS)
    radius = round(shot.width * 0.065)
    mask = Image.new('L', shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.size[0] - 1, shot.size[1] - 1], radius, fill=255)
    x = (w - shot.width) // 2
    canvas.paste(shot, (x, top), mask)
    ImageDraw.Draw(canvas).rounded_rectangle([x, top, x + shot.width - 1, top + shot.height - 1], radius, outline=(70, 90, 110), width=3)
    return canvas


def main(raw_root, out_root):
    for name in sorted(os.listdir(raw_root)):
        width, lang = name.split('-')
        src = os.path.join(raw_root, name)
        first = Image.open(os.path.join(src, SHOTS[0][0] + '.png'))
        size = first.size
        out = os.path.join(out_root, LOCALES[lang], f'{size[0]}x{size[1]}')
        os.makedirs(out, exist_ok=True)
        for i, (key, captions) in enumerate(SHOTS, 1):
            img = compose(os.path.join(src, key + '.png'), captions[lang], size)
            img.save(os.path.join(out, f'{i:02d}-{key.split("-", 1)[1]}.png'), optimize=True)
        print(out, size)


def play_shots():
    with open(PLAY_CAPTIONS, encoding='utf-8') as f:
        return json.load(f)['shots']


def main_play(raw_root, out_root):
    shots = play_shots()
    for lang, locale in LOCALES.items():
        src = os.path.join(raw_root, lang)
        out = os.path.join(out_root, locale, 'phoneScreenshots')
        os.makedirs(out, exist_ok=True)
        for i, shot in enumerate(shots, 1):
            img = compose(os.path.join(src, shot['raw'] + '.png'), shot[lang], PLAY_SIZE, max_lines=2)
            img.save(os.path.join(out, f'{i:02d}-{shot["name"]}.png'), optimize=True)
        print(out, PLAY_SIZE)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args and args[0] == '--play':
        main_play(args[1], args[2] if len(args) > 2 else os.path.join(REPO_ROOT, 'store', 'screenshots', 'android'))
    else:
        main(args[0], args[1])
