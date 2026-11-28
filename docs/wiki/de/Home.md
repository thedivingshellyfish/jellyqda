> 🌐 [English](../Home.md) · **Deutsch**

# jellyqda Wiki

**jellyqda** ist ein kleines, kostenloses Werkzeug für die **qualitative Analyse
von Interviews** in R und RStudio: komplett offline, ohne Cloud. Dieses Wiki
erklärt alle Funktionen Schritt für Schritt mit Screenshots.

<img src="../../screenshots/de/01-uebersicht.png" alt="Überblick über die App" width="1440">

## Für den Einstieg

1. **[Installation](Installation.md):** einmalig, eine Zeile in R
2. **[Erste Schritte](Erste-Schritte.md):** Projekt anlegen, App starten, erstes Interview kodieren
3. **[Die Oberfläche](Die-Oberflaeche.md):** was wo ist, Layout anpassen, Dark Mode

## Arbeiten mit jellyqda

| Thema | Worum es geht |
|---|---|
| [Dokumente importieren](Dokumente-importieren.md) | Transkripte laden (txt, md, docx, pdf), offene Antworten aus Fragebögen (CSV, Excel), Pseudonymisieren beim Import, Variablen wie Alter oder Rolle |
| [Kodieren](Kodieren.md) | Codesystem aufbauen, Text markieren, Codes vergeben, Überlappungen |
| [Segmente](Segmente.md) | Absätze oder Sprecherwechsel, Segmente teilen und zusammenführen |
| [Memos](Memos.md) | Textstellen-, Dokument-, Code- und Projekt-Memos, Kommentare |
| [Analysieren](Analysieren.md) | Kodierleitfaden, In vivo, Codes zusammenführen, Suchtreffer codieren, Fallvergleich, Worthäufigkeiten, Stichwort im Kontext, Mayring, Abfragen (UND / ODER / NICHT) |
| [Intercoder-Übereinstimmung](Intercoder-Uebereinstimmung.md) | Blind-Kopie für eine zweite Person, Cohens Kappa, Krippendorffs Alpha, Abweichungen und Konsens |
| [Grafiken](Grafiken.md) | Code-Überschneidungen (Heatmap), Code-Netzwerk, Dokument-Portraits |
| [Fälle](Faelle.md) | Fälle unabhängig von Dokumenten: mehrere Interviews je Person, die Teilnehmenden eines Gruppeninterviews, Fallvariablen, Fälle vergleichen |
| [Teamarbeit](Teamarbeit.md) | das Kodieren im Team aufteilen und die Kopien wieder zu einem Projekt zusammenführen |
| [Auswerten & Export](Auswerten-und-Export.md) | Codings je Code, Suche, Code-Matrix, Summary Grid, Export, HTML-Bericht |
| [Rückgängig & Datensicherheit](Rueckgaengig-und-Datensicherheit.md) | Strg+Z/Strg+Y, Protokoll, Backups, Datenschutz |

## Nachschlagen

- [Tastenkürzel](Tastenkuerzel.md)
- [R-Funktionen](R-Funktionen.md): alles auch per Skript
- [Hilfe bei Problemen](Hilfe-bei-Problemen.md)

## Die Idee in drei Sätzen

Ein Projekt ist **eine einzige Datei** (`meine-arbeit.jellyqda`) auf deinem
Rechner. Beim Import wird der Text **eingefroren**; alle Codings und Memos
merken sich die genaue Zeichenposition und verrutschen nie. Jede Aktion wird
mit Zeitstempel protokolliert und kann rückgängig gemacht werden.
