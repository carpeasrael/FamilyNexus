#!/usr/bin/env python3
"""IMAP-Helfer für TP-FN-DEF-G1G2 (Test-Postfach app_test@inneso.de, IONOS). Passwort nur aus secure/Test-Email.md,
nie ausgeben. Alle Zugriffe nur lesend (readonly), keine Mails löschen oder verschieben.

  mailcode.py check                       -> Anmeldung, Ordner, Anzahl INBOX
  mailcode.py wait <T0-epoch> <recipient> <codefile> [timeout_s]
      -> wartet auf Mail von matrix.org an <recipient> nach T0, schreibt Code nach <codefile> (600),
         gibt Absender/Empfänger/Betreff/Datum aus, Code als ******
"""
import email, email.header, email.utils, imaplib, os, re, sys, time

SECRET = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'secure', 'Test-Email.md')
HOST, PORT = 'imap.ionos.de', 993


def creds():
    user = pw = None
    for line in open(SECRET, encoding='utf-8'):
        m = re.match(r'\s*email password\s*=\s*(.+?)\s*$', line)
        if m:
            pw = m.group(1)
            continue
        m = re.match(r'\s*email\s*=\s*(\S+)', line)
        if m:
            user = m.group(1)
    return user, pw


def connect():
    user, pw = creds()
    c = imaplib.IMAP4_SSL(HOST, PORT, timeout=30)
    typ, _ = c.login(user, pw)
    return c, user, typ


def dec(h):
    return str(email.header.make_header(email.header.decode_header(h or '')))


def folders(c):
    typ, data = c.list()
    out = []
    for raw in data:
        s = raw.decode(errors='replace')
        m = re.search(r'"([^"]+)"\s*$', s) or re.search(r'(\S+)\s*$', s)
        out.append(m.group(1))
    return out


def body_text(msg):
    parts = []
    for p in msg.walk():
        if p.get_content_type() in ('text/plain', 'text/html'):
            try:
                parts.append(p.get_payload(decode=True).decode(p.get_content_charset() or 'utf-8', errors='replace'))
            except Exception:
                pass
    return '\n'.join(parts)


def main():
    if sys.argv[1] == 'check':
        c, user, typ = connect()
        print('Login', user, '->', typ)
        fs = folders(c)
        print('Ordner:', ', '.join(fs))
        typ, data = c.select('INBOX', readonly=True)
        print('INBOX:', typ, int(data[0]), 'Nachrichten')
        c.logout()
        return
    if sys.argv[1] == 'wait':
        t0, rcpt, codefile = float(sys.argv[2]), sys.argv[3].lower(), sys.argv[4]
        timeout = float(sys.argv[5]) if len(sys.argv) > 5 else 300
        end = time.time() + timeout
        while time.time() < end:
            c, user, _ = connect()
            fs = [f for f in folders(c) if f.upper() == 'INBOX' or 'spam' in f.lower() or 'junk' in f.lower()]
            best = None
            for f in fs:
                c.select('"%s"' % f, readonly=True)
                since = time.strftime('%d-%b-%Y', time.gmtime(t0 - 86400))
                typ, data = c.search(None, 'SINCE', since)
                for num in data[0].split():
                    typ, md = c.fetch(num, '(BODY.PEEK[])')
                    msg = email.message_from_bytes(md[0][1])
                    frm = dec(msg.get('From')).lower()
                    to = (dec(msg.get('To')) + ' ' + dec(msg.get('Delivered-To')) + ' ' + dec(msg.get('X-Original-To'))).lower()
                    dt = email.utils.parsedate_to_datetime(msg.get('Date')).timestamp() if msg.get('Date') else 0
                    if dt < t0 - 30 or not ('matrix.org' in frm or 'element.io' in frm):
                        continue
                    if rcpt not in to:
                        continue
                    if best is None or dt > best[0]:
                        best = (dt, f, msg)
            c.logout()
            if best:
                dt, f, msg = best
                text = body_text(msg)
                subj = dec(msg.get('Subject'))
                m = re.search(r'(?<!\d)(\d{6})(?!\d)', subj + '\n' + re.sub(r'<[^>]+>', ' ', text))
                print('Ordner:', f)
                print('Von:', dec(msg.get('From')))
                print('An:', dec(msg.get('To')))
                print('Betreff:', re.sub(r'\d{6}', '******', subj))
                print('Datum:', msg.get('Date'))
                if m:
                    fd = os.open(codefile, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
                    os.write(fd, m.group(1).encode())
                    os.close(fd)
                    print('Code: ****** (gefunden, in Datei mit Rechten 600)')
                else:
                    print('Code: nicht gefunden')
                return
            time.sleep(15)
        print('Keine passende Mail binnen', int(timeout), 's')
        sys.exit(3)


main()
