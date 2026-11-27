> 🌐 [English](../Evaluation-and-export.md) · **Deutsch**

# Auswerten & Export

## Alle Stellen eines Codes

Einen Code im **Codesystem anklicken**: Das Panel **Codings** zeigt alle
Stellen mit diesem Code aus allen Dokumenten, mit Kommentaren. Ein Klick auf
eine Zeile springt zur Stelle im Text.

<img src="../../screenshots/de/13-codings-eines-codes.png" alt="Codings eines Codes" width="802">

Mit **„Nur Dokumente mit Variable“** schränkst du auf Dokumente mit einem
bestimmten Merkmal ein, z. B. `Rolle=Projektleitung`.

## Volltextsuche im ganzen Projekt

Suchbegriff eingeben, **Suchen**. Jeder Treffer zeigt Dokument, Position und
Umgebung; ein Klick springt hin.

<img src="../../screenshots/de/14-suche.png" alt="Suche" width="802">

## Code-Matrix

Wie oft kommt welcher Code in welchem Dokument vor? Je kräftiger das Blau,
desto häufiger. Ein **Klick auf eine Zelle** öffnet das Dokument und zeigt
die Codings dieses Codes.

<img src="../../screenshots/de/15-code-matrix.png" alt="Code-Matrix" width="298">

## Summary Grid

Für die fallbezogene Zusammenfassung: Ein **Klick auf eine Zelle**
(Code × Dokument) zeigt die zugehörigen Textstellen und ein Feld für deine
Zusammenfassung. **Summary speichern**. Zellen mit Zusammenfassung sind gelb hinterlegt.

<img src="../../screenshots/de/16-summary-grid.png" alt="Summary Grid" width="298">

## Export

Menü **Export ▾** oben → **Alles exportieren** (oder `qda_export("all")`): Alles landet im Ordner
`exports/` neben der Projektdatei.

| Was | Datei(en) | Inhalt |
|---|---|---|
| `segments` | CSV + Excel (`.xlsx`) | alle Codings mit Text, Code, Dokument, Kommentar |
| `codings` | CSV | Codings-Tabelle (Positionen) |
| `codebook` | CSV + Word (`.docx`) | das Codesystem in Baum-Reihenfolge, mit Ebene, Beschreibung und Code-Memos |
| `audit` | CSV | das vollständige Protokoll aller Aktionen |
| `report` | HTML | Bericht (A4): Häufigkeiten mit Anteil in %, Codebuch, Memos, codierte Textstellen, alle Dokumente mit Markierungen |

```r
qda_export("all")
qda_export(c("segments", "codebook"))
qda_export("audit")      # für den Methodenteil
```

### Bericht (A4, druckfertig)

Button **Bericht** oben öffnet *(seit 0.9.1)* einen kleinen Dialog mit zwei
Möglichkeiten und der Dauer für Ihr Projekt:

- **Übersicht**: Codesystem, Grafiken, Codebuch, Memos, codierte
  Textstellen, Intercoder-Übereinstimmung – ohne die Dokumente. Auch bei
  großen Projekten in wenigen Sekunden fertig.
- **Vollständig (A4)**: dazu alle Dokumente mit Markierungen und Randspalte.

Ab 50 Dokumenten ist die Übersicht vorausgewählt. **Bericht erstellen** zeigt
einen **Fortschrittsbalken** („Dokument 87 von 150 …“), danach öffnet sich der
Bericht in einem **neuen Browser-Tab**, in der Sprache der Oberfläche. Bewegt
sich eine Minute lang nichts, fragt der Dialog, ob Sie **weiter warten** oder
**zurück** möchten (das Ergebnis wird dann verworfen; R erstellt den Bericht im
Hintergrund zu Ende, unterbrechen lässt es sich nicht).

<table>
<tr>
<td width="50%" valign="top"><img src="../../screenshots/de/41-bericht-dialog.png" alt="Bericht-Dialog: Übersicht oder vollständig" width="420"></td>
<td width="50%" valign="top"><img src="../../screenshots/de/42-bericht-fortschritt.png" alt="Bericht-Dialog mit Fortschrittsbalken" width="420"></td>
</tr>
</table>

Als Datei speichern: **Export ▾ → Bericht als HTML-Datei speichern** (ebenfalls
mit Fortschrittsbalken) bzw. `qda_export("report")`; für die Übersicht
`qda_export("report", report_documents = FALSE)`. Die Datei lässt sich ohne
jellyqda in jedem Browser öffnen und weitergeben.

Arbeitet die App an etwas, das länger als einen Moment dauert, erscheint
unten im Fenster ein kleines **„Wird verarbeitet …“**.

Der Bericht ist für **A4** gemacht: **Strg+P** druckt ihn oder speichert ihn als
PDF, mit Seitenzahlen. Farben stehen nur in Linien, Rahmen und Unterstreichungen,
nie als Hintergrundfläche, deshalb muss beim Drucken die Option
„Hintergrundgrafiken“ **nicht** eingeschaltet werden.

1. **Codesystem und Häufigkeiten:** jeder Code und Subcode je Dokument, Summe
   und **Anteil in Prozent** an allen Codings (mit Balken). Codes zählen ihre
   Subcodes mit; die Codes der obersten Ebene ergeben zusammen 100 %. Bei
   vielen oder langen Dokumentnamen heißen die Spalten D1, D2 … mit Legende.
2. **Codebuch:** Definitionen (Beschreibung und Code-Memos).
3. **Memos**, nach Art gruppiert.
4. **Codierte Textstellen**, nach Codes geordnet.
5. **Fallvergleich** (wenn Dokument-Variablen gesetzt sind) und
   **Zusammenfassung nach Mayring** (wenn Paraphrasen eingetragen sind).
6. **Dokumente mit Markierungen und Randspalte:** Der Text ist schmaler,
   Codings sind unterstrichen in der Farbe der Code-Familie (Subcodes
   gestrichelt mit Etikett, Überlappungen gepunktet) und tragen am Anfang
   eine **Nummer**. Rechts am Rand steht unter derselben Nummer, an einem
   farbigen Faden: Code-Pfad, Kommentar und Paraphrase; Textstellen-Memos
   als „M1, M2 …“. Zugeordnet wird nach dem Segment, in dem ein Coding
   beginnt, so bleibt der Bezug auch über Seitenumbrüche klar.

<img src="../../screenshots/de/33-bericht-randspalte-a4.png" alt="Bericht mit Randspalte (A4)" width="600">

<img src="../../screenshots/de/19-html-bericht.png" alt="HTML-Bericht" width="1100">

<img src="../../screenshots/de/19b-html-bericht-dokument.png" alt="HTML-Bericht: Dokument" width="1100">

<img src="../../screenshots/de/24-bericht-a4-druck.png" alt="Bericht als A4-PDF" width="455">

## Austausch mit anderer QDA-Software (REFI-QDA, .qdpx)

*Neu in Version 0.9.0.* **Export → REFI-QDA (.qdpx)** schreibt das ganze
Projekt in eine `.qdpx`-Datei im offenen Austauschformat der qualitativen
Datenanalyse. **MAXQDA, ATLAS.ti, NVivo, QualCoder** und andere Programme
können sie importieren. So können Sie woanders weiterarbeiten, mit Kolleg*innen
mit anderer Software zusammenarbeiten oder das Projekt in einem offenen
Format archivieren.

| Enthalten | Nicht enthalten (im Format nicht vorgesehen) |
|---|---|
| Dokumente (Text), Codesystem mit Farben, Kodierleitfaden (in der Code-Beschreibung), Codings mit Kommentar und Mayring-Feldern, alle Memos, Dokument-Variablen | Segmente, Summary Grid, Audit-Trail |

In R: `qda_export_qdpx()` oder `qda_export("qdpx")`. Die Datei landet in
`exports/`. Der Export ist gegen das offizielle REFI-QDA-Projektschema
(QDA-XML 1.0) geprüft.

## Kennzahlen und Tabellen in R

```r
qda_stats()          # Quellen, Codes, Codings, Memos, % codiert (gesamt + je Dokument)
qda_matrix()         # Codes × Dokumente als Tabelle
qda_segments("KMU")  # alle Stellen eines Codes als Tabelle
qda_summaries()      # alle Zusammenfassungen
qda_view(1)          # Dokument mit Markierungen im RStudio-Viewer
```

<img src="../../screenshots/de/20-qda-view.png" alt="qda_view im Viewer" width="1100">

Alle Funktionen geben **Tibbles** zurück, ideal zum Weiterrechnen mit dplyr,
ggplot2 usw.
