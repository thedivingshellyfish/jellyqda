> 🌐 [English](../Installation.md) · **Deutsch**

# Installation

Du brauchst das nur **einmal** zu machen. Danach läuft jellyqda ohne Internet.

## 1. R und RStudio installieren (falls noch nicht vorhanden)

- **R** (ab Version 4.0): <https://cran.r-project.org>
- **RStudio** (empfohlen, aber nicht nötig): <https://posit.co/download/rstudio-desktop/>

Beides ist kostenlos und läuft unter Windows, macOS und Linux.

## 2. jellyqda installieren: eine Zeile

Öffne RStudio (oder R) und füge in die **Konsole** ein:

```r
source("https://raw.githubusercontent.com/thedivingshellyfish/jellyqda/main/install_jellyqda.R")
```

Das Skript arbeitet fünf Schritte ab (auf einem deutschen System mit deutschen Meldungen) und zeigt jeweils, was passiert:

```
[1/5] R-Version pruefen
   OK   R 4.4.1
[2/5] Benoetigte Pakete pruefen
   ..   installiere 2 Paket(e): shiny, bslib
[3/5] jellyqda installieren
   OK   jellyqda 0.7.0 installiert
[4/5] Installation pruefen
   OK    App-Dateien (CSS/JS)
   OK    Rueckgaengig/Wiederholen
   ...
[5/5] Fertig! So geht es weiter:
```

Beim ersten Mal kann Schritt 2 einige Minuten dauern.

## Andere Wege

```r
# aus einer heruntergeladenen ZIP-Datei:
options(jellyqda.install.path = "~/Downloads/jellyqda.zip")
source("https://raw.githubusercontent.com/thedivingshellyfish/jellyqda/main/install_jellyqda.R")

# einen bestimmten Branch oder Tag installieren:
options(jellyqda.install.ref = "main")

# nach der Installation direkt eine Demo starten:
options(jellyqda.install.start_app = TRUE)
```

Du kannst das Skript auch herunterladen, in RStudio öffnen und oben auf
**„Source“** klicken.

## Linux: Systembibliotheken

Für den PDF- und Word-Import braucht R unter Linux einmalig ein paar
Systembibliotheken. Fehlen sie, nennt das Installationsskript den passenden
Befehl für deine Distribution, z. B. für Ubuntu/Debian (im **Terminal**, nicht in R):

```bash
sudo apt install libpoppler-cpp-dev libxml2-dev libssl-dev libcurl4-openssl-dev libfontconfig1-dev
```

Danach das Skript einfach erneut ausführen.

## Aktualisieren

Dieselbe Zeile wie oben noch einmal ausführen. Eine bereits geladene alte
Version wird automatisch entladen; in RStudio danach sicherheitshalber
**Session → Restart R**.

> ⚠️ Vor dem ersten Öffnen eines bestehenden Projekts mit einer neuen Version:
> `qda_backup()` (mit der alten Version) anlegen.

Weiter mit: **[Erste Schritte](Erste-Schritte.md)**
