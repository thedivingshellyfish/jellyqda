# Hilfe bei Problemen

### Die Installation bricht ab: „Keine Verbindung zum Paket-Server“

Internetverbindung prüfen; an der Uni ggf. Proxy oder VPN. Anderen Server versuchen:

```r
options(repos = c(CRAN = "https://cran.r-project.org"))
source("https://raw.githubusercontent.com/thedivingshellyfish/jellyqda/main/install_jellyqda.R")
```

### „Diese Pakete konnten nicht installiert werden: pdftools …“ (Linux)

Es fehlen Systembibliotheken. Das Installationsskript zeigt den passenden
Befehl; für Ubuntu/Debian im **Terminal**:

```bash
sudo apt install libpoppler-cpp-dev libxml2-dev libssl-dev libcurl4-openssl-dev libfontconfig1-dev
```

### Nach einem Update fehlen neue Funktionen

Eine alte Version ist noch geladen. In RStudio **Session → Restart R**, dann
`library(jellyqda)`. Prüfen: Das Installationsskript zeigt unter *[4/5]*,
ob alles da ist.

### „No jellyqda project is open“

Vor `qda_app()` bzw. anderen Funktionen zuerst `qda_open("datei.jellyqda")` aufrufen.

### Die App öffnet sich nicht / leeres Fenster

Die Adresse steht in der R-Konsole (`jellyqda app (lokal, offline): http://127.0.0.1:…`),
einfach im Browser öffnen. Läuft noch eine alte App? In der Konsole `Esc`, dann neu starten.

### Die R-Konsole reagiert nicht mehr

Solange die App läuft, ist die Konsole belegt. App beenden: rotes **X** in der
App oder `Esc` in der Konsole.

### Ein PDF zeigt kaum Text (Warnung beim Import)

Das PDF ist vermutlich ein Scan ohne Textebene. Vorher mit einer OCR-Software
(z. B. Tesseract) in ein durchsuchbares PDF oder `.txt` umwandeln und neu importieren.

### Umlaute sehen falsch aus

`.txt`-Dateien werden automatisch erkannt (UTF-8, Latin-1 …). Falls doch etwas
schiefgeht: die Datei im Editor als **UTF-8** speichern und neu importieren
(bereits importierte Texte ändern sich nicht).

### Ich habe aus Versehen etwas gelöscht

**Strg+Z** bzw. `qda_undo()`, auch nach einem Neustart. Notfalls ein Backup aus
`jellyqda-backups/` entpacken.

### Das Layout ist durcheinander

Oben **Export ▾ → Layout zurücksetzen**.

### „Invalid icon“ beim Start der App

Kam mit älteren shiny-Versionen vor (z. B. aus den Ubuntu-/Debian-Paketquellen).
Ab jellyqda 0.5.0 behoben; sonst `install.packages("shiny")`.

### Fehler gefunden?

Bitte ein Issue anlegen: <https://github.com/thedivingshellyfish/jellyqda/issues>.
Hilfreich: was du gemacht hast, die Fehlermeldung, `sessionInfo()`.
**Keine echten Interviewdaten anhängen.**
