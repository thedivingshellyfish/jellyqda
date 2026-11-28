# jellyqda :: import.R -- qda_import(): txt/md/docx/pdf -> UTF-8 frozen text
# SHA-256 dedup (same content is never imported twice), originals copied to
# originals/ under the display name (names= arg, e.g. real upload names),
# broken PDFs import with a warning. Text is FROZEN here and never re-read.
# Optional pseudonymisation before freezing: R/pseudonymise.R.

# Import engine --------------------------------------------------------------
# txt / md / docx / pdf are first-class formats; everything is normalized to
# UTF-8 and FROZEN into sources.frozen_text at import time. The text is never
# re-extracted afterwards, so offsets stay stable (concept section 4).

#' Import text files into the active project (text gets frozen)
#'
#' Reads `.txt`, `.md`, `.docx` and `.pdf` files, normalizes them to UTF-8 and
#' stores the text permanently in the `sources` table (`frozen_text`). The
#' original file is copied unchanged into `originals/` next to the project
#' file. Files whose content hash was already imported are skipped, so text is
#' extracted exactly once per file.
#'
#' A *different* file with a name that is already taken (e.g.
#' `a/interview.txt` and `b/interview.txt`) is imported under a unique name
#' such as `interview (2).txt`, so no original is ever overwritten and every
#' source can still be addressed by its name.
#'
#' PDFs without a usable text layer are imported with a warning (the original
#' remains the source of truth; consider manual OCR, e.g. tesseract).
#'
#' @param files Character vector of file paths.
#' @param copy_originals Logical; copy the original files into `originals/`.
#' @param names Optional character vector of display names (one per file) --
#'   e.g. the original file names when importing uploads whose temp paths are
#'   meaningless (`0.pdf`, ...). Defaults to `basename(files)`.
#' @param segments How the new documents are divided into segments:
#'   `"blankline"` (paragraphs, default), `"speaker"` (one segment per
#'   speaker turn, e.g. `"[00:01:12] P: ..."`) or `"line"`. Can be changed
#'   later with [qda_segments_set()]; see also [qda_segment_split()].
#' @param pseudonyms Optional key list for pseudonymisation (see
#'   [qda_pseudonyms()]): names of people, places, organisations ... are
#'   replaced in the text -- and in the document name -- BEFORE the text is
#'   frozen. The key list itself is not stored in the project, and the
#'   original files are not copied to `originals/` (they contain the real
#'   names). Check the list first with [qda_pseudonymise_preview()].
#' @return A tibble with one row per input file: `id`, `name`, `format`,
#'   `chars`, `status`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' files <- system.file("extdata", c("interview_01.txt", "interview_02.md", "interview_03.docx"),
#'                      package = "jellyqda")
#' qda_import(files)
#' qda_import(system.file("extdata", "fieldnotes.pdf", package = "jellyqda"),
#'            segments = "line")                  # one segment per line
#' qda_sources()
#' f <- file.path(tempdir(), "interview_anna.txt")
#' writeLines(c("I: Anna, how did you start?", "Anna: In Hamburg, with Ben."), f)
#' qda_import(f, pseudonyms = c("Anna" = "[Person A]", "Hamburg" = "[City 1]", "Ben" = "[Person B]"))
#' qda_sources()$name[5]           # the name is pseudonymised too
#' qda_close()
qda_import <- function(files, copy_originals = TRUE, names = NULL,
                       segments = c("blankline", "speaker", "line"), pseudonyms = NULL) {
  segments <- match.arg(segments)
  key <- if (!is.null(pseudonyms)) qda_pseudonyms(pseudonyms) else NULL   # R/pseudonymise.R
  if (length(key) && isTRUE(copy_originals)) {
    copy_originals <- FALSE
    message("Pseudonymised import: the original files are not copied to originals/ (they contain the real names).")
  }
  con <- qda_con()
  files <- normalizePath(as.character(files), mustWork = TRUE)
  rows <- list()
  for (i in seq_along(files)) {
    f <- files[i]
    nm <- if (!is.null(names) && i <= length(names) && !is.na(names[i]) && nzchar(names[i])) {
      basename(names[i])  # display name (original upload name), path-safe
    } else {
      basename(f)
    }
    fmt <- tolower(tools::file_ext(f))
    if (!fmt %in% c("txt", "md", "docx", "pdf")) {
      stop(sprintf("Unsupported format '.%s' (%s). Supported: txt, md, docx, pdf.",
                   fmt, basename(f)), call. = FALSE)
    }
    sha <- digest::digest(f, algo = "sha256", file = TRUE)
    known <- vapply(
      DBI::dbGetQuery(con, "SELECT meta_json FROM sources")$meta_json,
      function(m) isTRUE(jsonlite::fromJSON(m)$sha256 == sha),
      logical(1)
    )
    if (any(known)) {
      rows[[length(rows) + 1]] <- tibble::tibble(
        id = NA_integer_, name = nm, format = fmt,
        chars = NA_integer_,
        status = "already imported -- text stays frozen, skipped"
      )
      next
    }
    extracted <- switch(fmt,
      txt = , md = .read_text_file(f),
      docx = .read_docx_file(f),
      pdf = .read_pdf_file(f)
    )
    text <- .normalize_text(extracted$text)
    n_pseudo <- NA_integer_
    if (length(key)) {
      ps <- .pseudo_apply(c(text, nm), key)
      text <- ps$text[1]; nm <- ps$text[2]; n_pseudo <- sum(ps$counts)
    }
    warn <- isTRUE(extracted$warn)
    if (warn) {
      warning(sprintf(
        "'%s': PDF has no usable text layer (only %d chars extracted). Original kept in originals/; consider manual OCR (tesseract) and re-import.",
        nm, nchar(text, type = "chars")), call. = FALSE)
    }
    # a different file with the same name (e.g. a/interview.txt and
    # b/interview.txt) gets a unique name "interview (2).txt": otherwise its
    # original would overwrite the first one in originals/ and the name would
    # no longer identify the source
    odir <- file.path(project_dir(), "originals")
    taken <- DBI::dbGetQuery(con, "SELECT name FROM sources")$name
    if (isTRUE(copy_originals)) taken <- c(taken, list.files(odir))
    nm <- .unique_name(nm, taken)
    orig_rel <- NA_character_
    if (isTRUE(copy_originals)) {
      dir.create(odir, recursive = TRUE, showWarnings = FALSE)
      if (file.copy(f, file.path(odir, nm), overwrite = FALSE)) {
        orig_rel <- file.path("originals", nm)
      }
    }
    meta <- list(
      file = nm, original = orig_rel, sha256 = sha,
      encoding = extracted$encoding, pages = extracted$pages,
      format = fmt, imported_at = .now(),
      pseudonymised = if (!is.na(n_pseudo)) TRUE else NULL
    )
    DBI::dbExecute(
      con,
      "INSERT INTO sources (name, format, frozen_text, meta_json) VALUES (?, ?, ?, ?)",
      params = list(nm, fmt, text, .to_json(meta))
    )
    id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
    log_event("import", list(
      source_id = id, file = nm, format = fmt,
      chars = nchar(text, type = "chars"), sha256 = sha, warning = warn,
      pseudonymised = if (!is.na(n_pseudo)) n_pseudo else NULL      # only the number, never the names
    ))
    rows[[length(rows) + 1]] <- tibble::tibble(
      id = id, name = nm, format = fmt,
      chars = nchar(text, type = "chars"),
      status = if (warn) "imported with warning (broken text layer?)"
               else if (!is.na(n_pseudo)) sprintf("ok, pseudonymised (%d replacements)", n_pseudo) else "ok"
    )
  }
  if (length(rows) == 0) {
    return(tibble::tibble(id = integer(), name = character(), format = character(),
                         chars = integer(), status = character()))
  }
  out <- do.call(rbind, rows)
  # segmentation rule for the NEW documents only (skipped re-imports keep
  # their segments); blank lines = automatic, nothing to store
  if (segments != "blankline") {
    for (id in out$id[!is.na(out$id)]) qda_segments_set(id, segments)
  }
  out
}

#' `name`, or "stem (2).ext", "stem (3).ext", ... if `name` is in `taken`
#' (compared case-insensitively, as on Windows and macOS file systems).
#' @noRd
.unique_name <- function(name, taken) {
  taken <- tolower(taken)
  if (!tolower(name) %in% taken) return(name)
  ext <- tools::file_ext(name)
  stem <- if (nzchar(ext)) substr(name, 1, nchar(name) - nchar(ext) - 1) else name
  i <- 2L
  repeat {
    cand <- paste0(stem, " (", i, ")", if (nzchar(ext)) paste0(".", ext) else "")
    if (!tolower(cand) %in% taken) return(cand)
    i <- i + 1L
  }
}

#' Read a txt/md file as raw bytes, detect the encoding, convert to UTF-8.
#' @noRd
.read_text_file <- function(path) {
  raw <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(raw) == 0) return(list(text = "", encoding = "UTF-8", pages = NA_integer_))
  if (stringi::stri_enc_isutf8(raw)) {
    return(list(text = rawToChar(raw), encoding = "UTF-8", pages = NA_integer_))
  }
  guess <- readr::guess_encoding(raw, n_max = 5000)
  enc <- guess$encoding[which.max(guess$confidence)]
  chr <- tryCatch(rawToChar(raw), error = function(e) rawToChar(raw[raw != as.raw(0)]))
  txt <- tryCatch(iconv(chr, from = enc, to = "UTF-8"), error = function(e) NA_character_)
  if (is.na(txt)) txt <- chr
  list(text = txt, encoding = enc, pages = NA_integer_)
}

#' Extract paragraph text from a .docx via officer.
#' @noRd
.read_docx_file <- function(path) {
  s <- officer::docx_summary(officer::read_docx(path))
  txt <- paste(s$text[!is.na(s$text) & nzchar(s$text)], collapse = "\n\n")
  list(text = txt, encoding = "UTF-8", pages = NA_integer_)
}

#' Extract text from a PDF via pdftools; flag broken text layers.
#' @noRd
.read_pdf_file <- function(path) {
  pages <- tryCatch(
    pdftools::pdf_text(path),
    error = function(e) {
      warning(sprintf("'%s': PDF could not be read (%s).", basename(path), conditionMessage(e)),
              call. = FALSE)
      character(0)
    }
  )
  text <- paste(pages, collapse = "\n\n")
  list(text = text, encoding = "UTF-8", pages = length(pages),
       warn = nchar(trimws(text), type = "chars") < 10)
}

#' Normalize extracted text: line endings, Unicode NFC, no trailing blanks.
#' Offsets always refer to this normalized, frozen text.
#' @noRd
.normalize_text <- function(text) {
  text <- gsub("\r\n?", "\n", text)
  text <- stringi::stri_trans_nfc(text)
  text <- sub("[ \t\n]+$", "", text)
  Encoding(text) <- "UTF-8"
  text
}
