#!/usr/bin/env python3
"""Bedient die App im Sandbox-Emulator über uiautomator und adb (nur Standardbibliothek).

  ui.py <G1|G2> list [filter]          sichtbare Elemente: Beschriftung | klickbar | Mittelpunkt
  ui.py <G1|G2> tap <text> [n]         Element tippen, dessen Beschriftung <text> enthält (n-ter Treffer, ab 1);
                                       liegt es außerhalb des Bildschirms, wird zuerst gescrollt (bis 5-mal)
  ui.py <G1|G2> tapxy <x> <y>
  ui.py <G1|G2> long <text>            langes Drücken (1 s)
  ui.py <G1|G2> type <text>            Text in das fokussierte Feld (Leerzeichen erlaubt; Umlaute → Ersatzschreibung)
  ui.py <G1|G2> typesecret <SCHLUESSEL> Wert aus FN_SECRET_FILE tippen, ohne ihn auszugeben
  ui.py <G1|G2> key <BACK|ENTER|TAB|DEL> [n]
  ui.py <G1|G2> wait <text> [sek]      wartet, bis ein Element mit <text> sichtbar ist (0) oder Zeit um (3)
  ui.py <G1|G2> scroll <down|up>
"""
import os, re, subprocess, sys, time

ADB = os.path.join(os.environ.get('ANDROID_SDK_ROOT', os.path.expanduser('~/Android/Sdk')), 'platform-tools', 'adb')
SERIAL = {'G1': 'emulator-5560', 'G2': 'emulator-5562'}
UML = str.maketrans({'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'Ä': 'Ae', 'Ö': 'Oe', 'Ü': 'Ue', 'ß': 'ss', '„': '"', '“': '"', '–': '-'})
KEYS = {'BACK': 4, 'ENTER': 66, 'TAB': 61, 'DEL': 67}


def adb(dev, *a, capture=True):
    return subprocess.run([ADB, '-s', SERIAL[dev], *a], capture_output=capture, text=True).stdout


def nodes(dev):
    adb(dev, 'shell', 'uiautomator', 'dump', '/sdcard/ui.xml')
    xml = adb(dev, 'exec-out', 'cat', '/sdcard/ui.xml')
    out = []
    for m in re.finditer(r'<node [^>]*>', xml):
        n = m.group(0)
        g = lambda k: (re.search(k + r'="([^"]*)"', n) or [None, ''])[1]
        label = (g('content-desc') or g('text')).replace('&#10;', ' / ').replace('&amp;', '&').replace('&quot;', '"')
        b = re.findall(r'\d+', g('bounds'))
        if not label or len(b) != 4:
            continue
        x1, y1, x2, y2 = map(int, b)
        out.append((label, g('clickable') == 'true', (x1 + x2) // 2, (y1 + y2) // 2, g('class')))
    return out


def find(dev, text, idx=1):
    hits = [n for n in nodes(dev) if text.lower() in n[0].lower()]
    hits.sort(key=lambda n: not n[1])  # klickbare zuerst
    return hits[idx - 1] if len(hits) >= idx else None


def screen(dev):
    m = re.search(r'(\d+)x(\d+)', adb(dev, 'shell', 'wm', 'size').splitlines()[-1])
    return int(m.group(1)), int(m.group(2))


def visible(dev, text, idx=1):
    w, h = screen(dev)
    for _ in range(6):
        n = find(dev, text, idx)
        if n and 150 < n[3] < h - 150:
            return n
        if n is None:
            return None
        y1, y2 = ((h * 3) // 4, h // 4) if n[3] >= h - 150 else (h // 4, (h * 3) // 4)
        adb(dev, 'shell', 'input', 'swipe', str(w // 2), str(y1), str(w // 2), str(y2), '400')
        time.sleep(1)
    return find(dev, text, idx)


def type_text(dev, t):
    t = t.translate(UML)
    for part in re.split(r'( )', t):
        if part == ' ':
            adb(dev, 'shell', 'input', 'keyevent', '62')
        elif part:
            esc = re.sub(r'([\\\'"`$&|;<>()*?!#~{}\[\]])', r'\\\1', part)
            adb(dev, 'shell', 'input', 'text', esc)


def main(a):
    if len(a) < 3 or a[1] not in SERIAL:
        print(__doc__); return 2
    dev, cmd, rest = a[1], a[2], a[3:]
    if cmd == 'list':
        for label, clk, x, y, cls in nodes(dev):
            if not rest or rest[0].lower() in label.lower():
                print('%s | %s | %d,%d' % (label[:90], 'klickbar' if clk else '-', x, y))
    elif cmd in ('tap', 'long'):
        n = visible(dev, rest[0], int(rest[1]) if len(rest) > 1 else 1)
        if not n:
            print('nicht gefunden:', rest[0]); return 1
        if cmd == 'tap':
            adb(dev, 'shell', 'input', 'tap', str(n[2]), str(n[3]))
        else:
            adb(dev, 'shell', 'input', 'swipe', str(n[2]), str(n[3]), str(n[2]), str(n[3]), '1000')
        print('%s: %s (%d,%d)' % (cmd, n[0][:70], n[2], n[3]))
    elif cmd == 'tapxy':
        adb(dev, 'shell', 'input', 'tap', rest[0], rest[1])
    elif cmd == 'type':
        type_text(dev, rest[0]); print('getippt')
    elif cmd == 'typesecret':
        f = os.environ.get('FN_SECRET_FILE') or sys.exit('FN_SECRET_FILE nicht gesetzt')
        val = next((m.group(1) for m in (re.match(r'\s*' + re.escape(rest[0]) + r'\s*=\s*(.*?)\s*$', l) for l in open(f, encoding='utf-8')) if m), None)
        if val is None:
            sys.exit('Schlüssel fehlt: ' + rest[0])
        type_text(dev, val); print('getippt (Wert verborgen)')
    elif cmd == 'key':
        for _ in range(int(rest[1]) if len(rest) > 1 else 1):
            adb(dev, 'shell', 'input', 'keyevent', str(KEYS[rest[0]]))
    elif cmd == 'wait':
        end = time.time() + (float(rest[1]) if len(rest) > 1 else 30)
        while time.time() < end:
            if find(dev, rest[0]):
                print('gefunden:', rest[0]); return 0
            time.sleep(1.5)
        print('nicht gefunden:', rest[0]); return 3
    elif cmd == 'scroll':
        y1, y2 = ('1700', '700') if rest[0] == 'down' else ('700', '1700')
        adb(dev, 'shell', 'input', 'swipe', '540', y1, '540', y2, '300')
    else:
        print(__doc__); return 2
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
