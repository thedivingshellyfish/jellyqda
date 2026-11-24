#!/usr/bin/env python3
"""Baut die jellyqda-Assistenz (DE + EN) aus src/ zu je einer eigenständigen HTML-Datei.

    python3 build.py

src/shell-head.html  Kopf + CSS (gemeinsam)
src/content.de.js    deutsche Inhalte und Texte
src/content.en.js    englische Inhalte und Texte
src/app.js           Logik (gemeinsam)
"""
from pathlib import Path

ROOT = Path(__file__).parent
PAGES = {
    "de": ("website/de/assistenz/index.html", "jellyqda Assistenz",
           "jellyqda-Assistenz: von der Interviewform über die Auswertungslogik bis zur fertigen Analyse in jellyqda – Schritt für Schritt."),
    "en": ("website/assistant/index.html", "jellyqda Assistant",
           "jellyqda assistant: from interview type and analysis logic to a finished analysis in jellyqda, step by step."),
}
head = (ROOT / "src/shell-head.html").read_text(encoding="utf-8")
app = (ROOT / "src/app.js").read_text(encoding="utf-8")
for lang, (out, title, desc) in PAGES.items():
    content = (ROOT / f"src/content.{lang}.js").read_text(encoding="utf-8")
    html = (head.replace("@LANG@", lang).replace("@TITLE@", title).replace("@DESC@", desc)
            + content + app)
    target = ROOT / out
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(html, encoding="utf-8")
    print(f"{out}: {len(html.encode()) // 1024} KB")
