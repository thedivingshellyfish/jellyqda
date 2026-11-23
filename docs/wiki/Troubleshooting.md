> 🌐 **English** · [Deutsch](de/Hilfe-bei-Problemen.md)

# Troubleshooting

### The installation stops: "No connection to the package server"

Check the internet connection; at university possibly proxy or VPN. Try
another server:

```r
options(repos = c(CRAN = "https://cran.r-project.org"))
source("https://raw.githubusercontent.com/thedivingshellyfish/jellyqda/main/install_jellyqda.R")
```

### "These packages could not be installed: pdftools …" (Linux)

System libraries are missing. The installation script shows the right
command; for Ubuntu/Debian in a **terminal**:

```bash
sudo apt install libpoppler-cpp-dev libxml2-dev libssl-dev libcurl4-openssl-dev libfontconfig1-dev
```

### New functions are missing after an update

An old version is still loaded. In RStudio **Session → Restart R**, then
`library(jellyqda)`. The installation script shows under *[4/5]* whether
everything is there.

### "No jellyqda project is open"

Call `qda_open("file.jellyqda")` before `qda_app()` or other functions.

### The app does not open / empty window

The address is in the R console (`jellyqda app (local, offline): http://127.0.0.1:…`);
simply open it in the browser. Is an old app still running? `Esc` in the
console, then start again.

### The app is in the wrong language

Click **DE / EN** in the toolbar, or start it with `qda_app(lang = "en")`.
The browser remembers your choice; `qda_language("en")` sets it for the
whole R session (also for exported reports).

### The R console does not respond any more

While the app runs, the console is busy. Quit the app: red **X** in the app
or `Esc` in the console.

### A PDF shows hardly any text (warning on import)

The PDF is probably a scan without a text layer. Convert it into a
searchable PDF or `.txt` with OCR software (e.g. Tesseract) first and import
it again.

### Umlauts or accents look wrong

`.txt` files are detected automatically (UTF-8, Latin-1 …). If something
still goes wrong: save the file as **UTF-8** in an editor and import it again
(texts already imported do not change).

### I deleted something by accident

**Ctrl+Z** or `qda_undo()`, even after a restart. If necessary, unzip a
backup from `jellyqda-backups/`.

### The layout is messed up

At the top **Export ▾ → Reset layout**.

### "Invalid icon" when starting the app

Happened with older shiny versions (e.g. from the Ubuntu/Debian package
sources). Fixed since jellyqda 0.5.0; otherwise `install.packages("shiny")`.

### Found a bug?

Please open an issue: <https://github.com/thedivingshellyfish/jellyqda/issues>.
Helpful: what you did, the error message, `sessionInfo()`.
**Do not attach real interview data.**
