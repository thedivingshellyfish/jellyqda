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
              "shiny", "bslib", "colourpicker", "fontawesome", "rstudioapi",
              "writexl")   # writexl: Excel-Export der Codings (klein, ohne Systembibliotheken)

  # --- small helpers ---------------------------------------------------------
  `%||%` <- function(a, b) if (is.null(a)) b else a
  step <- function(i, txt) cat(sprintf("\n[%d/5] %s\n", i, txt))
  ok   <- function(txt) cat("   OK  ", txt, "\n")
  info <- function(txt) cat("   ..  ", txt, "\n")
  fail <- function(txt) stop(paste0("\n\n   FEHLER: ", txt, "\n"), call. = FALSE)

  # packages that need system libraries when built from source (Linux)
  needs_syslibs <- c("pdftools", "qpdf", "officer", "xml2", "curl", "openssl",
                     "systemfonts", "textshaping", "ragg", "gdtools")

  # hints for system libraries (pdftools needs poppler, officer needs libxml2)
  sys_hint <- function(pkgs) {
    os <- Sys.info()[["sysname"]]
    msg <- c("   Einige Pakete brauchen Systembibliotheken: ",
             paste0("   (betrifft: ", paste(pkgs, collapse = ", "), ")"))
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
      } else "Paketmanager: poppler-cpp + libxml2 (jeweils die -dev/-devel Pakete)"
      msg <- c(msg, "   Im Terminal (nicht in R) ausfuehren, dann dieses Skript erneut starten:",
               paste0("     ", cmd))
    } else if (os == "Darwin") {
      msg <- c(msg, "   Im Terminal: brew install poppler   (Homebrew: https://brew.sh)",
               "   dann dieses Skript erneut starten.")
    } else {
      msg <- c(msg, "   Unter Windows gibt es fertige Pakete -- bitte R aktualisieren",
               "   (https://cran.r-project.org) und das Skript erneut starten.")
    }
    cat(paste(msg, collapse = "\n"), "\n")
  }

  cat("=====================================================\n")
  cat(" jellyqda -- Installation\n")
  cat("=====================================================\n")

  # --- 1. R version ------------------------------------------------------------
  step(1, "R-Version pruefen")
  if (getRversion() < "4.0.0") {
    fail(sprintf("jellyqda braucht R >= 4.0 (installiert: %s). Bitte R aktualisieren: https://cran.r-project.org",
                 getRversion()))
  }
  ok(sprintf("R %s", getRversion()))
  if (identical(getOption("repos")[["CRAN"]], "@CRAN@") || is.null(getOption("repos")[["CRAN"]])) {
    options(repos = c(CRAN = "https://cloud.r-project.org"))
  }

  # --- 2. missing packages from CRAN ----------------------------------------------
  step(2, "Benoetigte Pakete pruefen")
  have <- rownames(utils::installed.packages())
  missing <- setdiff(needed, have)
  if (length(missing) == 0) {
    ok("alle Pakete vorhanden")
  } else {
    info(sprintf("installiere %d Paket(e): %s", length(missing), paste(missing, collapse = ", ")))
    # is the package repository reachable at all? (otherwise the reason is
    # the network, not missing system libraries)
    avail <- tryCatch(suppressWarnings(rownames(utils::available.packages())),
                      error = function(e) character())
    if (length(avail) == 0) {
      fail(paste0("Keine Verbindung zum Paket-Server (", getOption("repos")[["CRAN"]], ").
",
                  "   Internetverbindung pruefen (ggf. Proxy/VPN/Firewall der Uni) und erneut versuchen.
",
                  "   Anderer Server: options(repos = c(CRAN = \"https://cran.r-project.org\")) vor source(...)."))
    }
    gone <- setdiff(missing, avail)
    if (length(gone) > 0) {
      fail(sprintf("Auf dem Paket-Server nicht verfuegbar: %s (R %s zu alt/neu?). Bitte R aktualisieren.",
                   paste(gone, collapse = ", "), getRversion()))
    }
    info("(das kann beim ersten Mal einige Minuten dauern)")
    utils::install.packages(missing)
    still <- missing[!vapply(missing, requireNamespace, logical(1), quietly = TRUE)]
    if (length(still) > 0) {
      if (length(intersect(still, needs_syslibs)) > 0) sys_hint(intersect(still, needs_syslibs))
      fail(sprintf("Diese Pakete konnten nicht installiert werden: %s\n   (Details stehen in den Meldungen darueber.)",
                   paste(still, collapse = ", ")))
    }
    ok("Pakete installiert")
  }

  # --- 3. get + install jellyqda ---------------------------------------------------
  step(3, "jellyqda installieren")
  tmp <- tempfile("jellyqda-install-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  if (!is.null(path)) {
    path <- normalizePath(path.expand(path), mustWork = FALSE)
    if (!file.exists(path)) fail(sprintf("Datei/Ordner nicht gefunden: %s", path))
    if (dir.exists(path)) {
      src <- path
      info(sprintf("aus lokalem Ordner: %s", path))
    } else {
      info(sprintf("aus lokaler ZIP-Datei: %s", path))
      utils::unzip(path, exdir = tmp)
      src <- NULL
    }
  } else {
    url <- zip_url %||% sprintf("https://github.com/%s/archive/refs/heads/%s.zip", repo, ref)
    info(if (is.null(zip_url)) sprintf("von GitHub: %s (Branch '%s')", repo, ref) else sprintf("von %s", url))
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
    if (!got) fail(sprintf("Download fehlgeschlagen (%s). Internet/Branch-Name pruefen.", url))
    utils::unzip(zipfile, exdir = tmp)
    src <- NULL
  }
  if (is.null(src)) {   # the folder inside the zip that holds DESCRIPTION
    desc <- list.files(tmp, pattern = "^DESCRIPTION$", recursive = TRUE, full.names = TRUE)
    desc <- desc[grepl("^Package:\\s*jellyqda\\s*$",
                       vapply(desc, function(f) readLines(f, n = 1, warn = FALSE), character(1)))]
    if (length(desc) == 0) fail("Im Download/ZIP wurde kein jellyqda-Paket (DESCRIPTION) gefunden.")
    src <- dirname(desc[which.min(nchar(desc))])
  }

  # an already loaded old version would stay in memory -> unload it first
  if ("jellyqda" %in% loadedNamespaces()) {
    if (exists("qda_close", envir = asNamespace("jellyqda"))) {
      try(suppressWarnings(jellyqda::qda_close()), silent = TRUE)
    }
    unloaded <- tryCatch({ unloadNamespace("jellyqda"); TRUE }, error = function(e) FALSE)
    if (!unloaded) {
      fail(paste("Eine alte jellyqda-Version ist noch geladen.",
                 "Bitte R neu starten (RStudio: Session > Restart R) und das Skript erneut ausfuehren."))
    }
    info("alte, geladene Version entladen")
  }
  res <- tryCatch({
    utils::install.packages(src, repos = NULL, type = "source", quiet = TRUE); TRUE
  }, warning = function(w) conditionMessage(w), error = function(e) conditionMessage(e))
  if (!isTRUE(res)) fail(sprintf("Installation fehlgeschlagen: %s", res))
  ok(sprintf("jellyqda %s installiert", utils::packageVersion("jellyqda")))

  # --- 4. check ------------------------------------------------------------------
  step(4, "Installation pruefen")
  ns <- asNamespace("jellyqda")
  checks <- c(
    "App-Dateien (CSS/JS)"         = nzchar(system.file("app", "www", "jellyqda.js", package = "jellyqda")),
    "Rueckgaengig/Wiederholen"     = exists("qda_redo", envir = ns),
    "Segmente (Sprecherwechsel)"   = exists("qda_segments_set", envir = ns),
    "Memos in vier Arten"          = "kind" %in% names(formals(get("qda_memos", envir = ns))),
    "App-Pakete (shiny, bslib ...)" = all(vapply(c("shiny", "bslib", "colourpicker", "fontawesome"),
                                                 requireNamespace, logical(1), quietly = TRUE))
  )
  for (n in names(checks)) cat(if (checks[[n]]) "   OK   " else "   --   ", n, "\n")
  if (!all(checks)) {
    cat("\n   Hinweis: Einige Funktionen fehlen -- das ist eine aeltere jellyqda-Version.\n",
        "  Fuer die neue Version z.B. den Branch angeben:\n",
        "    options(jellyqda.install.ref = \"jellyqda-v4\")\n",
        "  oder die ZIP-Datei:\n",
        "    options(jellyqda.install.path = \"~/Downloads/jellyqda-v4.1.zip\")\n",
        "  und das Skript erneut ausfuehren.\n")
  }

  # --- 5. next steps -----------------------------------------------------------------
  step(5, "Fertig! So geht es weiter:")
  cat('
   library(jellyqda)
   qda_open("meinprojekt.jellyqda")   # Projekt anlegen oder oeffnen
   qda_app()                          # App im Browser starten (Esc beendet)

   Bestehende Projekte: vorher ein Backup anlegen -- qda_backup()
   Hilfe: ?qda_app, ?qda_memo_add, ?qda_segments_set
\n')
  if ("rstudioapi" %in% rownames(utils::installed.packages()) && rstudioapi::isAvailable()) {
    cat("   Tipp (RStudio): Wenn jellyqda vorher schon geladen war, einmal\n",
        "  Session > Restart R ausfuehren.\n")
  }
  if (start_app) {
    library(jellyqda)
    demo <- file.path(tempdir(), "jellyqda-demo.jellyqda")
    qda_open(demo)
    if (nrow(qda_sources()) == 0) {
      qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
    }
    cat("   Starte Demo-App mit einem Beispiel-Interview ...\n")
    qda_app()
  }
  invisible(TRUE)
})
