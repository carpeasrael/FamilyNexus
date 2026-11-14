#!/usr/bin/env python3
"""Erzeugt die PDFs der Exportunterlagen aus den Markdown-Quellen.

Aufruf: python3 tool/build_export_pdfs.py
Braucht: Python-Paket `markdown` und Google Chrome (headless).
Quelle:  docs/export-compliance/*.md   Ziel: gleichnamige .pdf daneben.
Schriften: assets/fonts (IBM Plex Sans, IBM Plex Mono, Space Grotesk), AURORA-Farben.
"""
import html
import pathlib
import subprocess
import sys
import tempfile

import markdown

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIR = ROOT / "docs" / "export-compliance"
FONTS = ROOT / "assets" / "fonts"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DOCS = {
    "encryption-description-en.md": ("en", "FamilyNexus – Description of Cryptographic Functionality"),
    "description-chiffrement-fr.md": ("fr", "FamilyNexus – Description des fonctions cryptographiques"),
}

CSS = """
@font-face{font-family:'Plex';src:url('%(f)s/IBMPlexSans-Variable.ttf');font-weight:100 700}
@font-face{font-family:'Grotesk';src:url('%(f)s/SpaceGrotesk-Variable.ttf');font-weight:300 700}
@font-face{font-family:'PlexMono';src:url('%(f)s/IBMPlexMono-Regular.ttf')}
@page{size:A4;margin:14mm 14mm 16mm 14mm}
*{box-sizing:border-box}
body{font:8.6pt/1.38 'Plex',sans-serif;color:#0f172a;margin:0}
h1,h2,h3{font-family:'Grotesk',sans-serif;color:#0f766e;margin:0 0 .35em}
h1{font-size:16pt;border-bottom:2px solid #2dd4bf;padding-bottom:.25em;margin-bottom:.5em}
h2{font-size:11pt;margin-top:1em;break-after:avoid}
h3{font-size:9.6pt;margin-top:.8em;break-after:avoid}
p{margin:.35em 0}
code{font-family:'PlexMono',monospace;font-size:.88em;background:#f1f5f9;padding:0 .2em;border-radius:2px}
table{border-collapse:collapse;width:100%%;margin:.5em 0;font-size:7.9pt}
th{background:#0f766e;color:#fff;text-align:left;font-family:'Grotesk',sans-serif;font-weight:500}
th,td{border:1px solid #cbd5e1;padding:2.5px 5px;vertical-align:top}
tr{break-inside:avoid}
tr:nth-child(even) td{background:#f8fafc}
ul,ol{margin:.3em 0;padding-left:1.3em}
li{margin:.1em 0}
em{color:#475569}
a{color:#0f766e}
"""


def build(name, lang, title):
    src = (DIR / name).read_text(encoding="utf-8")
    body = markdown.markdown(src, extensions=["tables", "sane_lists"])
    page = (
        f'<!doctype html><html lang="{lang}"><head><meta charset="utf-8">'
        f"<title>{html.escape(title)}</title><style>{CSS % {'f': FONTS.as_uri()}}</style>"
        f"</head><body>{body}</body></html>"
    )
    out = DIR / name.replace(".md", ".pdf")
    with tempfile.TemporaryDirectory() as tmp:
        f = pathlib.Path(tmp) / "doc.html"
        f.write_text(page, encoding="utf-8")
        subprocess.run(
            [CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
             f"--print-to-pdf={out}", f.as_uri()],
            check=True, capture_output=True, timeout=120,
        )
    print("geschrieben:", out.relative_to(ROOT))


if __name__ == "__main__":
    if not pathlib.Path(CHROME).exists():
        sys.exit("Google Chrome nicht gefunden: " + CHROME)
    for n, (lang, title) in DOCS.items():
        build(n, lang, title)
