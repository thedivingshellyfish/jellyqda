# =============================================================================
# install_jellyqda.R -- installs (or updates) jellyqda incl. everything the
# app needs. Works in the plain R console and in RStudio, on Linux, macOS
# and Windows. Needs internet once; jellyqda itself then runs offline.
#
# USAGE
#   a) straight from GitHub (latest version of branch "main"):
#        source("https://raw.githubusercontent.com/thedivingshellyfish/jellyqda/main/install_jellyqda.R")
#
#   b) this file downloaded / opened in RStudio: click "Source"
#      (or in the console: source("install_jellyqda.R"))
#
#   c) settings BEFORE source(...), all optional:
#        options(jellyqda.install.ref  = "jellyqda-v4")      # other branch/tag
#        options(jellyqda.install.path = "~/Downloads/jellyqda-v4.1.zip")
#                                       # install from a local .zip or folder
#        options(jellyqda.install.start_app = TRUE)          # start app afterwards
#        options(jellyqda.install.url = "https://.../x.zip") # any zip URL (e.g. a fork)
#
# WHAT IT DOES
#   1. checks the R version (>= 4.0)
#   2. installs missing packages from CRAN (only missing ones)
#   3. installs jellyqda from GitHub or from a local zip/folder
#   4. checks that the installation is complete (app files, functions)
#   5. prints the next steps
# Nothing is deleted, no project files (*.jellyqda) are touched.
# =============================================================================

local({

  # --- settings ----------------------------------------------------------------
  repo      <- "thedivingshellyfish/jellyqda"
  ref       <- getOption("jellyqda.install.ref", "main")
  path      <- getOption("jellyqda.install.path", NULL)
  start_app <- isTRUE(getOption("jellyqda.install.start_app", FALSE))
  zip_url   <- getOption("jellyqda.install.url", NULL)

  # packages jellyqda needs (Imports) + the ones the app needs (shiny & co)
  needed <- c("DBI", "RSQLite", "digest", "htmltools", "jsonlite", "officer",
              "pdftools", "readr", "stringi", "tibble", "zip",
              "shiny", "bslib", "fontawesome",
              "writexl")   # writexl: Excel export of the codings (small, no system libraries)

  # --- small helpers ---------------------------------------------------------
  # messages in German on German systems, otherwise in English
  de_ui <- grepl("^de", c(Sys.getenv("LANGUAGE"), Sys.getenv("LANG"),
                          tryCatch(Sys.getlocale("LC_COLLATE"), error = function(e) ""))[1]) ||
    grepl("German", tryCatch(Sys.getlocale("LC_COLLATE"), error = function(e) ""))
  if (!is.null(getOption("jellyqda.lang"))) de_ui <- identical(getOption("jellyqda.lang"), "de")
  tx <- function(de, en) if (de_ui) de else en
  `%||%` <- function(a, b) if (is.null(a)) b else a
  step <- function(i, txt) cat(sprintf("\n[%d/5] %s\n", i, txt))
  ok   <- function(txt) cat("   OK  ", txt, "\n")
  info <- function(txt) cat("   ..  ", txt, "\n")
  fail <- function(txt) stop(paste0("\n\n   ", tx("FEHLER", "ERROR"), ": ", txt, "\n"), call. = FALSE)

  # packages that need system libraries when built from source (Linux)
  needs_syslibs <- c("pdftools", "qpdf", "officer", "xml2", "curl", "openssl",
                     "systemfonts", "textshaping", "ragg", "gdtools")

  # hints for system libraries (pdftools needs poppler, officer needs libxml2)
  sys_hint <- function(pkgs) {
    os <- Sys.info()[["sysname"]]
    msg <- c(tx("   Einige Pakete brauchen Systembibliotheken: ", "   Some packages need system libraries: "),
             paste0(tx("   (betrifft: ", "   (concerns: "), paste(pkgs, collapse = ", "), ")"))
    if (os == "Linux") {
      id <- tryCatch(tolower(paste(readLines("/etc/os-release"), collapse = " ")),
                     error = function(e) "")
      cmd <- if (grepl("ubuntu|debian|mint|pop", id)) {
        "sudo apt install libpoppler-cpp-dev libxml2-dev libssl-dev libcurl4-openssl-dev libfontconfig1-dev"
      } else if (grepl("fedora|rhel|centos|rocky|alma", id)) {
        "sudo dnf install poppler-cpp-devel libxml2-devel openssl-devel libcurl-devel fontconfig-devel"
      } else if (grepl("arch|manjaro", id)) {
        "sudo pacman -S poppler libxml2 openssl curl fontconfig"
      } else if (grepl("suse", id)) {
        "sudo zypper install poppler-devel libxml2-devel libopenssl-devel libcurl-devel fontconfig-devel"
      } else tx("Paketmanager: poppler-cpp + libxml2 (jeweils die -dev/-devel Pakete)", "package manager: poppler-cpp + libxml2 (the -dev/-devel packages)")
      msg <- c(msg, tx("   Im Terminal (nicht in R) ausfuehren, dann dieses Skript erneut starten:", "   Run in a terminal (not in R), then start this script again:"),
               paste0("     ", cmd))
    } else if (os == "Darwin") {
      msg <- c(msg, tx("   Im Terminal: brew install poppler   (Homebrew: https://brew.sh)", "   In a terminal: brew install poppler   (Homebrew: https://brew.sh)"),
               tx("   dann dieses Skript erneut starten.", "   then start this script again."))
    } else {
      msg <- c(msg, tx("   Unter Windows gibt es fertige Pakete -- bitte R aktualisieren", "   On Windows there are ready-made packages -- please update R"),
               tx("   (https://cran.r-project.org) und das Skript erneut starten.", "   (https://cran.r-project.org) and start the script again."))
    }
    cat(paste(msg, collapse = "\n"), "\n")
  }

  cat("=====================================================\n")
  cat(" jellyqda -- Installation\n")
  cat("=====================================================\n")

  # --- 1. R version ------------------------------------------------------------
  step(1, tx("R-Version pruefen", "Check the R version"))
  if (getRversion() < "4.0.0") {
    fail(sprintf(tx("jellyqda braucht R >= 4.0 (installiert: %s). Bitte R aktualisieren: https://cran.r-project.org", "jellyqda needs R >= 4.0 (installed: %s). Please update R: https://cran.r-project.org"),
                 getRversion()))
  }
  ok(sprintf("R %s", getRversion()))
  if (identical(getOption("repos")[["CRAN"]], "@CRAN@") || is.null(getOption("repos")[["CRAN"]])) {
    options(repos = c(CRAN = "https://cloud.r-project.org"))
  }

  # --- 2. missing packages from CRAN ----------------------------------------------
  step(2, tx("Benoetigte Pakete pruefen", "Check the required packages"))
  have <- rownames(utils::installed.packages())
  missing <- setdiff(needed, have)
  if (length(missing) == 0) {
    ok(tx("alle Pakete vorhanden", "all packages available"))
  } else {
    info(sprintf(tx("installiere %d Paket(e): %s", "installing %d package(s): %s"), length(missing), paste(missing, collapse = ", ")))
    # is the package repository reachable at all? (otherwise the reason is
    # the network, not missing system libraries)
    avail <- tryCatch(suppressWarnings(rownames(utils::available.packages())),
                      error = function(e) character())
    if (length(avail) == 0) {
      fail(paste0(tx("Keine Verbindung zum Paket-Server (", "No connection to the package server ("), getOption("repos")[["CRAN"]], ").
",
                  tx("   Internetverbindung pruefen (ggf. Proxy/VPN/Firewall der Uni) und erneut versuchen.
", "   Check the internet connection (proxy/VPN/university firewall?) and try again.
"),
                  tx("   Anderer Server: options(repos = c(CRAN = \"https://cran.r-project.org\")) vor source(...).", "   Other server: options(repos = c(CRAN = \"https://cran.r-project.org\")) before source(...).")))
    }
    gone <- setdiff(missing, avail)
    if (length(gone) > 0) {
      fail(sprintf(tx("Auf dem Paket-Server nicht verfuegbar: %s (R %s zu alt/neu?). Bitte R aktualisieren.", "Not available on the package server: %s (R %s too old/new?). Please update R."),
                   paste(gone, collapse = ", "), getRversion()))
    }
    info(tx("(das kann beim ersten Mal einige Minuten dauern)", "(this can take a few minutes the first time)"))
    utils::install.packages(missing)
    still <- missing[!vapply(missing, requireNamespace, logical(1), quietly = TRUE)]
    if (length(still) > 0) {
      if (length(intersect(still, needs_syslibs)) > 0) sys_hint(intersect(still, needs_syslibs))
      fail(sprintf(tx("Diese Pakete konnten nicht installiert werden: %s\n   (Details stehen in den Meldungen darueber.)", "These packages could not be installed: %s\n   (details in the messages above.)"),
                   paste(still, collapse = ", ")))
    }
    ok(tx("Pakete installiert", "packages installed"))
  }

  # --- 3. get + install jellyqda ---------------------------------------------------
  step(3, tx("jellyqda installieren", "Install jellyqda"))
  tmp <- tempfile("jellyqda-install-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  if (!is.null(path)) {
    path <- normalizePath(path.expand(path), mustWork = FALSE)
    if (!file.exists(path)) fail(sprintf(tx("Datei/Ordner nicht gefunden: %s", "File/folder not found: %s"), path))
    if (dir.exists(path)) {
      src <- path
      info(sprintf(tx("aus lokalem Ordner: %s", "from local folder: %s"), path))
    } else {
      info(sprintf(tx("aus lokaler ZIP-Datei: %s", "from local ZIP file: %s"), path))
      utils::unzip(path, exdir = tmp)
      src <- NULL
    }
  } else {
    url <- zip_url %||% sprintf("https://github.com/%s/archive/refs/heads/%s.zip", repo, ref)
    info(if (is.null(zip_url)) sprintf(tx("von GitHub: %s (Branch '%s')", "from GitHub: %s (branch '%s')"), repo, ref) else sprintf(tx("von %s", "from %s"), url))
    zipfile <- file.path(tmp, "jellyqda.zip")
    got <- tryCatch({
      utils::download.file(url, zipfile, mode = "wb", quiet = TRUE); TRUE
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (!got && is.null(zip_url)) {   # maybe a tag instead of a branch
      url <- sprintf("https://github.com/%s/archive/refs/tags/%s.zip", repo, ref)
      got <- tryCatch({
        utils::download.file(url, zipfile, mode = "wb", quiet = TRUE); TRUE
      }, error = function(e) FALSE, warning = function(w) FALSE)
    }
    if (!got) fail(sprintf(tx("Download fehlgeschlagen (%s). Internet/Branch-Name pruefen.", "Download failed (%s). Check the internet connection/branch name."), url))
    utils::unzip(zipfile, exdir = tmp)
    src <- NULL
  }
  if (is.null(src)) {   # the folder inside the zip that holds DESCRIPTION
    desc <- list.files(tmp, pattern = "^DESCRIPTION$", recursive = TRUE, full.names = TRUE)
    desc <- desc[grepl("^Package:\\s*jellyqda\\s*$",
                       vapply(desc, function(f) readLines(f, n = 1, warn = FALSE), character(1)))]
    if (length(desc) == 0) fail(tx("Im Download/ZIP wurde kein jellyqda-Paket (DESCRIPTION) gefunden.", "No jellyqda package (DESCRIPTION) found in the download/ZIP."))
    src <- dirname(desc[which.min(nchar(desc))])
  }

  # an already loaded old version would stay in memory -> unload it first
  if ("jellyqda" %in% loadedNamespaces()) {
    if (exists("qda_close", envir = asNamespace("jellyqda"))) {
      try(suppressWarnings(jellyqda::qda_close()), silent = TRUE)
    }
    unloaded <- tryCatch({ unloadNamespace("jellyqda"); TRUE }, error = function(e) FALSE)
    if (!unloaded) {
      fail(paste(tx("Eine alte jellyqda-Version ist noch geladen.", "An old jellyqda version is still loaded."),
                 tx("Bitte R neu starten (RStudio: Session > Restart R) und das Skript erneut ausfuehren.", "Please restart R (RStudio: Session > Restart R) and run the script again.")))
    }
    info(tx("alte, geladene Version entladen", "old loaded version unloaded"))
  }
  res <- tryCatch({
    utils::install.packages(src, repos = NULL, type = "source", quiet = TRUE); TRUE
  }, warning = function(w) conditionMessage(w), error = function(e) conditionMessage(e))
  if (!isTRUE(res)) fail(sprintf(tx("Installation fehlgeschlagen: %s", "Installation failed: %s"), res))
  ok(sprintf(tx("jellyqda %s installiert", "jellyqda %s installed"), utils::packageVersion("jellyqda")))

  # --- 4. check ------------------------------------------------------------------
  step(4, tx("Installation pruefen", "Check the installation"))
  ns <- asNamespace("jellyqda")
  checks <- c(
    nzchar(system.file("app", "www", "js", "01-helpers.js", package = "jellyqda")),
    exists("qda_redo", envir = ns),
    exists("qda_segments_set", envir = ns),
    "kind" %in% names(formals(get("qda_memos", envir = ns))),
    exists("qda_language", envir = ns),
    all(vapply(c("shiny", "bslib", "fontawesome"), requireNamespace, logical(1), quietly = TRUE))
  )
  names(checks) <- if (de_ui) {
    c("App-Dateien (CSS/JS)", "R\u00fcckg\u00e4ngig/Wiederholen", "Segmente (Sprecherwechsel)",
      "Memos in vier Arten", "Englische/deutsche Oberfl\u00e4che", "App-Pakete (shiny, bslib ...)")
  } else {
    c("app files (CSS/JS)", "undo/redo", "segments (speaker turns)", "memos in four kinds",
      "English/German user interface", "app packages (shiny, bslib ...)")
  }
  for (n in names(checks)) cat(if (checks[[n]]) "   OK   " else "   --   ", n, "\n")
  if (!all(checks)) {
    cat(tx("\n   Hinweis: Einige Funktionen fehlen -- das ist eine aeltere jellyqda-Version.\n",
           "\n   Note: some functions are missing -- this is an older jellyqda version.\n"),
        tx("  Fuer die neue Version z.B. den Branch angeben:\n", "  For the new version, e.g. give the branch:\n"),
        "    options(jellyqda.install.ref = \"main\")\n",
        tx("  oder die ZIP-Datei:\n", "  or the ZIP file:\n"),
        "    options(jellyqda.install.path = \"~/Downloads/jellyqda.zip\")\n",
        tx("  und das Skript erneut ausfuehren.\n", "  and run the script again.\n"))
  }

  # --- 5. next steps -----------------------------------------------------------------
  step(5, tx("Fertig! So geht es weiter:", "Done! Next steps:"))
  cat(tx('
   library(jellyqda)
   qda_open("meinprojekt.jellyqda")   # Projekt anlegen oder oeffnen
   qda_app()                          # App im Browser starten (Esc beendet)
   qda_app(lang = "en")               # englische Oberflaeche

   Bestehende Projekte: vorher ein Backup anlegen -- qda_backup()
   Hilfe: ?qda_app, ?qda_memo_add, ?qda_segments_set
\n', '
   library(jellyqda)
   qda_open("my-project.jellyqda")    # create or open a project
   qda_app()                          # start the app in the browser (Esc stops it)
   qda_app(lang = "de")               # German user interface

   Existing projects: create a backup first -- qda_backup()
   Help: ?qda_app, ?qda_memo_add, ?qda_segments_set
\n'))
  if ("rstudioapi" %in% rownames(utils::installed.packages()) && rstudioapi::isAvailable()) {
    cat(tx("   Tipp (RStudio): Wenn jellyqda vorher schon geladen war, einmal\n  Session > Restart R ausfuehren.\n",
           "   Tip (RStudio): if jellyqda was loaded before, run\n  Session > Restart R once.\n"))
  }
  if (start_app) {
    library(jellyqda)
    demo <- file.path(tempdir(), "jellyqda-demo.jellyqda")
    qda_open(demo)
    if (nrow(qda_sources()) == 0) {
      qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
    }
    cat(tx("   Starte Demo-App mit einem Beispiel-Interview ...\n", "   Starting the demo app with an example interview ...\n"))
    qda_app()
  }
  invisible(TRUE)
})
