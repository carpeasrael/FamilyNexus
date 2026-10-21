#!/usr/bin/env python3
"""Erzeugt docs/ABHAENGIGKEITEN.md (SBOM-artige Liste) aus pubspec.lock und pub.dev (Version, Alter, Lizenz, Pflege)."""
import json, re, sys, urllib.request, datetime, concurrent.futures

def get(url):
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            return json.load(r)
    except Exception:
        return None

lock = open('pubspec.lock', encoding='utf-8').read()
pkgs = []
for m in re.finditer(r'^  (\S+):\n    dependency: "?([^"\n]+)"?\n(?:.*\n)*?    source: (\w+)\n    version: "([^"]+)"', lock, re.M):
    name, dep, source, version = m.groups()
    pkgs.append((name, dep, source, version))

def info(p):
    name, dep, source, version = p
    if source != 'hosted':
        return (name, dep, source, version, '—', '—', '—', 'SDK/lokal')
    meta = get(f'https://pub.dev/api/packages/{name}')
    score = get(f'https://pub.dev/api/packages/{name}/score') or {}
    lic = ', '.join(t.split(':', 1)[1] for t in score.get('tags', []) if t.startswith('license:') and t not in ('license:fsf-libre', 'license:osi-approved')) or '?'
    published = '?'
    latest = '?'
    flags = []
    if meta:
        latest = meta['latest']['version']
        for v in meta['versions']:
            if v['version'] == version:
                published = v['published'][:10]
        if meta.get('isDiscontinued'):
            flags.append('eingestellt')
        if meta.get('replacedBy'):
            flags.append('ersetzt durch ' + meta['replacedBy'])
    if latest != version and latest != '?':
        flags.append(f'neuer: {latest}')
    return (name, dep, source, version, published, lic, str(score.get('grantedPoints', '?')), ', '.join(flags) or 'ok')

with concurrent.futures.ThreadPoolExecutor(8) as ex:
    rows = list(ex.map(info, pkgs))
rows.sort(key=lambda r: ({'direct main': 0, 'direct dev': 1, 'direct overridden': 1, 'transitive': 2}.get(r[1], 3), r[0]))
out = ['# Abhängigkeiten (SBOM)', '', f'Stand: {datetime.date.today()} · erzeugt mit `tool/sbom.py` aus `pubspec.lock` und pub.dev.', '',
       'Alle direkten Abhängigkeiten sind in `pubspec.yaml` exakt gepinnt; transitive Versionen fixiert `pubspec.lock`. Spalte „Pub-Punkte“ = pub.dev-Bewertung (max. 160).', '',
       '| Paket | Art | Version | Veröffentlicht | Lizenz | Pub-Punkte | Hinweis |', '|---|---|---|---|---|---|---|']
for n, dep, src, ver, pub, lic, pts, note in rows:
    out.append(f'| `{n}` | {dep} | {ver} | {pub} | {lic} | {pts} | {note} |')
open('docs/ABHAENGIGKEITEN.md', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print(len(rows), 'Pakete')
