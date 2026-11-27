# jellyqda :: analysis.R -- tools for deductive and inductive analysis
#
#   qda_code_guide()          coding guideline per code: definition, anchor
#                             example, coding rule (deductive, Mayring / Kuckartz)
#   qda_code_merge()          merge two codes (inductive: condensing categories)
#   qda_autocode()            code every occurrence of a search term
#   qda_coding_set_summary()  paraphrase + generalisation per coding
#                             (Mayring's summarising content analysis)
#   qda_words()               word frequencies (without stop words)
#   qda_kwic()                keyword in context
#   qda_case_matrix()         case comparison: codes x values of a variable
#
# Every changing function writes one audit-trail event with a before/after
# snapshot, so each of them is undone in one step (Ctrl+Z / qda_undo()).

# Coding guideline -------------------------------------------------------------

#' Set the coding guideline of a code (definition, anchor example, rule)
#'
#' The three columns of a coding guideline ("Kodierleitfaden") as used in
#' qualitative content analysis (Mayring, Kuckartz): a **definition** of the
#' category, one or more **anchor examples** (typical passages) and a
#' **coding rule** (how to decide borderline cases). Arguments left `NULL`
#' are not changed. The definition is stored in the column `description`.
#'
#' @param code Code id or unique label.
#' @param definition,anchor,rule New text, or `NULL` to keep the current one.
#' @param append_anchor Logical; add `anchor` as a further example instead of
#'   replacing the existing anchor examples.
#' @return Invisibly, a one-row tibble with the updated guideline.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_code_guide("SME",
#'   definition = "Statements about working in a small or medium-sized enterprise",
#'   rule = "Only explicit statements; comparisons with corporations -> other code")
#' qda_code_guide("SME", anchor = "'I have worked in a small company for 5 years'",
#'                append_anchor = TRUE)
#' qda_codes()[, c("label", "description", "anchor", "coding_rule")]
#' qda_close()
qda_code_guide <- function(code, definition = NULL, anchor = NULL, rule = NULL,
                           append_anchor = FALSE) {
  con <- qda_con()
  row <- .resolve_code(code)
  old_anchor <- if (is.na(row$anchor %||% NA)) "" else row$anchor
  new_def <- if (is.null(definition)) row$description else as.character(definition)
  new_anchor <- if (is.null(anchor)) old_anchor else if (isTRUE(append_anchor) && nzchar(old_anchor)) {
    paste(old_anchor, as.character(anchor), sep = "\n")
  } else as.character(anchor)
  new_rule <- if (is.null(rule)) (if (is.na(row$coding_rule %||% NA)) "" else row$coding_rule) else as.character(rule)
  before <- .snap("codes", row$id)
  DBI::dbExecute(con, "UPDATE codes SET description = ?, anchor = ?, coding_rule = ? WHERE id = ?",
                 params = list(new_def, new_anchor, new_rule, row$id))
  log_event("code_update", list(code_id = row$id, guide = TRUE),
            changes = list(.chg("codes", before, .snap("codes", row$id))),
            desc = sprintf(.t("Kodierleitfaden von '%s' ge\u00e4ndert"), row$label))
  invisible(tibble::tibble(id = row$id, label = row$label, definition = new_def,
                           anchor = new_anchor, coding_rule = new_rule))
}

# Merging codes ----------------------------------------------------------------

#' Merge a code into another code
#'
#' All codings, code memos and summaries of `from` move to `into`; subcodes
#' of `from` become subcodes of `into` (a subcode with the same label as an
#' existing subcode of `into` is merged into it as well). The guideline texts
#' are kept (appended where both codes have one). Finally `from` is deleted.
#' Typical step of inductive category building: two categories turn out to
#' mean the same. Undo restores everything in one step.
#'
#' @param from Code that disappears (id or unique label).
#' @param into Code that remains (id or unique label).
#' @return Invisibly, a one-row tibble: `into`, number of `codings_moved`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Interest")
#' qda_code_add("Intrinsic")
#' qda_code(1, "Interest", segment = 2)
#' qda_code_merge("Interest", into = "Intrinsic")
#' qda_codings()$code
#' qda_undo()   # both codes are back
#' qda_close()
qda_code_merge <- function(from, into) {
  con <- qda_con()
  a <- .resolve_code(from)
  b <- .resolve_code(into)
  if (a$id == b$id) stop("A code cannot be merged into itself.", call. = FALSE)
  all <- DBI::dbGetQuery(con, "SELECT id, label, parent_id FROM codes")
  if (b$id %in% .code_descendants(all, a$id)) {
    stop("Cannot merge a code into one of its own subcodes.", call. = FALSE)
  }
  code_ids <- unique(c(.code_descendants(all, a$id), .code_descendants(all, b$id)))
  fam_a <- .code_descendants(all, a$id)
  in_a <- paste(fam_a, collapse = ",")
  in_all <- paste(code_ids, collapse = ",")
  cod_ids <- DBI::dbGetQuery(con, sprintf("SELECT id FROM codings WHERE code_id IN (%s)", in_a))$id
  memo_ids <- DBI::dbGetQuery(con, sprintf("SELECT id FROM memos WHERE code_id IN (%s)", in_a))$id
  sum_ids <- DBI::dbGetQuery(con, sprintf("SELECT id FROM summaries WHERE code_id IN (%s)", in_all))$id
  before <- list(codes = .snap("codes", code_ids), codings = .snap("codings", cod_ids),
                 memos = .snap("memos", memo_ids), summaries = .snap("summaries", sum_ids))
  join_txt <- function(x, y) {
    x <- if (is.na(x)) "" else x; y <- if (is.na(y)) "" else y
    if (!nzchar(x)) y else if (!nzchar(y) || identical(x, y)) x else paste(x, y, sep = "\n")
  }
  merge_rec <- function(fid, tid) {
    f <- DBI::dbGetQuery(con, "SELECT * FROM codes WHERE id = ?", params = list(fid))
    t <- DBI::dbGetQuery(con, "SELECT * FROM codes WHERE id = ?", params = list(tid))
    DBI::dbExecute(con, "UPDATE codings SET code_id = ? WHERE code_id = ?", params = list(tid, fid))
    DBI::dbExecute(con, "UPDATE memos SET code_id = ? WHERE code_id = ?", params = list(tid, fid))
    sf <- DBI::dbGetQuery(con, "SELECT id, source_id, text_ FROM summaries WHERE code_id = ?", params = list(fid))
    for (i in seq_len(nrow(sf))) {
      st <- DBI::dbGetQuery(con, "SELECT id, text_ FROM summaries WHERE code_id = ? AND source_id = ?",
                            params = list(tid, sf$source_id[i]))
      if (nrow(st)) {
        DBI::dbExecute(con, "UPDATE summaries SET text_ = ? WHERE id = ?",
                       params = list(join_txt(st$text_[1], sf$text_[i]), st$id[1]))
        DBI::dbExecute(con, "DELETE FROM summaries WHERE id = ?", params = list(sf$id[i]))
      } else {
        DBI::dbExecute(con, "UPDATE summaries SET code_id = ? WHERE id = ?", params = list(tid, sf$id[i]))
      }
    }
    DBI::dbExecute(con, "UPDATE codes SET description = ?, anchor = ?, coding_rule = ? WHERE id = ?",
                   params = list(join_txt(t$description, f$description), join_txt(t$anchor, f$anchor),
                                 join_txt(t$coding_rule, f$coding_rule), tid))
    kids <- DBI::dbGetQuery(con, "SELECT id, label FROM codes WHERE parent_id = ?", params = list(fid))
    for (k in seq_len(nrow(kids))) {
      clash <- DBI::dbGetQuery(con, "SELECT id FROM codes WHERE parent_id = ? AND label = ?",
                               params = list(tid, kids$label[k]))
      if (nrow(clash)) merge_rec(kids$id[k], clash$id[1])
      else DBI::dbExecute(con, "UPDATE codes SET parent_id = ? WHERE id = ?", params = list(tid, kids$id[k]))
    }
    DBI::dbExecute(con, "DELETE FROM codes WHERE id = ?", params = list(fid))
  }
  DBI::dbWithTransaction(con, merge_rec(a$id, b$id))
  log_event("code_merge", list(from = a$id, into = b$id, from_label = a$label, into_label = b$label,
                               codings = length(cod_ids)),
            changes = list(.chg("codes", before$codes, .snap("codes", code_ids)),
                           .chg("codings", before$codings, .snap("codings", cod_ids)),
                           .chg("memos", before$memos, .snap("memos", memo_ids)),
                           .chg("summaries", before$summaries, .snap("summaries", sum_ids))),
            desc = sprintf(.t("Codes zusammengef\u00fchrt: '%s' -> '%s' (%d Codings)"),
                           a$label, b$label, length(cod_ids)))
  invisible(tibble::tibble(into = b$id, codings_moved = length(cod_ids)))
}

# Coding automatically ---------------------------------------------------------

# Positions (1-based, inclusive) of `pattern` in `text`, as a 2-col matrix.
#' @noRd
.find_all <- function(text, pattern, ignore_case = TRUE, whole_word = FALSE) {
  if (!nzchar(pattern) || !nzchar(text)) return(matrix(integer(), ncol = 2))
  if (isTRUE(whole_word)) {
    rx <- paste0("(?<![\\p{L}\\p{N}_])",
                 gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", pattern),
                 "(?![\\p{L}\\p{N}_])")
    m <- stringi::stri_locate_all_regex(text, rx,
           opts_regex = stringi::stri_opts_regex(case_insensitive = isTRUE(ignore_case)))[[1]]
  } else {
    m <- stringi::stri_locate_all_fixed(text, pattern,
           opts_fixed = stringi::stri_opts_fixed(case_insensitive = isTRUE(ignore_case)))[[1]]
  }
  m[!is.na(m[, 1]), , drop = FALSE]
}

#' Code every occurrence of a search term
#'
#' Finds `pattern` (plain text, not a regular expression) in the documents
#' and codes either the **match** itself or the whole **segment** containing
#' it. Places already coded with this code (same range) are skipped. All new
#' codings form one action: one undo removes them all again. Useful for
#' deductive codes that are tied to clear terms -- and for a first pass that
#' is then checked by hand.
#'
#' @param pattern Search term (plain text).
#' @param code Code id or unique label.
#' @param scope `"match"` (only the found words) or `"segment"` (the whole
#'   segment, e.g. the speaker turn, around each match).
#' @param source Optional source(s) (ids or names); default all.
#' @param ignore_case Logical.
#' @param whole_word Logical; only whole words (default: also inside words).
#' @param memo Optional comment for every new coding.
#' @return Invisibly, a tibble of the new codings.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Project")
#' qda_autocode("project", code = "Project")                      # the matches
#' qda_autocode("project", code = "Project", scope = "segment")   # whole segments
#' qda_codings()[, c("code", "start", "end")]
#' qda_close()
qda_autocode <- function(pattern, code, scope = c("match", "segment"), source = NULL,
                         ignore_case = TRUE, whole_word = FALSE, memo = "") {
  con <- qda_con()
  scope <- match.arg(scope)
  pattern <- as.character(pattern)
  if (!nzchar(trimws(pattern))) stop("pattern must not be empty.", call. = FALSE)
  cod <- .resolve_code(code)
  src_ids <- if (is.null(source)) qda_sources()$id else vapply(source, function(s) .resolve_source(s)$id, numeric(1))
  ranges <- list()
  for (sid in src_ids) {
    src <- .resolve_source(sid)
    m <- .find_all(src$frozen_text, pattern, ignore_case, whole_word)
    if (nrow(m) == 0) next
    if (scope == "segment") {
      sg <- .segments_for(src)
      k <- vapply(m[, 1], function(p) { i <- which(sg$start <= p & sg$end >= p); if (length(i)) i[1] else NA_integer_ },
                  integer(1))
      m <- unique(cbind(sg$start[k[!is.na(k)]], sg$end[k[!is.na(k)]]))
    }
    if (nrow(m)) ranges[[length(ranges) + 1]] <- data.frame(source_id = sid, start = m[, 1], end = m[, 2])
  }
  ranges <- if (length(ranges)) do.call(rbind, ranges) else data.frame(source_id = integer(), start = integer(), end = integer())
  have <- DBI::dbGetQuery(con, "SELECT source_id, start, end FROM codings WHERE code_id = ?", params = list(cod$id))
  if (nrow(ranges) && nrow(have)) {
    ranges <- ranges[!paste(ranges$source_id, ranges$start, ranges$end) %in%
                       paste(have$source_id, have$start, have$end), , drop = FALSE]
  }
  if (nrow(ranges) == 0) {
    return(invisible(tibble::tibble(id = integer(), source_id = integer(), code_id = integer(),
                                    start = integer(), end = integer())))
  }
  ids <- integer(nrow(ranges))
  DBI::dbWithTransaction(con, {
    for (i in seq_len(nrow(ranges))) {
      DBI::dbExecute(con, "INSERT INTO codings (source_id, code_id, start, end, memo) VALUES (?, ?, ?, ?, ?)",
                     params = list(as.integer(ranges$source_id[i]), cod$id, as.integer(ranges$start[i]),
                                   as.integer(ranges$end[i]), as.character(memo)))
      ids[i] <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
    }
  })
  log_event("coding_add", list(code_id = cod$id, autocode = pattern, scope = scope, n = length(ids)),
            changes = list(.chg("codings", .snap("codings", integer()), .snap("codings", ids))),
            desc = sprintf(.t("Automatisch codiert: %d Stellen mit '%s' (Suche '%s', %s)"),
                           length(ids), cod$label, pattern, if (scope == "match") .t("Treffer") else .t("Segmente")))
  invisible(tibble::tibble(id = ids, source_id = as.integer(ranges$source_id), code_id = cod$id,
                           start = as.integer(ranges$start), end = as.integer(ranges$end)))
}

# Mayring: paraphrase and generalisation ---------------------------------------

#' Set paraphrase and generalisation of a coding (Mayring)
#'
#' The steps of Mayring's summarising content analysis per coded passage:
#' **paraphrase** (the content in short, own words) and **generalisation**
#' (raised to the abstraction level of the analysis). The reduction step is
#' the code itself. Arguments left `NULL` are not changed.
#'
#' @param coding Coding id.
#' @param paraphrase,generalization New text or `NULL`.
#' @return Invisibly, a one-row tibble with the updated texts.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_code(1, "SME", segment = 2)
#' qda_coding_set_summary(1, paraphrase = "Works in a small company",
#'                        generalization = "Career in an SME")
#' qda_codings()[, c("code", "paraphrase", "generalization")]
#' qda_close()
qda_coding_set_summary <- function(coding, paraphrase = NULL, generalization = NULL) {
  con <- qda_con()
  row <- .resolve_coding(coding)
  cur <- DBI::dbGetQuery(con, "SELECT paraphrase, generalization FROM codings WHERE id = ?",
                         params = list(row$id))
  nz <- function(x) if (is.null(x) || length(x) == 0 || is.na(x)) "" else as.character(x)
  p <- if (is.null(paraphrase)) nz(cur$paraphrase) else as.character(paraphrase)
  g <- if (is.null(generalization)) nz(cur$generalization) else as.character(generalization)
  before <- .snap("codings", row$id)
  DBI::dbExecute(con, "UPDATE codings SET paraphrase = ?, generalization = ? WHERE id = ?",
                 params = list(p, g, row$id))
  log_event("coding_update", list(coding_id = row$id, summary = TRUE),
            changes = list(.chg("codings", before, .snap("codings", row$id))),
            desc = sprintf(.t("Paraphrase/Generalisierung von Coding #%d ge\u00e4ndert"), row$id))
  invisible(tibble::tibble(id = row$id, paraphrase = p, generalization = g))
}

# Word frequencies and keyword in context ----------------------------------------

#' Word frequencies
#'
#' Counts the words of all documents, one document, or only of the passages
#' coded with a code (incl. its subcodes) -- an entry point for inductive
#' work. Words are lower-cased; numbers, time stamps and stop words are left
#' out.
#'
#' @param source Optional source id or name.
#' @param code Optional code id or label: only words inside its codings
#'   (and those of its subcodes).
#' @param n Number of words to return (most frequent first); `Inf` for all.
#' @param min_chars Minimum word length.
#' @param stopwords `TRUE` (built-in German and English lists), `FALSE`, or a character
#'   vector of further words to leave out (added to the built-in list).
#' @return A tibble: `word`, `n` (occurrences), `sources` (in how many
#'   documents).
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_code(1, "SME", segment = 2)
#' qda_words(n = 10)
#' qda_words(code = "Career path")   # only within these codings
#' qda_close()
qda_words <- function(source = NULL, code = NULL, n = 50, min_chars = 3, stopwords = TRUE) {
  if (!is.null(code)) {
    codes <- qda_codes()
    ids <- .code_descendants(codes, .resolve_code(code)$id)
    cd <- qda_codings(source = source)
    cd <- cd[cd$code_id %in% ids, , drop = FALSE]
    texts <- cd$text; doc <- cd$source_id
  } else {
    s <- qda_sources()
    if (!is.null(source)) s <- s[s$id == .resolve_source(source)$id, , drop = FALSE]
    texts <- vapply(s$id, function(i) .resolve_source(i)$frozen_text, character(1)); doc <- s$id
  }
  empty <- tibble::tibble(word = character(), n = integer(), sources = integer())
  if (length(texts) == 0) return(empty)
  w <- stringi::stri_extract_all_regex(stringi::stri_trans_tolower(texts), "\\p{L}[\\p{L}\\-']*\\p{L}|\\p{L}")
  df <- data.frame(word = unlist(w), doc = rep(doc, lengths(w)), stringsAsFactors = FALSE)
  df <- df[!is.na(df$word) & nchar(df$word) >= min_chars, , drop = FALSE]
  stop_list <- if (isFALSE(stopwords)) character() else c(.STOPWORDS_DE, .STOPWORDS_EN, if (is.character(stopwords)) tolower(stopwords))  # R/stopwords.R
  # compare via ASCII escapes: works without a UTF-8 locale as well
  df <- df[!stringi::stri_escape_unicode(df$word) %in% stringi::stri_escape_unicode(enc2utf8(stop_list)), , drop = FALSE]
  if (nrow(df) == 0) return(empty)
  cnt <- table(df$word)
  docs <- tapply(df$doc, df$word, function(x) length(unique(x)))
  out <- tibble::tibble(word = names(cnt), n = as.integer(cnt), sources = as.integer(docs[names(cnt)]))
  out <- out[order(-out$n, out$word), , drop = FALSE]
  if (is.finite(n)) out <- utils::head(out, n)
  out
}

#' Keyword in context (KWIC)
#'
#' Every occurrence of a word or phrase with the text to its left and right
#' -- to see how a term is used across all interviews.
#'
#' @param pattern Word or phrase (plain text).
#' @param source Optional source id or name.
#' @param width Characters of context on each side.
#' @param ignore_case Logical.
#' @param whole_word Logical; only whole words.
#' @return A tibble: `source_id`, `source`, `segment`, `start`, `end`,
#'   `left`, `match`, `right`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_kwic("colleague", width = 30)
#' qda_kwic("inform", whole_word = FALSE)   # also inside words ("informatics")
#' qda_close()
qda_kwic <- function(pattern, source = NULL, width = 50, ignore_case = TRUE, whole_word = TRUE) {
  s <- qda_sources()
  if (!is.null(source)) s <- s[s$id == .resolve_source(source)$id, , drop = FALSE]
  out <- list()
  for (sid in s$id) {
    src <- .resolve_source(sid)
    txt <- src$frozen_text
    m <- .find_all(txt, as.character(pattern), ignore_case, whole_word)
    if (nrow(m) == 0) next
    sg <- .segments_for(src)
    flat <- function(x) gsub("\\s+", " ", x)
    out[[length(out) + 1]] <- tibble::tibble(
      source_id = sid, source = src$name,
      segment = vapply(m[, 1], function(p) { i <- which(sg$start <= p & sg$end >= p); if (length(i)) as.integer(i[1]) else NA_integer_ }, integer(1)),
      start = as.integer(m[, 1]), end = as.integer(m[, 2]),
      left = flat(substring(txt, pmax(1L, m[, 1] - width), m[, 1] - 1L)),
      match = substring(txt, m[, 1], m[, 2]),
      right = flat(substring(txt, m[, 2] + 1L, m[, 2] + width)))
  }
  if (length(out) == 0) {
    return(tibble::tibble(source_id = integer(), source = character(), segment = integer(),
                          start = integer(), end = integer(), left = character(),
                          match = character(), right = character()))
  }
  do.call(rbind, out)
}

# Case comparison -------------------------------------------------------------------

#' Case comparison: codes x values of a document variable
#'
#' Counts codings per code (rows, in code-tree order) and per value of a
#' document variable (columns), e.g. `by = "Rolle"`. Codes count their
#' subcodes as well (column `with_subcodes`). Documents without the variable
#' are collected in the column `(ohne)`.
#'
#' @param by Name of a document variable (see [qda_source_set_var()]).
#' @param percent Logical; column percentages (share of all codings of the
#'   group) instead of counts.
#' @return A tibble: `code`, `path`, `depth`, then one column per value.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", c("interview_01.txt", "interview_02.md"), package = "jellyqda"))
#' qda_source_set_var(1, "role", "project lead")
#' qda_source_set_var(2, "role", "developer")
#' qda_code_add("Motivation")
#' qda_code(1, "Motivation", segment = 2)
#' qda_code(2, "Motivation", segment = 1)
#' qda_case_matrix("role")
#' qda_case_matrix("role", percent = TRUE)
#' qda_close()
qda_case_matrix <- function(by, percent = FALSE) {
  s <- qda_sources()
  val <- vapply(s$id, function(i) { v <- qda_source_vars(i)[by]; if (is.na(v)) "(ohne)" else unname(v) }, character(1))
  groups <- sort(unique(val))
  if ("(ohne)" %in% groups) groups <- c(setdiff(groups, "(ohne)"), "(ohne)")
  tr <- .code_tree(qda_codes())
  cd <- qda_codings()
  grp_of <- val[match(cd$source_id, s$id)]
  out <- tibble::tibble(code = tr$label, path = tr$path, depth = tr$depth)
  for (g in groups) {
    out[[g]] <- vapply(tr$id, function(i) {
      sum(cd$code_id %in% .code_descendants(tr, i) & grp_of == g)
    }, integer(1))
    if (isTRUE(percent)) {
      tot <- sum(grp_of == g)
      out[[g]] <- if (tot > 0) round(100 * out[[g]] / tot, 1) else 0
    }
  }
  attr(out, "n_documents") <- stats::setNames(as.integer(table(factor(val, levels = groups))), groups)
  out
}
