#!/usr/bin/env python3
"""AURORA-Bericht für TP-FN-DEF-G1G2 (Default-Test G1–G2).

Liest die Schritte und Abnahmekriterien aus Default_test_G1-G2.md, die Ergebnisse aus
<Lauf-Ordner>/results.json und die Bilder aus <Lauf-Ordner>/screenshots/ und erzeugt
<Lauf-Ordner>/Testreport_<Ordner>_DE.html und .pdf (Chromium headless).

  python3 make_report.py report <Lauf-Ordner>          # HTML + PDF
  python3 make_report.py report <Lauf-Ordner> --check  # nur Prüfung, kein Bericht
  python3 make_report.py textshot <in.txt> <out.png>   # CLI-Ausgabe als Bild-Beleg
  python3 make_report.py skeleton <Lauf-Ordner>        # leere results.json anlegen

Ein Schritt ohne Eintrag in results.json gilt als ⏳ (nicht durchgeführt).
"""
import base64
import datetime as dt
import html
import json
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PLAN = os.path.join(HERE, 'Default_test_G1-G2.md')
FONTS = os.path.join(HERE, 'assets', 'fonts')

STATUS = {
    'passed': ('✅', 'Bestanden', 'ok'),
    'passed_with_issue': ('⚠️', 'Bestanden mit Befund', 'warn'),
    'failed': ('❌', 'Fehlgeschlagen', 'fail'),
    'pending': ('⏳', 'Nicht durchgeführt', 'open'),
    'na': ('n/a', 'Nicht anwendbar', 'na'),
}


# ---------------------------------------------------------------- Plan lesen
def _cells(line):
    return [c.strip() for c in line.strip().strip('|').split('|')]


def parse_plan(path=PLAN):
    steps, criteria, sections = [], [], []
    section = None
    version = ''
    for line in open(path, encoding='utf-8'):
        m = re.match(r'\*\*Planversion: (v\d+)\*\*', line)
        if m:
            version = m.group(1)
        m = re.match(r'### ([A-Z])\. (.+)', line)
        if m:
            section = (m.group(1), m.group(2).strip())
            sections.append(section)
            continue
        if line.startswith('| DT-'):
            c = _cells(line)
            if len(c) >= 5:
                steps.append({'id': c[0], 'device': c[1], 'action': c[2], 'expected': c[3],
                              'shots': c[4], 'section': section})
        elif line.startswith('| AK-'):
            c = _cells(line)
            criteria.append({'id': c[0], 'text': c[1], 'steps': re.findall(r'DT-[A-Z]-\d{2}', c[2])})
    return version, sections, steps, criteria


# ---------------------------------------------------------------- Hilfen
def md_inline(text):
    """Backticks und **fett** aus dem Plan in HTML übersetzen (Rest escapen)."""
    out = []
    for i, part in enumerate(re.split(r'(`[^`]*`)', text)):
        if part.startswith('`') and part.endswith('`') and len(part) > 1:
            out.append('<code>%s</code>' % html.escape(part[1:-1]))
        else:
            p = html.escape(part)
            p = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', p)
            out.append(p)
    return ''.join(out)


def b64(path):
    with open(path, 'rb') as f:
        return base64.b64encode(f.read()).decode('ascii')


def font_css():
    faces = [('Space Grotesk', 'SpaceGrotesk-Variable.ttf', '300 700'),
             ('IBM Plex Sans', 'IBMPlexSans-Variable.ttf', '100 700'),
             ('IBM Plex Mono', 'IBMPlexMono-Regular.ttf', '400'),
             ('IBM Plex Mono', 'IBMPlexMono-Medium.ttf', '500')]
    css = []
    for fam, file, weight in faces:
        p = os.path.join(FONTS, file)
        if os.path.exists(p):
            css.append("@font-face{font-family:'%s';src:url(data:font/ttf;base64,%s) format('truetype');"
                       "font-weight:%s;font-style:normal}" % (fam, b64(p), weight))
    return ''.join(css)


def badge(status):
    icon, label, cls = STATUS.get(status, STATUS['pending'])
    return '<span class="badge b-%s">%s %s</span>' % (cls, icon, label)


# ---------------------------------------------------------------- Prüfung
def check(run_dir, steps, results):
    problems = []
    known = {s['id'] for s in steps}
    for sid, r in results.get('steps', {}).items():
        if sid not in known:
            problems.append('%s: Schritt steht nicht im Plan' % sid)
            continue
        st = r.get('status')
        if st not in STATUS:
            problems.append('%s: unbekannter Status %r' % (sid, st))
        ev = r.get('evidence', [])
        if st in ('passed', 'passed_with_issue', 'failed') and not ev:
            problems.append('%s: %s ohne Screenshot' % (sid, st))
        if st in ('passed', 'passed_with_issue', 'failed') and not r.get('observed'):
            problems.append('%s: Beobachtetes Ergebnis fehlt' % sid)
        if st in ('pending', 'na') and not r.get('comment'):
            problems.append('%s: %s ohne Grund (comment)' % (sid, st))
        for e in ev:
            if not os.path.exists(os.path.join(run_dir, e)):
                problems.append('%s: Beleg fehlt auf der Platte: %s' % (sid, e))
    return problems


# ---------------------------------------------------------------- Bericht
CSS = r"""
:root{--primary:#0f766e;--primary-dark:#0b5f58;--primary-light:#14b8a6;--success:#15803d;--warning:#b45309;--danger:#b91c1c;--info:#0284c7;
--bg-body:#f6f7fb;--bg-primary:#ffffff;--bg-secondary:#eff3f8;--bg-tertiary:#e6edf6;--text-primary:#0f172a;--text-secondary:#334155;--text-muted:#64748b;
--border-primary:#d7e0ea;--border-secondary:#c1cbd8;--shadow-sm:0 1px 2px rgba(15,23,42,.08);
--ok-bg:rgba(21,128,61,.12);--warn-bg:rgba(180,83,9,.12);--fail-bg:rgba(185,28,28,.12);--open-bg:rgba(2,132,199,.12);--na-bg:rgba(100,116,139,.15);--na:#475569;
--font-display:'Space Grotesk','IBM Plex Sans',system-ui,sans-serif;--font-sans:'IBM Plex Sans','Helvetica Neue',Arial,sans-serif;--font-mono:'IBM Plex Mono',Consolas,monospace;
--radius-sm:8px;--radius-md:12px;--radius-lg:18px;--radius-full:9999px;--space-1:4px;--space-2:8px;--space-3:12px;--space-4:16px;--space-6:24px;--space-8:32px}
@page{size:A4;margin:14mm 12mm}
*{box-sizing:border-box}
body{margin:0;background:var(--bg-body);color:var(--text-primary);font-family:var(--font-sans);font-size:10.5pt;line-height:1.5;-webkit-print-color-adjust:exact;print-color-adjust:exact}
.wrap{padding:0}
h1,h2,h3{font-family:var(--font-display);font-weight:600;letter-spacing:-.01em;line-height:1.2;margin:0}
h1{font-size:24pt}h2{font-size:16pt;margin:var(--space-8) 0 var(--space-3);color:var(--primary)}h3{font-size:12.5pt}
code,.mono{font-family:var(--font-mono);font-size:.9em}
.hero{background:var(--bg-primary);border:1px solid var(--border-primary);border-top:6px solid var(--primary);border-radius:var(--radius-lg);padding:var(--space-6);box-shadow:var(--shadow-sm)}
.hero .sub{color:var(--text-secondary);margin-top:var(--space-2)}
.verdict{margin-top:var(--space-4);font-family:var(--font-display);font-size:14pt;font-weight:600}
.v-ok{color:var(--success)}.v-fail{color:var(--danger)}.v-open{color:var(--warning)}
.kpis{display:flex;gap:var(--space-3);margin-top:var(--space-4);flex-wrap:wrap}
.kpi{flex:1;min-width:90px;background:var(--bg-secondary);border:1px solid var(--border-primary);border-radius:var(--radius-md);padding:var(--space-3);text-align:center}
.kpi b{display:block;font-family:var(--font-display);font-size:18pt}
.kpi span{font-size:8.5pt;color:var(--text-secondary)}
table{width:100%;border-collapse:collapse;background:var(--bg-primary);border:1px solid var(--border-primary);border-radius:var(--radius-md);overflow:hidden;font-size:9.5pt}
th{background:var(--bg-tertiary);text-align:left;font-weight:600;color:var(--text-secondary)}
th,td{padding:6px 9px;border-bottom:1px solid var(--border-primary);vertical-align:top}
tr{page-break-inside:avoid}
.badge{display:inline-block;border-radius:var(--radius-full);padding:2px 10px;font-size:8.5pt;font-weight:600;white-space:nowrap}
.b-ok{background:var(--ok-bg);color:var(--success)}.b-warn{background:var(--warn-bg);color:var(--warning)}
.b-fail{background:var(--fail-bg);color:var(--danger)}.b-open{background:var(--open-bg);color:var(--info)}.b-na{background:var(--na-bg);color:var(--na)}
.step{background:var(--bg-primary);border:1px solid var(--border-primary);border-left:5px solid var(--border-secondary);border-radius:var(--radius-md);padding:var(--space-4);margin:var(--space-3) 0;box-shadow:var(--shadow-sm);page-break-inside:avoid}
.step.s-ok{border-left-color:var(--success)}.step.s-warn{border-left-color:var(--warning)}.step.s-fail{border-left-color:var(--danger)}.step.s-open{border-left-color:var(--info)}.step.s-na{border-left-color:var(--na)}
.step-head{display:flex;justify-content:space-between;align-items:center;gap:var(--space-3);margin-bottom:var(--space-2)}
.step-head .id{font-family:var(--font-mono);font-weight:500;color:var(--primary)}
.step-head .dev{color:var(--text-muted);font-size:9pt}
.kv{display:grid;grid-template-columns:150px 1fr;gap:4px var(--space-3);font-size:9.5pt}
.kv dt{color:var(--text-muted);font-weight:600}.kv dd{margin:0}
.cmp{margin-top:var(--space-2);padding:var(--space-2) var(--space-3);border-radius:var(--radius-sm);background:var(--bg-secondary);font-size:9.5pt}
.shots{display:flex;flex-wrap:wrap;gap:var(--space-3);margin-top:var(--space-3)}
figure{margin:0;flex:0 1 auto;max-width:48%;page-break-inside:avoid}
figure img{max-width:100%;max-height:105mm;border:1px solid var(--border-secondary);border-radius:var(--radius-sm);display:block}
figcaption{font-family:var(--font-mono);font-size:8pt;color:var(--text-muted);margin-top:2px}
.missing{color:var(--danger);font-weight:600}
.note{color:var(--text-secondary);font-size:9pt}
.section{page-break-before:auto}
.foot{margin-top:var(--space-8);color:var(--text-muted);font-size:8.5pt;border-top:1px solid var(--border-primary);padding-top:var(--space-2)}
"""


def build_html(run_dir, version, sections, steps, criteria, results, problems):
    run = results.get('run', {})
    rs = results.get('steps', {})
    version = run.get('plan_version', version)
    folder = os.path.basename(os.path.normpath(run_dir))

    def st(sid):
        return rs.get(sid, {}).get('status', 'pending')

    counts = {k: 0 for k in STATUS}
    for s in steps:
        counts[st(s['id'])] += 1

    crit_rows, crit_ok = [], True
    for c in criteria:
        sts = [st(x) for x in c['steps']]
        if any(x == 'failed' for x in sts):
            res = 'failed'
        elif any(x in ('pending',) for x in sts):
            res = 'pending'
        elif all(x == 'passed' for x in sts):
            res = 'passed'
        else:
            res = 'passed_with_issue'
        if res in ('failed', 'pending'):
            crit_ok = False
        crit_rows.append('<tr><td class="mono">%s</td><td>%s</td><td class="mono">%s</td><td>%s</td></tr>' % (
            c['id'], md_inline(c['text']), ', '.join(c['steps']), badge(res)))

    if counts['failed']:
        verdict = '<div class="verdict v-fail">Gesamtergebnis: ❌ nicht bestanden</div>'
    elif not crit_ok:
        verdict = '<div class="verdict v-open">Gesamtergebnis: ⏳ unvollständig, Abnahme nicht belegt</div>'
    else:
        verdict = '<div class="verdict v-ok">Gesamtergebnis: ✅ bestanden (alle Abnahmekriterien belegt)</div>'

    h = []
    h.append('<!DOCTYPE html><html lang="de" data-theme="light"><head><meta charset="utf-8">')
    h.append('<title>Testreport FamilyNexus – %s</title><style>%s%s</style></head><body><div class="wrap">' % (
        html.escape(folder), font_css(), CSS))
    h.append('<div class="hero"><h1>Testreport FamilyNexus · Default-Test G1–G2</h1>')
    h.append('<div class="sub">Plan <code>TP-FN-DEF-G1G2 %s</code> · Lauf <code>%s</code> · %s</div>' % (
        html.escape(version), html.escape(folder), html.escape(run.get('date', ''))))
    h.append(verdict)
    h.append('<div class="kpis">')
    for k in STATUS:
        icon, label, cls = STATUS[k]
        h.append('<div class="kpi"><b class="%s">%d</b><span>%s %s</span></div>' % (
            {'ok': 'v-ok', 'fail': 'v-fail'}.get(cls, ''), counts[k], icon, label))
    h.append('</div></div>')

    # Umgebung
    h.append('<h2>Plattform und System</h2><table><tr><th>Angabe</th><th>G1 (N1)</th><th>G2 (I2)</th></tr>')
    g1, g2 = run.get('g1', {}), run.get('g2', {})
    for key, label in [('platform', 'Plattform'), ('device', 'Gerät / Emulator'), ('os', 'Betriebssystem'),
                       ('operation', 'Bedienung'), ('install', 'Installationsquelle'),
                       ('app_version', 'App-Version (Ist)'), ('screenshot_method', 'Screenshot-Methode')]:
        h.append('<tr><td>%s</td><td>%s</td><td>%s</td></tr>' % (
            label, md_inline(str(g1.get(key, '–'))), md_inline(str(g2.get(key, '–')))))
    h.append('</table>')
    h.append('<table style="margin-top:12px"><tr><th>Angabe</th><th>Wert</th></tr>')
    for key, label in [('commit', 'Commit'), ('build', 'Build'), ('tester', 'Durchführung'),
                       ('start', 'Beginn'), ('end', 'Ende'), ('matrix_org_release', 'Freigabe matrix.org'),
                       ('accounts', 'Konten des Laufs')]:
        h.append('<tr><td>%s</td><td>%s</td></tr>' % (label, md_inline(str(run.get(key, '–')))))
    h.append('</table>')

    h.append('<h2>Abnahmekriterien</h2><table><tr><th>ID</th><th>Kriterium</th><th>Schritte</th><th>Ergebnis</th></tr>%s</table>'
             % ''.join(crit_rows))

    findings = results.get('findings', [])
    if findings:
        h.append('<h2>Befunde</h2><table><tr><th>ID</th><th>Schritt</th><th>Schwere</th><th>Beschreibung</th><th>Issue</th></tr>')
        for f in findings:
            h.append('<tr><td class="mono">%s</td><td class="mono">%s</td><td>%s</td><td>%s</td><td class="mono">%s</td></tr>' % tuple(
                md_inline(str(f.get(k, '–'))) for k in ('id', 'step', 'severity', 'text', 'issue')))
        h.append('</table>')

    notes = run.get('notes', [])
    if notes or problems:
        h.append('<h2>Hinweise zum Lauf</h2><ul>')
        for n in notes:
            h.append('<li>%s</li>' % md_inline(n))
        for p in problems:
            h.append('<li class="missing">Prüfhinweis: %s</li>' % html.escape(p))
        h.append('</ul>')

    # Schritte
    h.append('<h2>Testschritte: Erwartet gegen Beobachtet</h2>')
    current = None
    for s in steps:
        if s['section'] != current:
            current = s['section']
            h.append('<h3 class="section" style="margin-top:20px">%s. %s</h3>' % (html.escape(current[0]), md_inline(current[1])))
        r = rs.get(s['id'], {})
        status = r.get('status', 'pending')
        cls = STATUS.get(status, STATUS['pending'])[2]
        h.append('<div class="step s-%s"><div class="step-head"><div><span class="id">%s</span> <span class="dev">· %s%s</span></div>%s</div>' % (
            cls, s['id'], md_inline(s['device']),
            (' · %s' % html.escape(r['time'])) if r.get('time') else '', badge(status)))
        h.append('<dl class="kv"><dt>Aktion</dt><dd>%s</dd><dt>Erwartetes Ergebnis</dt><dd>%s</dd>' % (
            md_inline(s['action']), md_inline(s['expected'])))
        h.append('<dt>Beobachtetes Ergebnis</dt><dd>%s</dd>' % (
            md_inline(r['observed']) if r.get('observed') else '<span class="note">– nicht erfasst –</span>'))
        if r.get('comparison'):
            h.append('<dt>Abgleich</dt><dd>%s</dd>' % md_inline(r['comparison']))
        if r.get('comment'):
            h.append('<dt>Anmerkung</dt><dd>%s</dd>' % md_inline(r['comment']))
        h.append('<dt>Soll-Belege</dt><dd class="mono">%s</dd></dl>' % md_inline(s['shots']))
        ev = r.get('evidence', [])
        if ev:
            h.append('<div class="shots">')
            for e in ev:
                p = os.path.join(run_dir, e)
                if os.path.exists(p) and e.lower().endswith(('.png', '.jpg', '.jpeg')):
                    mime = 'image/png' if e.lower().endswith('.png') else 'image/jpeg'
                    h.append('<figure><img alt="%s" src="data:%s;base64,%s"><figcaption>%s</figcaption></figure>' % (
                        html.escape(e), mime, b64(p), html.escape(e)))
                else:
                    h.append('<figure><div class="missing">Beleg fehlt: %s</div></figure>' % html.escape(e))
            h.append('</div>')
        elif status in ('passed', 'passed_with_issue', 'failed'):
            h.append('<div class="missing">Kein Screenshot hinterlegt.</div>')
        h.append('</div>')

    h.append('<div class="foot">Erzeugt am %s mit <code>User E2E Test/Default_test_G1-G2/make_report.py</code>. '
             'Bewertung: ✅ nur mit Beleg; nicht Ausgeführtes ist ⏳. Geheimnisse sind in Belegen geschwärzt und liegen nur unter <code>secure/</code>.</div>'
             % dt.datetime.now().strftime('%d.%m.%Y %H:%M'))
    h.append('</div></body></html>')
    return ''.join(h)


def find_chromium():
    for name in ('chromium', 'chromium-browser', 'google-chrome-stable', 'google-chrome'):
        p = shutil.which(name)
        if p:
            return p
    return None


def cmd_report(run_dir, only_check=False):
    version, sections, steps, criteria = parse_plan()
    rpath = os.path.join(run_dir, 'results.json')
    results = json.load(open(rpath, encoding='utf-8')) if os.path.exists(rpath) else {}
    problems = check(run_dir, steps, results)
    for p in problems:
        print('PRÜFHINWEIS:', p)
    print('%d Schritte im Plan, %d mit Ergebnis, %d Prüfhinweise' % (
        len(steps), len(results.get('steps', {})), len(problems)))
    if only_check:
        return 1 if problems else 0
    folder = os.path.basename(os.path.normpath(run_dir))
    base = os.path.join(run_dir, 'Testreport_%s_DE' % folder)
    with open(base + '.html', 'w', encoding='utf-8') as f:
        f.write(build_html(run_dir, version, sections, steps, criteria, results, problems))
    chrome = find_chromium()
    if not chrome:
        print('Kein Chromium gefunden: nur HTML erzeugt:', base + '.html')
        return 1
    subprocess.run([chrome, '--headless', '--disable-gpu', '--no-sandbox', '--no-pdf-header-footer',
                    '--print-to-pdf=' + base + '.pdf', 'file://' + os.path.abspath(base + '.html')],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print('Bericht:', base + '.pdf')
    return 0


def cmd_textshot(src, dst):
    from PIL import Image, ImageDraw, ImageFont
    text = open(src, encoding='utf-8', errors='replace').read().rstrip('\n')
    font_path = os.path.join(FONTS, 'IBMPlexMono-Regular.ttf')
    font = ImageFont.truetype(font_path, 18) if os.path.exists(font_path) else ImageFont.load_default()
    lines = []
    for raw in text.split('\n'):
        while len(raw) > 110:
            lines.append(raw[:110])
            raw = '  ' + raw[110:]
        lines.append(raw)
    w = 40 + max([int(font.getlength(l)) for l in lines] + [400])
    hgt = 70 + 26 * len(lines)
    img = Image.new('RGB', (w, hgt), (11, 17, 32))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w, 30], fill=(15, 118, 110))
    d.text((14, 5), os.path.basename(src) + ' · ' + dt.datetime.now().strftime('%Y-%m-%d %H:%M:%S'), font=font, fill=(248, 250, 252))
    for i, l in enumerate(lines):
        d.text((20, 44 + 26 * i), l, font=font, fill=(203, 213, 225))
    img.save(dst)
    print('Bild:', dst)
    return 0


def cmd_skeleton(run_dir):
    os.makedirs(os.path.join(run_dir, 'screenshots'), exist_ok=True)
    os.makedirs(os.path.join(run_dir, 'logs'), exist_ok=True)
    rpath = os.path.join(run_dir, 'results.json')
    if os.path.exists(rpath):
        print('results.json besteht schon, nichts geändert')
        return 1
    dev = {k: '' for k in ('platform', 'device', 'os', 'operation', 'install', 'app_version', 'screenshot_method')}
    plan_version = parse_plan()[0]
    data = {'run': {'date': dt.date.today().isoformat(), 'plan_version': plan_version, 'tester': 'Claude-Agent (Tester) mit Nutzer für Captcha/E-Mail',
                    'commit': '', 'build': '', 'start': '', 'end': '', 'matrix_org_release': '',
                    'accounts': '', 'g1': dict(dev), 'g2': dict(dev), 'notes': []},
            'steps': {}, 'findings': []}
    json.dump(data, open(rpath, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    print('Angelegt:', rpath)
    return 0


def main(argv):
    if len(argv) >= 3 and argv[1] == 'report':
        return cmd_report(argv[2], '--check' in argv)
    if len(argv) == 4 and argv[1] == 'textshot':
        return cmd_textshot(argv[2], argv[3])
    if len(argv) == 3 and argv[1] == 'skeleton':
        return cmd_skeleton(argv[2])
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
