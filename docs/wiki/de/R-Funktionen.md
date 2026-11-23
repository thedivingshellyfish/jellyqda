> 🌐 [English](../R-functions.md) · **Deutsch**

# R-Funktionen

Alles, was die App kann, geht auch per R-Code: praktisch für reproduzierbare
Auswertungen. Alle Funktionen geben **Tibbles** zurück. Ausführliche Hilfe zu
jeder Funktion: `?qda_code` usw. Eine kommentierte Vorlage liegt in
`inst/examples/jellyqda-vorlage.R` (englisch: `jellyqda-template.R`).

## Projekt

| Funktion | Zweck |
|---|---|
| `qda_open(path, auto_snapshot = 25)` | Projekt öffnen oder anlegen |
| `qda_close()` | Projekt schließen |
| `qda_project()` | Überblick: Datei, Größe, Anzahl Einträge |
| `qda_app(new_window = TRUE, lang = NULL)` | App starten (`lang = "de"` oder `"en"`) |
| `qda_language(lang)` | Sprache von App und Bericht abfragen/setzen |

## Dokumente

| Funktion | Zweck |
|---|---|
| `qda_import(files, segments = "blankline")` | txt/md/docx/pdf importieren und einfrieren |
| `qda_sources()` | alle Dokumente |
| `qda_view(source)` | Dokument mit Markierungen im Viewer |
| `qda_source_vars()` / `qda_source_set_var()` / `qda_source_del_var()` | Variablen |

## Segmente

| Funktion | Zweck |
|---|---|
| `qda_source_segments(source)` | Segmente eines Dokuments |
| `qda_segments_set(source, rule, pattern)` | neu einteilen: `"blankline"`, `"speaker"`, `"line"` |
| `qda_segment_split(source, at)` | Segment teilen |
| `qda_segment_merge(source, segment)` | mit dem nächsten zusammenführen |
| `qda_segment_define(source, start, end)` | eigenes Segment festlegen |
| `qda_segments_reset(source)` | zurück zu automatisch (Leerzeilen) |

## Codes und Codings

| Funktion | Zweck |
|---|---|
| `qda_codes()` | Codesystem (mit Pfad und Anzahl) |
| `qda_code_add(label, parent, color, description)` | Code anlegen |
| `qda_code_rename()` / `qda_code_move()` / `qda_code_delete()` | umbenennen, umhängen (Subcode machen), löschen |
| `qda_code_set_color(code, color)` | Farbe einer Code-Familie ändern |
| `qda_code(source, code, segment | start, end, memo)` | Code vergeben |
| `qda_codings(source, code)` | Codings mit Text |
| `qda_coding_set_memo(coding, memo)` | Kommentar setzen |
| `qda_coding_recode(coding, code)` | Coding umkodieren (z. B. auf einen Subcode) |
| `qda_coding_delete(coding)` | Coding löschen |
| `qda_coding_set_summary(coding, paraphrase, generalization)` | Mayring: Paraphrase, Generalisierung |
| `qda_code_guide(code, definition, anchor, rule)` | Kodierleitfaden eines Codes |
| `qda_code_merge(from, into)` | zwei Codes zusammenführen |
| `qda_autocode(pattern, code, scope)` | alle Fundstellen eines Begriffs codieren |
| `qda_words(source, code, n)` | Worthäufigkeiten |
| `qda_kwic(pattern, width)` | Stichwort im Kontext |
| `qda_case_matrix(by)` | Fallvergleich: Codes × Werte einer Variable |
| `qda_segments(code)` | alle Stellen eines Codes |

## Memos

| Funktion | Zweck |
|---|---|
| `qda_memo_add(text, source, start, end, code, title, kind)` | Memo anlegen (Art ergibt sich aus den Angaben) |
| `qda_memos(kind, source, code)` | Memos auflisten/filtern |
| `qda_memo_update(memo, text, title)` | bearbeiten |
| `qda_memo_delete(memo)` | löschen |

## Auswerten, Sichern, Verlauf

| Funktion | Zweck |
|---|---|
| `qda_stats()` | Fortschritt gesamt und je Dokument |
| `qda_matrix()` | Codes × Dokumente |
| `qda_summary_set()` / `qda_summaries()` | Summary Grid |
| `qda_export(what, path)` | `"segments"`, `"codings"`, `"codebook"`, `"audit"`, `"report"`, `"all"` |
| `qda_backup(path, keep = 10)` | ZIP-Backup |
| `qda_undo()` / `qda_redo()` / `qda_history()` | Rückgängig / Wiederholen |
| `qda_events()` | Protokoll |

## Beispiel: kompletter Ablauf

```r
library(jellyqda)
qda_open("meine-arbeit.jellyqda")
qda_import(list.files("transkripte", full.names = TRUE), segments = "speaker")

qda_code_add("Berufsweg", description = "Stationen des Werdegangs")
qda_code_add("KMU", parent = "Berufsweg")
qda_memo_add("Nur explizite Aussagen codieren", code = "KMU", title = "Kodierregel")

qda_code(source = 1, segment = 3, code = "KMU")
qda_segments("KMU")

library(dplyr)
qda_codings() |> count(code, source)      # Häufigkeiten
qda_export("all"); qda_backup()
```

## RStudio-Addins

Im RStudio-Menü **Addins** gibt es zwei Einträge für das geöffnete Projekt:
*jellyqda: Backup project* und *jellyqda: Show coding stats*.
