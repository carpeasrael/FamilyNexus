#!/usr/bin/env python3
"""Rauchtest der Web-Version (E-53) in Chrome (headless), nur Python-Standardbibliothek.

Startet die gebaute App (build/web_app, über tool/build_web.sh), legt den Browser-Tresor an, lädt neu, prüft falsches und
richtiges Passwort. Geprüft wird über den Semantikbaum von Flutter (Text im DOM), bedient wird über Mausklicks und
Tastatur per DevTools-Protokoll. Aufruf: tool/web_smoke.py [Pfad zu Chrome]
"""

import base64, hashlib, json, os, socket, struct, subprocess, sys, tempfile, time, urllib.request

class WS:
    def __init__(self, url):
        assert url.startswith('ws://')
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
        self.events = []
    def _recv_exact(self, n):
        d = b''
        while len(d) < n:
            c = self.s.recv(n - len(d))
            if not c: raise EOFError
            d += c
        return d
    def _read_frame(self):
        b1, b2 = self._recv_exact(2)
        ln = b2 & 0x7f
        if ln == 126: ln = struct.unpack('>H', self._recv_exact(2))[0]
        elif ln == 127: ln = struct.unpack('>Q', self._recv_exact(8))[0]
        return b1 & 0x0f, self._recv_exact(ln)
    def send(self, method, **params):
        self.id += 1
        payload = json.dumps({'id': self.id, 'method': method, 'params': params}).encode()
        mask = os.urandom(4)
        ln = len(payload)
        hdr = b'\x81' + (bytes([0x80 | ln]) if ln < 126 else b'\xfe' + struct.pack('>H', ln) if ln < 65536 else b'\xff' + struct.pack('>Q', ln))
        self.s.sendall(hdr + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))
        want = self.id
        msg = b''
        while True:
            op, data = self._read_frame()
            if op == 1 or op == 0:
                msg += data
                m = json.loads(msg); msg = b''
                if 'method' in m: self.events.append(m)
                if m.get('id') == want:
                    if 'error' in m: raise RuntimeError(m['error'])
                    return m.get('result', {})
            elif op == 8: raise EOFError

def _drain(ws, seconds):
    end = time.time() + seconds
    ws.s.settimeout(0.5)
    msg = b''
    while time.time() < end:
        try:
            op, data = ws._read_frame()
        except socket.timeout:
            continue
        if op in (0, 1):
            msg += data
            try:
                m = json.loads(msg); msg = b''
                if 'method' in m: ws.events.append(m)
            except Exception:
                pass
    ws.s.settimeout(60)

class Chrome:
    def __init__(self, chrome, width=1100, height=800, port=9333):
        self.dir = tempfile.mkdtemp()
        self.proc = subprocess.Popen([chrome, '--headless=new', '--disable-gpu', '--no-sandbox', f'--user-data-dir={self.dir}',
            f'--remote-debugging-port={port}', f'--window-size={width},{height}', 'about:blank'], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
        for _ in range(60):
            try:
                tabs = json.load(urllib.request.urlopen(f'http://127.0.0.1:{port}/json'))
                page = [t for t in tabs if t['type'] == 'page'][0]
                break
            except Exception:
                time.sleep(0.5)
        self.ws = WS(page['webSocketDebuggerUrl'])
        self.ws.send('Page.enable'); self.ws.send('Runtime.enable'); self.ws.send('Log.enable')
        self.ws.send('Emulation.setDeviceMetricsOverride', width=width, height=height, deviceScaleFactor=1, mobile=False)
    def goto(self, url, wait=8):
        self.ws.send('Page.navigate', url=url); time.sleep(wait)
    def shot(self, path):
        r = self.ws.send('Page.captureScreenshot', format='png')
        open(path, 'wb').write(base64.b64decode(r['data']))
    def click(self, x, y):
        for t in ('mousePressed', 'mouseReleased'):
            self.ws.send('Input.dispatchMouseEvent', type=t, x=x, y=y, button='left', clickCount=1)
        time.sleep(0.4)
    def type(self, text):
        self.ws.send('Input.insertText', text=text); time.sleep(0.3)
    def key(self, key, code=None, vk=None):
        for t in ('keyDown', 'keyUp'):
            self.ws.send('Input.dispatchKeyEvent', type=t, key=key, code=code or key, windowsVirtualKeyCode=vk or 0)
        time.sleep(0.3)
    def wait(self, seconds):
        _drain(self.ws, seconds)
    def console(self):
        out = []
        for e in self.ws.events:
            if e['method'] == 'Runtime.consoleAPICalled':
                out.append(' '.join(str(a.get('value', a.get('description', ''))) for a in e['params']['args'])[:300])
            elif e['method'] == 'Runtime.exceptionThrown':
                out.append('EXC ' + json.dumps(e['params']['exceptionDetails'])[:400])
            elif e['method'] == 'Log.entryAdded':
                out.append('LOG ' + e['params']['entry'].get('text', '')[:300])
        return out
    def close(self):
        self.proc.terminate()

def main():
    import functools, http.server, threading
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build', 'web_app')
    if not os.path.isdir(root):
        sys.exit('build/web_app fehlt (tool/build_web.sh)')
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=root)
    handler.log_message = lambda *a, **k: None
    httpd = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    url = f'http://127.0.0.1:{httpd.server_address[1]}/'
    chrome_path = sys.argv[1] if len(sys.argv) > 1 else next(
        (c for c in ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', 'google-chrome', 'google-chrome-stable', 'chromium', 'chromium-browser']
         if os.path.exists(c) or subprocess.call(['which', c], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0), None)
    if not chrome_path:
        sys.exit('Chrome nicht gefunden')
    c = Chrome(chrome_path, port=9300 + os.getpid() % 500)
    failures = []

    def texts():
        # Semantik einschalten (Flutter legt sie erst auf Anforderung an) und alle Beschriftungen lesen.
        c.ws.send('Runtime.evaluate', expression="document.querySelector('flt-semantics-placeholder')?.click()")
        time.sleep(0.8)
        r = c.ws.send('Runtime.evaluate', returnByValue=True, expression=(
            "Array.from(document.querySelectorAll('flt-semantics, input, textarea')).map(e => (e.getAttribute('aria-label') || e.innerText || '')).join('|')"))
        return r.get('result', {}).get('value', '')

    def expect(label, needle, wait=10):
        end = time.time() + wait
        seen = ''
        while time.time() < end:
            seen = texts()
            if needle in seen:
                print('ok  ', label)
                return
            time.sleep(1)
        failures.append(label)
        print('FAIL', label, '- gesucht:', needle, '- gesehen:', seen[:200])

    # Das Einschalten der Semantik ändert die Bedienung der Seite; deshalb wird vor jeder Eingabe neu geladen und
    # die Semantik nur zum Lesen eingeschaltet.
    try:
        c.goto(url, wait=8)
        expect('Tresor einrichten', 'Browser-Tresor einrichten')
        c.goto(url, wait=8)
        c.click(550, 408); c.type('smoke-passwort-0123'); c.click(550, 468); c.type('smoke-passwort-0123')
        c.click(404, 532)
        expect('Start nach dem Anlegen (Willkommen)', 'Willkommen bei FamilyNexus', wait=30)
        time.sleep(6)  # localStorage wird verzögert geschrieben
        c.goto(url, wait=8)
        expect('Entsperren nach Neuladen', 'FamilyNexus entsperren')
        c.goto(url, wait=8)
        c.click(550, 380); c.type('falsches-passwort'); c.key('Enter', 'Enter', 13)
        expect('Falsches Passwort abgelehnt', 'Falsches Passwort', wait=30)
        c.goto(url, wait=8)
        c.click(550, 380); c.type('smoke-passwort-0123'); c.key('Enter', 'Enter', 13)
        expect('Richtiges Passwort entsperrt', 'Willkommen bei FamilyNexus', wait=30)
    finally:
        c.close()
        httpd.shutdown()
    if failures:
        sys.exit(f'{len(failures)} Prüfung(en) fehlgeschlagen')
    print('Rauchtest bestanden.')


if __name__ == '__main__':
    main()
