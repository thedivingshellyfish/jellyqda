#!/usr/bin/env python3
"""Baut die Zusatz-Tools der Projektseite aus src/ – je eine eigenständige HTML-Datei.

    cd website && python3 build.py

Assistenz:  src/shell-head.html + src/content.<lang>.js + src/app.js
Converter:  CSS aus src/shell-head.html + src/converter-body.html + src/converter.js
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"
read = lambda name: (SRC / name).read_text(encoding="utf-8")

head = read("shell-head.html")
app = read("app.js")
css_head = head[: head.index("</style>")]
conv_body, conv_js = read("converter-body.html"), read("converter.js")

PAGES = [
    # (Ausgabe, Sprache, Titel, Beschreibung, Art)
    ("de/assistenz/index.html", "de", "jellyqda Assistenz",
     "jellyqda-Assistenz: von der Interviewform über die Auswertungslogik bis zur fertigen Analyse in jellyqda – Schritt für Schritt.", "assist"),
    ("assistant/index.html", "en", "jellyqda Assistant",
     "jellyqda assistant: from interview type and analysis logic to a finished analysis in jellyqda, step by step.", "assist"),
    ("de/konverter/index.html", "de", "jellyqda Converter",
     "MAXQDA-, ATLAS.ti- oder NVivo-Projekte (REFI-QDA, .qdpx) in eine jellyqda-Projektdatei umwandeln – komplett im Browser, ohne Upload.", "conv"),
    ("converter/index.html", "en", "jellyqda Converter",
     "Convert MAXQDA, ATLAS.ti or NVivo projects (REFI-QDA, .qdpx) into a jellyqda project file – entirely in your browser, no upload.", "conv"),
]
for out, lang, title, desc, kind in PAGES:
    if kind == "assist":
        html = head + read(f"content.{lang}.js") + app
    else:
        html = css_head + conv_body + conv_js + "\n</script>\n</body>\n</html>\n"
    html = html.replace("@LANG@", lang).replace("@TITLE@", title).replace("@DESC@", desc)
    target = ROOT / out
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(html, encoding="utf-8")
    print(f"{out}: {len(html.encode()) // 1024} KB")
