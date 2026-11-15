#!/usr/bin/env python3
"""Dekodiert die Zeilen `PNG <name> <base64>` aus dem Log von integration_test/store_screenshots_test.dart (Android, macOS).

Aufruf:  python3 tool/preview/decode_shots.py <log> <Ausgabe-Ordner> [<sprache>]
         Sprache (de|en) als drittes Argument oder aus dem Namen der Logdatei (z. B. shots_de.log, shots-en.txt).
Ausgabe: <Ausgabe-Ordner>/<sprache>/<name>.png. Rohaufnahmen nicht einchecken (Ausgabe z. B. unter /tmp).
Weiter mit: python3 tool/preview/compose_store_images.py --play <Ausgabe-Ordner>
"""
import base64
import os
import re
import sys

LINE = re.compile(r'PNG ([\w.-]+) ([A-Za-z0-9+/=]{16,})\s*$')
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


def language(log_path):
    m = re.search(r'(?:^|[^a-z])(de|en)(?:[^a-z]|$)', os.path.basename(log_path).lower())
    return m.group(1) if m else None


def decode(log_path, out_root, lang):
    out = os.path.join(out_root, lang)
    os.makedirs(out, exist_ok=True)
    names = []
    with open(log_path, encoding='utf-8', errors='replace') as f:
        for line in f:
            m = LINE.search(line)
            if not m:
                continue
            data = base64.b64decode(m.group(2))
            if not data.startswith(PNG_SIGNATURE):
                raise SystemExit(f'{m.group(1)}: keine PNG-Daten')
            with open(os.path.join(out, m.group(1) + '.png'), 'wb') as g:
                g.write(data)
            names.append(m.group(1))
    return out, names


if __name__ == '__main__':
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    log, out_root = sys.argv[1], sys.argv[2]
    lang = sys.argv[3] if len(sys.argv) > 3 else language(log)
    if lang not in ('de', 'en'):
        raise SystemExit('Sprache (de|en) als drittes Argument angeben oder im Namen der Logdatei führen')
    out, names = decode(log, out_root, lang)
    print(f'{len(names)} Bilder nach {out}: {", ".join(names)}')
    if not names:
        raise SystemExit('keine PNG-Zeilen im Log gefunden (Lauf abgebrochen oder abgeschnitten?)')
    if len(names) != 7:
        print(f'WARNUNG: erwartet werden 7 Bilder, gefunden {len(names)}', file=sys.stderr)
