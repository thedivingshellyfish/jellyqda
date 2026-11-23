> 🌐 [English](README.md) · **Deutsch**

[![R-CMD-check](https://github.com/thedivingshellyfish/jellyqda/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/thedivingshellyfish/jellyqda/actions/workflows/R-CMD-check.yaml)

# jellyqda

**Qualitative Inhaltsanalyse von Interviews in R & RStudio: kostenlos, komplett offline, ohne Cloud.**

<img src="docs/screenshots/de/01-uebersicht.png" alt="jellyqda: Dokumente, Codesystem, Dokument-Browser mit Codings, Memos und Summary Grid" width="1440">

jellyqda ist ein kleines Werkzeug für die **qualitative Analyse von Interviews
und Feldnotizen**, entstanden für eine Masterarbeit. Du importierst
Transkripte, baust ein Kategoriensystem auf (deduktiv aus dem Leitfaden
und/oder induktiv am Material), markierst Textstellen, schreibst Memos und
wertest aus. Alles läuft **lokal auf deinem Rechner**, in RStudio oder im
Browser.

- 🔒 **100 % offline:** keine Cloud, keine Uploads, DSGVO-freundlich. Ein Projekt ist **eine Datei** (`*.jellyqda`).
- 📄 **Import** von `.txt`, `.md`, `.docx` und `.pdf`. Der Text wird beim Import „eingefroren“, Codings verrutschen nie.
- 🌳 **Codebaum mit Codes und Subcodes:** ein- und ausklappbar, jede Code-Familie in einer Farbe, verbunden durch einen farbigen „Faden“. Umbenennen per Doppelklick, Löschen mit Rückfrage.
- 🏷️ **Kodieren mit der Maus:** Text markieren, Code anklicken, fertig. Subcodes klappen in der Kodier-Leiste aus; Umkodieren mit einem Klick. Überlappende Codings werden übersichtlich angezeigt.
- ✂️ **Segmente** nach Absätzen oder **Sprecherwechseln** (`[00:01:12] P: …`), frei anpassbar.
- 📝 **Memos** in vier Arten: Textstelle, Dokument, Code (Definition, Kodierregel), Projekt.
- 🔬 **Deduktiv und induktiv:** Kodierleitfaden (Definition, Ankerbeispiel, Kodierregel), In-vivo-Codes, Codes zusammenführen, alle Suchtreffer auf einmal codieren, **Zusammenfassung nach Mayring** (Paraphrase → Generalisierung → Reduktion).
- 📊 **Auswerten:** Codings je Code, Volltextsuche, Code-Matrix mit **Fallvergleich**, Worthäufigkeiten, Stichwort im Kontext, Summary Grid, Export (CSV, Excel, Word).
- 🖨️ **Bericht** im eigenen Browser-Tab, druckfertig auf **A4** (ohne Hintergrundfarben), mit Häufigkeiten in Prozent und einer **Randspalte** neben jedem Interview: welche Codings, Kommentare und Memos an welcher Stelle stehen.
- ↩️ **Rückgängig/Wiederholen** für alles (Strg+Z / Strg+Y) und ein lückenloses **Protokoll** für den Methodenteil.
- 🌙 **Dark Mode**, gut lesbar (geprüfter Kontrast).
- 🌐 **Deutsch und Englisch:** Oberfläche und Bericht in beiden Sprachen, umschaltbar per Klick (**DE/EN**).

> 🆕 **Neu in Version 0.7.0:** Oberfläche und Bericht auf **Deutsch und Englisch**
> (Umschalter **DE/EN**), Paket bereit für CRAN (lauffähige Beispiele, Vignette).
> **0.6.0:** Bericht mit Randspalte (Codings und Memos neben dem
> Interview), Kommentarfeld in der Coding-Leiste, In-vivo-Codes, Codes zusammenführen,
> Suchtreffer codieren, Kodierleitfaden, Fallvergleich, Worthäufigkeiten,
> Stichwort im Kontext und Zusammenfassung nach Mayring.
> **0.5.0:** Codebaum mit Subcodes, zweistufige Kodier-Leiste, Umkodieren, Speichern (Strg+S),
> Bericht im neuen Tab. Alle Änderungen: [NEWS.md](NEWS.md).

**Ausführliche Anleitung mit Screenshots zu allen Funktionen:**
[📖 Wiki](docs/wiki/de/Home.md) (Ordner `docs/wiki/de/`)

---

## Installation (einmalig, ca. 5 Minuten)

**Voraussetzung:** [R](https://cran.r-project.org) ab Version 4.0, am besten
mit [RStudio](https://posit.co/download/rstudio-desktop/). Beides ist kostenlos.

Öffne R oder RStudio und kopiere diese **eine Zeile** in die Konsole:

```r
source("https://raw.githubusercontent.com/thedivingshellyfish/jellyqda/main/install_jellyqda.R")
```

Das Skript installiert alle benötigten Pakete, dann jellyqda, prüft die
Installation und sagt dir am Ende, wie es weitergeht. Bei Problemen gibt es
eine konkrete Anleitung aus, z. B. welcher Befehl unter Linux fehlende
Systembibliotheken für den PDF-Import nachinstalliert.

<details>
<summary><b>Andere Wege</b> (ZIP-Datei, bestimmte Version, ohne Skript)</summary>

```r
# aus einer heruntergeladenen ZIP-Datei (z. B. von der Releases-Seite):
options(jellyqda.install.path = "~/Downloads/jellyqda.zip")
source("https://raw.githubusercontent.com/thedivingshellyfish/jellyqda/main/install_jellyqda.R")

# eine bestimmte Version / einen Branch:
options(jellyqda.install.ref = "main")

# danach direkt eine Demo mit Beispiel-Interview starten:
options(jellyqda.install.start_app = TRUE)

# ganz ohne Skript, aus einem entpackten Ordner:
install.packages(c("DBI", "RSQLite", "digest", "htmltools", "jsonlite", "officer", "pdftools",
                   "readr", "stringi", "tibble", "zip", "shiny", "bslib", "fontawesome",
                   "writexl"))
install.packages("pfad/zu/jellyqda", repos = NULL, type = "source")
```

**Linux:** Für den PDF- und Word-Import braucht R einmalig Systembibliotheken,
unter Ubuntu/Debian z. B.
`sudo apt install libpoppler-cpp-dev libxml2-dev libssl-dev libcurl4-openssl-dev libfontconfig1-dev`.
Das Installationsskript nennt den passenden Befehl für deine Distribution.
</details>

---

## Los geht's in 3 Schritten

```r
library(jellyqda)
qda_open("meine-arbeit.jellyqda")   # 1. Projekt anlegen (oder später wieder öffnen)
qda_app()                           # 2. App starten: öffnet sich im Browser
                                    #    (qda_app(lang = "de") = deutsche Oberfläche)
```

3. In der App links bei **Dokumente** deine Transkripte importieren (oder
   per Drag & Drop hineinziehen), im **Code System** mit **„+ Code“** erste
   Codes anlegen (und mit **„+ Subcode“** darunter), im Text markieren und auf
   einen Code klicken.

Beenden: rotes **X** oben rechts (speichert Export + Backup) oder `Esc` in der
R-Konsole. Gespeichert wird ohnehin **sofort bei jeder Aktion**.

> 💡 **Ausprobieren ohne eigene Daten:**
> `qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))`
> oder die fiktiven Transkripte aus dem Ordner [`demo/`](demo/) (mit Zeitmarken, ideal für
> Segmente nach Sprecherwechsel).

---

## So sieht die Arbeit aus

**Codebaum:** Ein Code (oberste Ebene) ist voll gefärbt, seine Subcodes tragen
nur einen Rahmen in derselben Farbe und hängen an einer Linie, dem „Faden“.
Pfeil = ein-/ausklappen, **„+ Subcode“** an jeder Zeile, **Doppelklick** =
umbenennen, Papierkorb = löschen (mit Rückfrage), Farbpunkt = Farbe der ganzen
Code-Familie. „Σ“ zählt die Codings inklusive aller Subcodes.

<table>
<tr>
<td width="33%" valign="top"><img src="docs/screenshots/de/05-codesystem.png" alt="Codebaum mit Codes und Subcodes" width="290"></td>
<td width="33%" valign="top"><img src="docs/screenshots/de/22-code-umbenennen.png" alt="Umbenennen per Doppelklick" width="290"></td>
<td width="33%" valign="top"><img src="docs/screenshots/de/21-code-loeschen.png" alt="Löschen mit Rückfrage" width="290"></td>
</tr>
</table>

**Kodieren:** Text markieren, dann erscheint die Kodier-Leiste. Ein Klick auf
einen Code mit Subcodes klappt diese am Faden aus; **„(nur Code)“** vergibt den
Code selbst. Per Tastatur: **Strg+1…9** wählt den Code, danach **1…9** den
Subcode (**0** = nur der Code). Das Suchfeld findet jeden Code über seinen Pfad,
**Enter** ohne Treffer legt einen neuen Code an. Beim Überfahren erscheint die
Definition aus dem Code-Memo. Solange Text markiert ist, kodiert auch ein Klick
in den Codebaum.

<img src="docs/screenshots/de/06-markieren-aktionsleiste.png" alt="Markierter Text mit Kodier-Leiste" width="798">

**Coding anklicken:** Die Leiste zeigt alle Codes derselben Familie zum
**Umkodieren** (aus „Berufsweg“ wird mit einem Klick „Berufsweg › KMU“), ein
Feld für den **Kommentar**, die Mayring-Felder **Paraphrase** und
**Generalisierung** und „**Als Ankerbeispiel**“ für den Kodierleitfaden.
Subcode-Codings sind im Text hell getönt, unterstrichen und tragen ein kleines
Etikett.

<img src="docs/screenshots/de/08-coding-leiste.png" alt="Coding-Leiste mit Umkodieren" width="798">

**Überlappungen:** Stellen mit mehreren Codings sind grau mit einer Zahl.
Fährst du mit der Maus darüber, siehst du alle Codings dieser Stelle.

<img src="docs/screenshots/de/07-ueberlappung-popover.png" alt="Popover bei überlappenden Codings" width="1199">

<table>
<tr>
<td width="50%" valign="top"><b>Memos</b> in vier Arten, mit Filter und Suche<br><img src="docs/screenshots/de/10-memos.png" alt="Memo-Panel" width="298"></td>
<td width="50%" valign="top"><b>Summary Grid</b>: Zusammenfassung je Code und Dokument<br><img src="docs/screenshots/de/16-summary-grid.png" alt="Summary Grid" width="298"></td>
</tr>
</table>

**Segmente** nach Sprecherwechseln; teilen und zusammenführen mit einem Klick in den Text:

<img src="docs/screenshots/de/09-segmentleiste.png" alt="Segment-Leiste" width="798">

**Analysieren** (deduktiv und induktiv): Kodierleitfaden (Buch-Symbol am
Code), **In vivo** in der Kodier-Leiste, Codes **zusammenführen**
(Pfeil-Symbol), **alle Suchtreffer codieren**, **Fallvergleich** in der
Code-Matrix und das Fenster **Analyse** mit Worthäufigkeiten, Stichwort im
Kontext und der Mayring-Tabelle. Anleitung: [Wiki: Analysieren](docs/wiki/de/Analysieren.md).

<table>
<tr>
<td width="50%" valign="top"><img src="docs/screenshots/de/26-kodierleitfaden.png" alt="Kodierleitfaden" width="420"></td>
<td width="50%" valign="top"><img src="docs/screenshots/de/32-mayring.png" alt="Zusammenfassung nach Mayring" width="420"></td>
</tr>
<tr>
<td valign="top"><img src="docs/screenshots/de/31-stichwort-im-kontext.png" alt="Stichwort im Kontext" width="420"></td>
<td valign="top"><img src="docs/screenshots/de/29-fallvergleich.png" alt="Fallvergleich" width="250"></td>
</tr>
</table>

**Symbolleiste:** **Speichern** (Strg+S, legt zusätzlich einen Sicherungspunkt
an), Rückgängig/Wiederholen, **Bericht** (öffnet einen neuen Tab), **Analyse** und das
**Export**-Menü (alles exportieren, Codebuch, Bericht als Datei, Backup,
Layout zurücksetzen).

<img src="docs/screenshots/de/23-symbolleiste-export.png" alt="Symbolleiste mit Export-Menü" width="920">

**Bericht:** öffnet sich in einem neuen Tab und ist für den Druck auf A4
gemacht (Strg+P, auch als PDF): Codesystem mit Häufigkeiten je Dokument und
**Anteil in Prozent**, Codebuch, Memos, codierte Textstellen und alle Dokumente
mit Markierungen. Neben jedem Interview steht eine **Randspalte**: Jedes Coding
trägt im Text eine Nummer, am Rand hängt unter derselben Nummer an einem
farbigen Faden ein Kärtchen mit Code, Kommentar und Paraphrase (Memos als
M1, M2 …). Farben stehen nur in Linien und Rahmen, deshalb braucht der
Druck keine Hintergrundgrafiken.

<table>
<tr>
<td width="55%" valign="top"><img src="docs/screenshots/de/19-html-bericht.png" alt="Bericht im Browser" width="520"></td>
<td width="45%" valign="top"><img src="docs/screenshots/de/33-bericht-randspalte-a4.png" alt="Bericht mit Randspalte als A4-PDF" width="400"></td>
</tr>
</table>

**Dark Mode** (Mond-Symbol oben rechts):

<img src="docs/screenshots/de/02-uebersicht-dark.png" alt="Dark Mode" width="1440">

Alle Funktionen Schritt für Schritt im **[Wiki](docs/wiki/de/Home.md)**:
[Erste Schritte](docs/wiki/de/Erste-Schritte.md) ·
[Dokumente](docs/wiki/de/Dokumente-importieren.md) ·
[Kodieren](docs/wiki/de/Kodieren.md) ·
[Segmente](docs/wiki/de/Segmente.md) ·
[Memos](docs/wiki/de/Memos.md) ·
[Analysieren](docs/wiki/de/Analysieren.md) ·
[Auswerten & Export](docs/wiki/de/Auswerten-und-Export.md) ·
[Rückgängig & Sicherheit](docs/wiki/de/Rueckgaengig-und-Datensicherheit.md) ·
[R-Funktionen](docs/wiki/de/R-Funktionen.md) ·
[Tastenkürzel](docs/wiki/de/Tastenkuerzel.md) ·
[Hilfe bei Problemen](docs/wiki/de/Hilfe-bei-Problemen.md)

---

## Tastenkürzel

| Kürzel | Wirkung |
|---|---|
| **Strg+1 … 9** | Text markiert: 1.–9. Code der Kodier-Leiste (kodiert oder klappt die Subcodes aus) |
| **1 … 9 / 0** | danach: Subcode wählen / nur den Code vergeben (**Esc** klappt zu) |
| **Doppelklick / F2** | Code im Codebaum umbenennen |
| **Strg+S** | Speichern + Sicherungspunkt |
| **Strg+M** | Textstellen-Memo zur Markierung |
| **Strg+Z / Strg+Y** | Rückgängig / Wiederholen |
| **Strg+Enter** | Memo speichern (im Memo-Feld) |
| **Esc** | Überlappungs-Liste schließen, Eingabe abbrechen |

Auf dem Mac jeweils **Cmd** statt Strg.

---

## Deine Daten

- Ein Projekt ist **eine Datei** (`meine-arbeit.jellyqda`, SQLite). Daneben
  liegen `originals/` (unveränderte Originaldateien) und `exports/`.
- **Gespeichert wird sofort** bei jeder Aktion. **Speichern** (Strg+S) schreibt
  die Datei zusätzlich fest und legt einen Sicherungspunkt an.
- **Backups:** Button „Speichern“, „Backup anlegen“ im Export-Menü bzw. `qda_backup()`, außerdem automatisch alle
  25 Aktionen, als ZIP in `jellyqda-backups/` *außerhalb* des Projektordners.
  Die letzten 10 werden behalten.
- **Protokoll:** Jede Aktion wird mit Zeitstempel festgehalten
  (`qda_export("audit")`), praktisch für den Methodenteil.
- jellyqda baut **keine Netzwerkverbindung** auf; die App läuft nur auf
  `127.0.0.1` (dein eigener Rechner). Das wird in den Tests geprüft.
- **Interviewdaten gehören nicht in Git:** Die `.gitignore` schließt
  `*.jellyqda`, `originals/`, `exports/` und Backups aus.

---

## Auch ohne App: per R-Skript

Alles, was die App kann, geht auch als R-Code, praktisch für
reproduzierbare Auswertungen. Eine kommentierte Vorlage liegt in
[`inst/examples/jellyqda-vorlage.R`](inst/examples/jellyqda-vorlage.R)
(englisch: [`jellyqda-template.R`](inst/examples/jellyqda-template.R)).

```r
library(jellyqda)
qda_open("meine-arbeit.jellyqda")
qda_import(c("interview_01.docx", "interview_02.txt"), segments = "speaker")
qda_code_add("Berufsweg"); qda_code_add("KMU", parent = "Berufsweg")
qda_code(source = 1, segment = 3, code = "KMU", memo = "5 Jahre KMU")   # ganzes Segment
qda_code(source = 1, start = 120, end = 340, code = "Berufsweg")      # Zeichenbereich
qda_coding_recode(2, "KMU")   # Coding umkodieren (z. B. auf einen Subcode)
qda_code_set_color("Berufsweg", "#E69F00")   # Farbe der ganzen Code-Familie
qda_code_guide("KMU", definition = "...", rule = "...")   # Kodierleitfaden
qda_autocode("Kollegen", code = "Teamklima", scope = "segment")
qda_words(n = 30); qda_kwic("Familie"); qda_case_matrix("Rolle")
qda_memo_add("Nur explizite Aussagen codieren", code = "KMU", title = "Kodierregel")
qda_segments("KMU")      # alle Textstellen eines Codes (Tabelle)
qda_matrix()             # Codes × Dokumente
qda_stats()              # Fortschritt: wie viel ist codiert?
qda_export("all")        # CSV/Excel/Word/HTML nach exports/
qda_backup()
```

Alle Funktionen: [Wiki: R-Funktionen](docs/wiki/de/R-Funktionen.md) bzw. `?qda_code` usw. in R
(die Hilfeseiten in R sind englisch).

---

## Für Entwickler:innen

<details>
<summary><b>Aufbau des Projekts</b></summary>

```
jellyqda/
├── DESCRIPTION / LICENSE / CITATION   # Paket-Metadaten (MIT)
├── install_jellyqda.R                 # Installationsskript (siehe oben)
├── R/                                 # R-Code, eine Datei pro Thema:
│   ├── open.R / schema.R / utils.R    #   Projekt öffnen, DB-Schema, Hilfsfunktionen
│   ├── import.R / sources.R           #   Import + Einfrieren, Dokumente + Variablen
│   ├── segments.R                     #   Segmente (Regeln, teilen, zusammenführen)
│   ├── codes.R / coding.R / memos.R   #   Codesystem, Codings, Memos (4 Arten)
│   ├── render.R / view.R              #   Text mit Markierungen als HTML (App, Bericht, Viewer)
│   ├── history.R / undo.R / events.R  #   Rückgängig/Wiederholen, Protokoll
│   ├── summary.R / stats.R            #   Summary Grid, Statistik, Matrix
│   ├── analysis.R                     #   Leitfaden, Zusammenführen, Auto-Codieren, Mayring, Wörter, KWIC, Fallvergleich
│   ├── export.R / backup.R            #   Export + HTML-Bericht, ZIP-Backups
│   ├── app.R                          #   Shiny-App qda_app(): UI + Server
│   ├── i18n.R / i18n_catalog.R        #   Sprache (Deutsch/Englisch) + englische Übersetzungen
│   └── addins.R                       #   RStudio-Addins (Backup, Statistik)
├── inst/app/www/jellyqda.css|js       # Aussehen + Browser-Logik der App (kommentiert)
├── inst/extdata/                      # Beispieldaten (fiktiv)
├── inst/examples/                     # kommentierte Vorlagen (deutsch + englisch)
├── vignettes/                         # Einführung (englisch)
├── tests/testthat/                    # Tests (testthat 3)
└── docs/                              # Screenshots + Wiki (englisch; deutsch in de/)
```

**Architektur in einem Absatz:** Eine SQLite-Datei pro Projekt enthält alles
(Tabellen `sources`, `codes`, `codings`, `memos`, `segments`, `summaries`,
`events`, siehe `R/schema.R`). Der Text wird beim Import in
`sources.frozen_text` eingefroren; Codings, Textstellen-Memos und Segmente sind
1-basierte Zeichenpositionen in diesem Text. Die `qda_*()`-Funktionen lesen
und schreiben nur diese Datenbank und geben Tibbles zurück; die App ist eine
dünne Schicht darüber. Jede Änderung landet mit einem Vorher/Nachher-Schnappschuss
in `events`; daraus entstehen Protokoll-Export, Rückgängig und Wiederholen.
Wichtigste Regel (getestet): Der im Browser angezeigte Text ist **Zeichen für
Zeichen** identisch mit dem eingefrorenen Text, sonst würden Markierungen an
falscher Stelle gespeichert.
</details>

<details>
<summary><b>Aussehen anpassen</b></summary>

| Was | Wo |
|---|---|
| Farben, Schriften, Abstände, Dark Mode | `inst/app/www/jellyqda.css` (Abschnitte 1–7; Dark-Mode-Farbpalette als CSS-Variablen) |
| Verhalten im Browser (Markieren, Klicks, Tastenkürzel, Popover, Layout) | `inst/app/www/jellyqda.js` (Abschnitte 1–14) |
| Hauptfarbe + Schriftgröße | `bslib::bs_theme(primary = "#2c6fbb", font_scale = 0.82)` in `.jellyqda_ui()` (`R/app.R`) |
| Beschriftungen | deutsch in `R/app.R` als `.t("…")`, englisch in `R/i18n_catalog.R` (ein Test prüft, dass jede Beschriftung übersetzt ist) |
| Icons im vom Server erzeugten HTML | `<i class="fa-solid fa-NAME">`, Name in `.jq_icon_names()` eintragen (ein Test prüft das) |
| Code-Farben | in der App beim Anlegen oder `qda_code_add(color = "#...")` |

Nach Änderungen: Paket neu installieren (`devtools::install()`) und R neu starten.
</details>

<details>
<summary><b>Tests & Entwicklung</b></summary>

```r
pkgload::load_all(".")          # Entwicklungsversion laden
testthat::test_local(".")       # alle Tests (inkl. Offline-Garantie)
```

Fiktive Beispiel-Interviews (10, 30, 60 und 120 Minuten, mit Zeitmarken) liegen
in `demo/`, gut zum Ausprobieren von Import, Segmenten und Kodieren.

`R CMD check --as-cran` läuft bei jedem Push (GitHub Actions). R-Code muss ASCII
bleiben (Umlaute als `\u00e4` usw.). Kommentare im Code sind englisch. Siehe `CONTRIBUTING.md`.
</details>

---

## Lizenz & Zitieren

MIT-Lizenz, siehe [LICENSE.md](LICENSE.md). Frei nutzbar, veränderbar und teilbar.
Wenn du jellyqda in einer wissenschaftlichen Arbeit verwendest, zitiere es bitte:
`citation("jellyqda")` (siehe [CITATION](https://github.com/thedivingshellyfish/jellyqda/blob/main/inst/CITATION)).
