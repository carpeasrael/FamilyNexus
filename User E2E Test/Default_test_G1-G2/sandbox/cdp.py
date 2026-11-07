#!/usr/bin/env python3
"""Steuert Chrome im Test-Emulator (auch Custom Tabs) über das DevTools-Protokoll. Nur Standardbibliothek.

Voraussetzung: sandbox.sh up (leitet tcp:<port> auf chrome_devtools_remote des Emulators um).

  cdp.py <port> list                          Seiten (Typ, URL, Titel)
  cdp.py <port> text [match]                  sichtbarer Text der Seite (URL enthält <match>, sonst die jüngste)
  cdp.py <port> fields [match]                Eingabefelder, Knöpfe, Links mit Selektor-Vorschlag
  cdp.py <port> fill <css> <wert> [match]     Feld füllen (Ereignisse input/change)
  cdp.py <port> fillsecret <css> <SCHLUESSEL> [match]
                                              Feld mit Wert aus secure/<Laufdatei> füllen (Zeile "SCHLUESSEL = wert"),
                                              der Wert erscheint nie in Ausgabe oder Befehlszeile
  cdp.py <port> fillfile <css> <datei> [match] Feld mit Inhalt einer Datei füllen (z. B. E-Mail-Code, Rechte 600)
  cdp.py <port> click <css|text:Beschriftung> [match]   nur für Links/Schaltflächen ohne Formular
  cdp.py <port> submit <css|text:Beschriftung> [match]  Formular über diese Schaltfläche absenden (requestSubmit),
                                              danach bis 10 s warten, ob sich URL oder Text ändern.
                                              Rückgabe 0 = Seite hat reagiert, 5 = keine Änderung
                                              -> dann per Fingertipp: ui.py <G> tap "<Beschriftung>" (Lauf 23:
                                              React-Dialoge reagieren nur auf echte Eingaben)
  cdp.py <port> check <css> [match]           Kontrollkästchen setzen
  cdp.py <port> wait <text> [sek] [match]     wartet, bis <text> sichtbar ist (Rückgabe 0) oder Zeit um (3)
  cdp.py <port> url [match]                   aktuelle URL
  cdp.py <port> shot <out.png> [match]        Bild des Seiteninhalts (ohne Browserleiste)

Umgebungsvariable FN_SECRET_FILE: Pfad der Laufdatei unter secure/ (für fillsecret).
Captchas werden nie bedient: Erkennt das Werkzeug eine Captcha-Aufgabe, meldet es CAPTCHA und endet mit 4.
"""
import base64, json, os, re, socket, struct, sys, time, urllib.request


class WS:
    def __init__(self, url):
        host, rest = url[5:].split('/', 1)
        h, p = host.split(':')
        self.s = socket.create_connection((h, int(p)), timeout=60)
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall((f'GET /{rest} HTTP/1.1\r\nHost: {host}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
                        f'Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n').encode())
        buf = b''
        while b'\r\n\r\n' not in buf:
            buf += self.s.recv(1)
        assert b' 101 ' in buf.split(b'\r\n')[0], buf
        self.id = 0

    def _exact(self, n):
        d = b''
        while len(d) < n:
            c = self.s.recv(n - len(d))
            if not c:
                raise EOFError
            d += c
        return d

    def _frame(self):
        b1, b2 = self._exact(2)
        ln = b2 & 0x7f
        if ln == 126:
            ln = struct.unpack('>H', self._exact(2))[0]
        elif ln == 127:
            ln = struct.unpack('>Q', self._exact(8))[0]
        return b1 & 0x0f, self._exact(ln)

    def send(self, method, **params):
        self.id += 1
        data = json.dumps({'id': self.id, 'method': method, 'params': params}).encode()
        hdr = bytes([0x81])
        n = len(data)
        if n < 126:
            hdr += bytes([0x80 | n])
        elif n < 65536:
            hdr += bytes([0x80 | 126]) + struct.pack('>H', n)
        else:
            hdr += bytes([0x80 | 127]) + struct.pack('>Q', n)
        mask = os.urandom(4)
        self.s.sendall(hdr + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))
        while True:
            op, payload = self._frame()
            if op != 1:
                continue
            msg = json.loads(payload)
            if msg.get('id') == self.id:
                if 'error' in msg:
                    raise RuntimeError(msg['error'])
                return msg.get('result', {})


def targets(port):
    with urllib.request.urlopen(f'http://127.0.0.1:{port}/json', timeout=10) as r:
        return [t for t in json.load(r) if t.get('type') == 'page']


def page(port, match=None):
    ts = targets(port)
    if match:
        ts = [t for t in ts if match in t.get('url', '')]
    if not ts:
        sys.exit('Keine passende Seite' + (f' mit "{match}"' if match else ''))
    return WS(ts[0]['webSocketDebuggerUrl']), ts[0]


def ev(ws, js):
    r = ws.send('Runtime.evaluate', expression=js, returnByValue=True, awaitPromise=True)
    if 'exceptionDetails' in r:
        raise RuntimeError(r['exceptionDetails'].get('text'))
    return r.get('result', {}).get('value')


CAPTCHA_JS = """(() => !!document.querySelector('iframe[src*="captcha"], iframe[src*="challenges.cloudflare"], iframe[title*="hCaptcha"], iframe[title*="reCAPTCHA"], .g-recaptcha, .h-captcha, .cf-turnstile'))()"""


def secret(key):
    f = os.environ.get('FN_SECRET_FILE')
    if not f:
        sys.exit('FN_SECRET_FILE nicht gesetzt')
    for line in open(f, encoding='utf-8'):
        m = re.match(r'\s*' + re.escape(key) + r'\s*=\s*(.*?)\s*$', line)
        if m:
            return m.group(1)
    sys.exit(f'Schlüssel {key} fehlt in der Laufdatei')


def set_value(ws, css, value):
    js = """((css, v) => { const e = document.querySelector(css); if (!e) return 'fehlt';
      e.focus(); const p = Object.getPrototypeOf(e); const d = Object.getOwnPropertyDescriptor(p, 'value');
      d.set.call(e, v); e.dispatchEvent(new Event('input', {bubbles: true})); e.dispatchEvent(new Event('change', {bubbles: true}));
      return 'ok'; })(%s, %s)""" % (json.dumps(css), json.dumps(value))
    return ev(ws, js)


def main(a):
    if len(a) < 3:
        print(__doc__); return 2
    port, cmd, rest = int(a[1]), a[2], a[3:]
    if cmd == 'list':
        for t in targets(port):
            print(t['type'], t['url'][:120], '|', t.get('title', '')[:60])
        return 0
    if cmd in ('text', 'url', 'fields'):
        ws, t = page(port, rest[0] if rest else None)
        if cmd == 'url':
            print(ev(ws, 'location.href'))
        elif cmd == 'text':
            print(ev(ws, 'document.body ? document.body.innerText : ""'))
            if ev(ws, CAPTCHA_JS):
                print('\n[Hinweis] Captcha-Element auf der Seite erkannt.')
        else:
            js = """[...document.querySelectorAll('input,button,a,select,textarea')].filter(e => e.offsetParent !== null).map(e => {
              const id = e.id ? '#' + CSS.escape(e.id) : (e.name ? e.tagName.toLowerCase() + '[name="' + e.name + '"]' : e.tagName.toLowerCase());
              const v = (e.type === 'password' || e.type === 'hidden') ? (e.value ? '<gesetzt, verborgen>' : '') : (e.innerText || e.value || e.placeholder || e.getAttribute('aria-label') || '');
              return [id, e.type || '', v.trim().slice(0, 60)].join(' | ');
            }).join('\\n')"""
            print(ev(ws, js))
        return 0
    if cmd in ('fill', 'fillsecret', 'fillfile'):
        css, val = rest[0], rest[1]
        ws, t = page(port, rest[2] if len(rest) > 2 else None)
        if cmd == 'fillsecret':
            val = secret(val)
        elif cmd == 'fillfile':
            val = open(val, encoding='utf-8').read().strip()
        r = set_value(ws, css, val)
        print(r if cmd == 'fill' else ('ok (Wert verborgen)' if r == 'ok' else r))
        return 0 if r == 'ok' else 1
    if cmd == 'check':
        ws, t = page(port, rest[1] if len(rest) > 1 else None)
        print(ev(ws, """((css) => { const e = document.querySelector(css); if (!e) return 'fehlt'; if (!e.checked) e.click(); return e.checked ? 'ok' : 'nicht gesetzt'; })(%s)""" % json.dumps(rest[0])))
        return 0
    if cmd == 'click':
        target = rest[0]
        ws, t = page(port, rest[1] if len(rest) > 1 else None)
        if ev(ws, CAPTCHA_JS) and target.lower().startswith('text:') and 'captcha' in target.lower():
            print('CAPTCHA')
            return 4
        if target.startswith('text:'):
            js = """((t) => { const els = [...document.querySelectorAll('button,a,input[type=submit],[role=button]')].filter(e => e.offsetParent !== null);
              const e = els.find(e => (e.innerText || e.value || '').trim() === t) || els.find(e => (e.innerText || e.value || '').includes(t));
              if (!e) return 'fehlt'; e.click(); return 'ok'; })(%s)""" % json.dumps(target[5:])
        else:
            js = """((css) => { const e = document.querySelector(css); if (!e) return 'fehlt'; e.click(); return 'ok'; })(%s)""" % json.dumps(target)
        r = ev(ws, js)
        print(r)
        return 0 if r == 'ok' else 1
    if cmd == 'submit':
        target = rest[0]
        match = rest[1] if len(rest) > 1 else None
        ws, t = page(port, match)
        before = (ev(ws, 'location.href'), ev(ws, 'document.body ? document.body.innerText : ""'))
        if target.startswith('text:'):
            find = """[...document.querySelectorAll('button,input[type=submit]')].filter(e => e.offsetParent !== null)
              .find(e => (e.innerText || e.value || '').trim() === %s)""" % json.dumps(target[5:])
        else:
            find = 'document.querySelector(%s)' % json.dumps(target)
        r = ev(ws, """(() => { const b = %s; if (!b) return 'fehlt';
          if (b.form && b.type === 'submit') { b.form.requestSubmit(b); return 'requestSubmit'; }
          b.click(); return 'click'; })()""" % find)
        if r == 'fehlt':
            print('fehlt'); return 1
        end = time.time() + 10
        while time.time() < end:
            time.sleep(1)
            try:
                ws, t = page(port, match)
                now = (ev(ws, 'location.href'), ev(ws, 'document.body ? document.body.innerText : ""'))
            except BaseException:
                print(r, '-> Seite gewechselt'); return 0
            if now != before:
                print(r, '-> Seite hat reagiert:', now[0][:100]); return 0
        print(r, '-> keine Änderung; per Fingertipp wiederholen (ui.py tap)')
        return 5
    if cmd == 'shot':
        ws, t = page(port, rest[1] if len(rest) > 1 else None)
        r = ws.send('Page.captureScreenshot', format='png')
        with open(rest[0], 'wb') as f:
            f.write(base64.b64decode(r['data']))
        print('shot', rest[0])
        return 0
    if cmd == 'wait':
        text = rest[0]
        sec = float(rest[1]) if len(rest) > 1 else 30
        match = rest[2] if len(rest) > 2 else None
        end = time.time() + sec
        while time.time() < end:
            try:
                ws, t = page(port, match)
                body = ev(ws, 'document.body ? document.body.innerText : ""') or ''
                if text.lower() in body.lower():
                    print('gefunden:', text)
                    return 0
                if ev(ws, CAPTCHA_JS):
                    print('CAPTCHA')
                    return 4
            except SystemExit:
                pass
            except Exception:
                pass
            time.sleep(1)
        print('nicht gefunden:', text)
        return 3
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
