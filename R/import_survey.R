# jellyqda :: import_survey.R -- survey import (open answers from online
# surveys: SoSci Survey, LimeSurvey, Qualtrics, ... exported as CSV or Excel)
#
#   qda_survey_columns()  look at a survey file: which column is the ID,
#                         which hold open answers, which are variables
#   qda_import_survey()   one document per respondent: every open answer a
#                         segment ("question" line + answer), chosen columns
#                         as document variables, optionally pre-coded by
#                         question (one code per question)
#
# The text of each document is frozen like every import (R/import.R); the
# survey file is copied once into originals/. Excel needs the package
# 'readxl' (suggested, not required); CSV works always. The app: dialog
# "Fragebogen importieren" in the documents panel (R/app_server_survey.R).

#' Read a survey file into a data frame of character columns.
#' @noRd
.read_survey <- function(file, sheet = 1, name = NULL) {
  ext <- tolower(tools::file_ext(name %||% file))
  if (ext %in% c("xlsx", "xls")) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      stop("Excel files need the package 'readxl': install.packages('readxl') -- or save the survey as CSV.", call. = FALSE)
    }
    df <- as.data.frame(readxl::read_excel(file, sheet = sheet, col_types = "text", .name_repair = "minimal"),
                        stringsAsFactors = FALSE)
  } else if (ext %in% c("csv", "tsv", "txt")) {
    first <- readLines(file, n = 1, warn = FALSE, encoding = "UTF-8")
    count <- function(ch) lengths(regmatches(first, gregexpr(ch, first, fixed = TRUE)))
    delim <- c(",", ";", "\t")[which.max(c(count(","), count(";"), count("\t")))]
    raw <- readBin(file, "raw", min(file.info(file)$size, 200000))
    enc <- tryCatch(readr::guess_encoding(raw)$encoding[1], error = function(e) NA)
    enc <- if (is.na(enc) || !nzchar(enc) || grepl("ASCII", enc)) "UTF-8" else enc
    df <- as.data.frame(readr::read_delim(file, delim = delim, col_types = readr::cols(.default = "c"),
                                          locale = readr::locale(encoding = enc), na = c("", "NA"),
                                          trim_ws = TRUE, show_col_types = FALSE, name_repair = "minimal",
                                          progress = FALSE), stringsAsFactors = FALSE)
  } else {
    stop(sprintf("Unsupported survey format '.%s'. Use CSV or Excel (.xlsx).", ext), call. = FALSE)
  }
  names(df) <- enc2utf8(trimws(names(df)))
  df[] <- lapply(df, function(x) { x <- enc2utf8(as.character(x)); x[is.na(x)] <- ""; trimws(x) })
  df
}

#' Clean an answer: line breaks unified, no blank lines inside (a blank line
#' separates the answers), NFC as every import (R/import.R: .normalize_text)
#' -- applied BEFORE the positions of the answers are computed.
#' @noRd
.survey_clean <- function(x) stringi::stri_trans_nfc(trimws(gsub("\n[ \t]*\n+", "\n", gsub("\r\n?", "\n", x))))

#' The text of one respondent's document: "question\nanswer" blocks separated
#' by a blank line (= one segment each), and where each answer starts and ends
#' (1-based, inclusive) -- for pre-coding by question. Answers must already be
#' cleaned (.survey_clean).
#' @noRd
.survey_doc <- function(questions, answers) {
  q <- stringi::stri_trans_nfc(gsub("\\s+", " ", questions))
  blocks <- paste0(q, "\n", answers)
  body <- paste(blocks, collapse = "\n\n"); Encoding(body) <- "UTF-8"
  starts <- cumsum(c(1L, nchar(blocks[-length(blocks)]) + 2L))
  a_start <- starts + nchar(q) + 1L
  list(body = body, a_start = a_start, a_end = a_start + nchar(answers) - 1L)
}

#' Guess the role of every column: "id", "text" (open answers), "variable"
#' or "ignore".
#' @noRd
.survey_roles <- function(df) {
  n <- nrow(df)
  info <- lapply(names(df), function(nm) {
    x <- df[[nm]]; ne <- x[nzchar(x)]
    data.frame(column = nm, answers = length(ne), distinct = length(unique(ne)),
               mean_chars = if (length(ne)) mean(nchar(ne)) else 0,
               max_chars = if (length(ne)) max(nchar(ne)) else 0,
               example = if (length(ne)) substr(ne[which.max(nchar(ne))], 1, 80) else "",
               stringsAsFactors = FALSE)
  })
  info <- do.call(rbind, info)
  role <- rep("ignore", nrow(info))
  id_name <- grepl("^(id|respondent|respondent_?id|case|caseid|lfdn|response_?id|participant|teilnehmer\\w*|fall|nr)$",
                   info$column, ignore.case = TRUE)
  unique_full <- info$answers == n & info$distinct == n & n > 0
  id <- which(id_name & unique_full)[1]
  if (!is.na(id)) role[id] <- "id"
  # open answers: long texts with more than a handful of different answers
  # (a long category label with 3 values stays a variable)
  text <- (info$mean_chars >= 25 | info$max_chars >= 80) & info$distinct > pmax(3, 0.3 * info$answers) & role == "ignore"
  role[text] <- "text"
  # variables: 2 to 30 different values, but not one per respondent (time
  # stamps, IP addresses, e-mail ... are left out)
  per_row <- info$distinct == info$answers & info$answers > 3
  var <- role == "ignore" & info$distinct >= 2 & info$distinct <= 30 & !per_row
  role[var] <- "variable"
  info$role <- role
  info
}

#' Look at a survey file before importing it
#'
#' Reads a survey export (CSV or Excel) and suggests a role for every
#' column: the respondent **id**, columns with **open answers** (`"text"`),
#' columns to keep as document **variables** (few distinct values, e.g. age
#' group or field of study) and columns to **ignore** (time stamps, IP
#' addresses, ...). Pass the suggestions -- or your own choice -- to
#' [qda_import_survey()].
#'
#' @param file Path to a `.csv` (comma, semicolon or tab separated) or
#'   `.xlsx` file (needs the package 'readxl').
#' @param sheet Excel sheet (number or name).
#' @param name File name to show (e.g. the original name of an upload).
#' @return A tibble, one row per column: `column`, `role`, `answers`
#'   (non-empty cells), `distinct`, `mean_chars`, `example`. Attribute
#'   `"rows"`: number of respondents.
#' @export
#' @examples
#' f <- system.file("extdata", "survey_demo.csv", package = "jellyqda")
#' qda_survey_columns(f)
qda_survey_columns <- function(file, sheet = 1, name = NULL) {
  df <- .read_survey(file, sheet, name)
  r <- .survey_roles(df)
  out <- tibble::tibble(column = r$column, role = r$role, answers = as.integer(r$answers),
                        distinct = as.integer(r$distinct), mean_chars = round(r$mean_chars, 1),
                        example = r$example)
  attr(out, "rows") <- nrow(df)
  out
}

#' Import open answers from a survey (CSV or Excel)
#'
#' Turns a survey export (SoSci Survey, LimeSurvey, Qualtrics, Google Forms
#' ... saved as CSV or Excel) into documents: **one document per
#' respondent**, in it every **open answer** as its own segment (the
#' question as the first line, the answer below), and chosen columns as
#' **document variables** -- ready for coding, case comparison and queries
#' by group. With `code_questions = TRUE` every answer is already coded with
#' a code for its question (all below one code "Fragen" / "Questions"), so
#' you can filter and compare by question right away.
#'
#' Empty answers are left out; respondents without any open answer are
#' skipped. Importing the same file again skips respondents already
#' imported. The survey file is copied to `originals/`.
#'
#' @param file Path to a `.csv` or `.xlsx` file.
#' @param text Columns with open answers. Default: as suggested by
#'   [qda_survey_columns()].
#' @param vars Columns to store as document variables. Default: as
#'   suggested.
#' @param id Column with the respondent id; default as suggested, otherwise
#'   the row number.
#' @param sheet Excel sheet.
#' @param code_questions Logical; code every answer with a code for its
#'   question.
#' @param prefix Start of the document names (default: the file name), e.g.
#'   `"survey"` gives `survey_017`.
#' @param name File name to use for `originals/` and the default prefix (e.g.
#'   the original name of an upload).
#' @param pseudonyms Optional key list (see [qda_pseudonyms()]): names in the
#'   answers, the ids and the variable values are replaced before the text is
#'   frozen; the survey file is then not copied to `originals/`.
#' @return Invisibly, a tibble of the new documents (`id`, `name`, `format`,
#'   `chars`, `status`), like [qda_import()]. Attribute `"skipped"`: number
#'   of respondents without answers or already imported.
#' @seealso [qda_survey_columns()]
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "survey.jellyqda"))
#' f <- system.file("extdata", "survey_demo.csv", package = "jellyqda")
#' qda_survey_columns(f)
#' qda_import_survey(f, code_questions = TRUE)
#' qda_sources()[, c("name", "segments")]
#' qda_source_vars(1)
#' qda_close()
qda_import_survey <- function(file, text = NULL, vars = NULL, id = NULL, sheet = 1,
                              code_questions = FALSE, prefix = NULL, name = NULL, pseudonyms = NULL) {
  con <- qda_con()
  key <- if (!is.null(pseudonyms)) qda_pseudonyms(pseudonyms) else NULL   # R/pseudonymise.R
  pz <- function(x) if (length(key)) .pseudo_apply(x, key)$text else x
  n_pseudo <- 0L
  file <- normalizePath(file, mustWork = TRUE)
  fname <- basename(name %||% file)
  df <- .read_survey(file, sheet, fname)
  roles <- .survey_roles(df)
  if (is.null(text)) text <- roles$column[roles$role == "text"]
  if (is.null(vars)) vars <- roles$column[roles$role == "variable"]
  if (is.null(id)) id <- roles$column[roles$role == "id"][1]
  text <- as.character(text); vars <- as.character(vars)
  bad <- setdiff(c(text, vars, stats::na.omit(id)), names(df))
  if (length(bad)) stop(sprintf("Column(s) not in the survey: %s", paste(bad, collapse = ", ")), call. = FALSE)
  if (length(text) == 0) stop("No column with open answers: give `text`.", call. = FALSE)
  ids <- if (!is.na(id %||% NA) && nzchar(id %||% "")) df[[id]] else sprintf("%03d", seq_len(nrow(df)))
  ids[!nzchar(ids)] <- sprintf("row%03d", which(!nzchar(ids)))
  prefix <- prefix %||% sub("\\.[A-Za-z0-9]+$", "", fname)
  sha <- digest::digest(file, algo = "sha256", file = TRUE)
  known <- vapply(DBI::dbGetQuery(con, "SELECT meta_json FROM sources")$meta_json,
                  function(m) { x <- jsonlite::fromJSON(m); if (is.null(x$survey_sha256)) "" else paste(x$survey_sha256, x$respondent) },
                  character(1))
  # original survey file, once
  odir <- file.path(project_dir(), "originals"); dir.create(odir, recursive = TRUE, showWarnings = FALSE)
  orig <- .unique_name(fname, list.files(odir))
  if (!length(key) && !any(grepl(sha, known, fixed = TRUE))) file.copy(file, file.path(odir, orig))
  taken <- DBI::dbGetQuery(con, "SELECT name FROM sources")$name
  rows <- list(); skipped <- 0L; answer_pos <- list()
  DBI::dbWithTransaction(con, {
    for (i in seq_len(nrow(df))) {
      if (paste(sha, pz(ids[i])) %in% known) { skipped <- skipped + 1L; next }
      ans <- .survey_clean(vapply(text, function(cl) df[[cl]][i], character(1)))
      if (length(key)) { ps <- .pseudo_apply(ans, key); ans <- ps$text; n_pseudo <- n_pseudo + sum(ps$counts) }
      has <- nzchar(ans)
      if (!any(has)) { skipped <- skipped + 1L; next }
      d <- .survey_doc(text[has], ans[has])
      body <- d$body; a_start <- d$a_start; a_end <- d$a_end
      nm <- .unique_name(pz(paste0(prefix, "_", ids[i])), taken); taken <- c(taken, nm)
      v <- if (length(vars)) stats::setNames(as.list(vapply(vars, function(cl) df[[cl]][i], character(1))), vars) else list()
      v <- lapply(v[nzchar(unlist(v))], pz)
      meta <- list(file = nm, original = if (length(key)) NULL else file.path("originals", orig), survey = fname,
                   survey_sha256 = sha, respondent = pz(ids[i]), format = "survey", imported_at = .now(), variables = v,
                   pseudonymised = if (length(key)) TRUE else NULL)
      DBI::dbExecute(con, "INSERT INTO sources (name, format, frozen_text, meta_json) VALUES (?, ?, ?, ?)",
                     params = list(nm, "survey", body, as.character(.to_json(meta))))
      sid <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
      answer_pos[[length(answer_pos) + 1]] <- data.frame(sid = sid, question = text[has], start = a_start, end = a_end,
                                                         stringsAsFactors = FALSE)
      rows[[length(rows) + 1]] <- tibble::tibble(id = as.integer(sid), name = nm, format = "survey",
                                                 chars = nchar(body, type = "chars"), status = "ok")
    }
  })
  out <- if (length(rows)) do.call(rbind, rows) else
    tibble::tibble(id = integer(), name = character(), format = character(), chars = integer(), status = character())
  log_event("import", list(survey = fname, documents = nrow(out), skipped = skipped,
                           questions = length(text), variables = length(vars),
                           pseudonymised = if (length(key)) n_pseudo else NULL,
                           desc = sprintf(.t("Fragebogen importiert: %s (%d Dokumente, %d offene Fragen)"),
                                          fname, nrow(out), length(text))))
  # optional: one code per question, every answer coded with it (one undo step)
  if (isTRUE(code_questions) && length(answer_pos)) {
    ap <- do.call(rbind, answer_pos)
    parent_label <- .t("Fragen")
    tr <- .code_categories()
    pid <- tr$id[tr$label == parent_label & tr$depth == 1L][1]
    if (is.na(pid)) pid <- qda_code_add(parent_label)$id
    qlab <- function(x) { x <- gsub("\\s+", " ", x); if (nchar(x) > 60) paste0(substr(x, 1, 59), "\u2026") else x }
    cids <- vapply(unique(ap$question), function(qq) {
      lab <- qlab(qq)
      ex <- DBI::dbGetQuery(con, "SELECT id FROM codes WHERE label = ? AND parent_id = ?", params = list(lab, pid))$id
      if (length(ex)) ex[1] else qda_code_add(lab, parent = pid)$id
    }, numeric(1))
    cids <- stats::setNames(cids, unique(ap$question))
    new_ids <- integer(nrow(ap))
    DBI::dbWithTransaction(con, {
      for (k in seq_len(nrow(ap))) {
        DBI::dbExecute(con, "INSERT INTO codings (source_id, code_id, start, end, memo) VALUES (?, ?, ?, ?, '')",
                       params = list(ap$sid[k], as.integer(cids[[ap$question[k]]]), as.integer(ap$start[k]), as.integer(ap$end[k])))
        new_ids[k] <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
      }
    })
    log_event("coding_add", list(survey = fname, by_question = TRUE, n = length(new_ids)),
              changes = list(.chg("codings", .snap("codings", integer()), .snap("codings", new_ids))),
              desc = sprintf(.t("Antworten nach Frage codiert: %d Stellen"), length(new_ids)))
  }
  attr(out, "skipped") <- skipped
  invisible(out)
}
