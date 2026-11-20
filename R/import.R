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
#' PDFs without a usable text layer are imported with a warning (the original
#' remains the source of truth; consider manual OCR, e.g. tesseract).
#'
#' @param files Character vector of file paths.
#' @param copy_originals Logical; copy the original files into `originals/`.
#' @return A tibble with one row per input file: `id`, `name`, `format`,
#'   `chars`, `status`.
#' @export
#' @examples
#' \dontrun{
#' qda_open("meinarbeit.jellyqda")
#' qda_import(c("interview_01.txt", "interview_02.docx", "feldnotizen.pdf"))
#' }
qda_import <- function(files, copy_originals = TRUE) {
  con <- qda_con()
  files <- normalizePath(as.character(files), mustWork = TRUE)
  rows <- list()
  for (f in files) {
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
        id = NA_integer_, name = basename(f), format = fmt,
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
    warn <- isTRUE(extracted$warn)
    if (warn) {
      warning(sprintf(
        "'%s': PDF has no usable text layer (only %d chars extracted). Original kept in originals/; consider manual OCR (tesseract) and re-import.",
        basename(f), nchar(text, type = "chars")), call. = FALSE)
    }
    orig_rel <- NA_character_
    if (isTRUE(copy_originals)) {
      odir <- file.path(project_dir(), "originals")
      dir.create(odir, recursive = TRUE, showWarnings = FALSE)
      if (file.copy(f, odir, overwrite = TRUE)) {
        orig_rel <- file.path("originals", basename(f))
      }
    }
    meta <- list(
      file = basename(f), original = orig_rel, sha256 = sha,
      encoding = extracted$encoding, pages = extracted$pages,
      format = fmt, imported_at = .now()
    )
    DBI::dbExecute(
      con,
      "INSERT INTO sources (name, format, frozen_text, meta_json) VALUES (?, ?, ?, ?)",
      params = list(basename(f), fmt, text, .to_json(meta))
    )
    id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
    log_event("import", list(
      source_id = id, file = basename(f), format = fmt,
      chars = nchar(text, type = "chars"), sha256 = sha, warning = warn
    ))
    rows[[length(rows) + 1]] <- tibble::tibble(
      id = id, name = basename(f), format = fmt,
      chars = nchar(text, type = "chars"),
      status = if (warn) "imported with warning (broken text layer?)" else "ok"
    )
  }
  if (length(rows) == 0) {
    return(tibble::tibble(id = integer(), name = character(), format = character(),
                         chars = integer(), status = character()))
  }
  do.call(rbind, rows)
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
