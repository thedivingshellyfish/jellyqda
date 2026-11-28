# jellyqda :: merge.R -- qda_merge(): bring the work of a team copy back
#
# Team workflow: one person sets up the project (documents, code system,
# coding guideline) and hands out copies (e.g. qda_intercoder_copy(), or
# simply the file). Everyone codes their part -- or imports and codes their
# own interviews. qda_merge() then takes everything from such a copy into
# the open project:
#
#   documents   matched by their frozen text (not by name); documents that
#               exist only in the copy are added (add_documents = TRUE)
#   codes       matched by their path ("Team / Support"); missing codes are
#               created below the right parent; empty guideline fields are
#               filled in
#   codings     added unless the same code already covers the same passage
#   memos       added unless an identical memo is already there
#   variables   document and case variables: missing ones are added; a
#               different value is a conflict -- the open project keeps its own
#   summaries   summary grid cells that are still empty here
#   cases       matched by name; members and variables as above
#
# The copy is only read (opened read-only). With dry_run = TRUE nothing is
# written (the merge runs in a transaction that is rolled back), so the app
# can show what would happen. A real merge first writes a backup -- merging
# is not undone with Ctrl+Z but by restoring that backup (qda_backup()).

#' Read one table of the other project ("" columns that do not exist there
#' come back as NA, so older project files can be merged too).
#' @noRd
.merge_read <- function(oc, table, cols) {
  if (!table %in% DBI::dbListTables(oc)) {
    return(as.data.frame(stats::setNames(replicate(length(cols), logical(), simplify = FALSE), cols)))
  }
  have <- DBI::dbGetQuery(oc, sprintf("PRAGMA table_info(%s)", table))$name
  df <- DBI::dbGetQuery(oc, sprintf("SELECT %s FROM %s ORDER BY id", paste0('"', intersect(cols, have), '"', collapse = ", "), table))
  for (c in setdiff(cols, have)) df[[c]] <- rep(NA, nrow(df))
  for (c in names(df)) df[[c]] <- .utf8(df[[c]])
  df[, cols, drop = FALSE]
}

#' A value, or `default` when it is NULL or NA.
#' @noRd
.or <- function(x, default) if (is.null(x) || length(x) == 0 || is.na(x)) default else x

#' Variables from a meta_json string (named character).
#' @noRd
.merge_vars <- function(json) {
  v <- tryCatch(jsonlite::fromJSON(json %||% "{}")$variables, error = function(e) NULL)
  if (is.null(v)) character() else { v <- unlist(v); stats::setNames(as.character(v), names(v)) }
}

#' Add the variables `theirs` to the meta_json `ours`: returns list(json, added, conflicts).
#' @noRd
.merge_fill_vars <- function(ours_json, theirs) {
  m <- tryCatch(jsonlite::fromJSON(ours_json %||% "{}"), error = function(e) list())
  if (is.null(m$variables)) m$variables <- list()
  added <- 0L; conflicts <- 0L
  for (k in names(theirs)) {
    cur <- m$variables[[k]]
    if (is.null(cur)) { m$variables[[k]] <- theirs[[k]]; added <- added + 1L }
    else if (!identical(as.character(cur), theirs[[k]])) conflicts <- conflicts + 1L
  }
  list(json = .to_json(m), added = added, conflicts = conflicts)
}

#' Merge another project file into the open project
#'
#' Takes documents, codes, codings, memos, variables, summary grid cells and
#' cases from another jellyqda project -- typically the copy a team member
#' coded -- into the open project. Documents are recognised by their text,
#' codes by their path; nothing that is already there is added twice, and
#' where both projects have a different value (a variable, a summary) the
#' open project keeps its own and the difference is counted as a conflict.
#'
#' Run it with `dry_run = TRUE` first to see what would be added. A real
#' merge writes a backup of the open project first ([qda_backup()]); it is
#' not undone with [qda_undo()] but by restoring that backup. The other file
#' is only read.
#'
#' @param other Path to the other `.jellyqda` file.
#' @param add_documents Logical; also add documents that exist only in the
#'   other project (default `TRUE`). With `FALSE` their codings are skipped.
#' @param dry_run Logical; only report what would be merged.
#' @param backup Logical; write a backup before merging (default `TRUE`).
#' @return A tibble with one row per kind of data: `what`, `added`,
#'   `already` (already there, skipped) and `conflicts`. Attributes `"file"`
#'   and `"dry_run"`.
#' @seealso [qda_intercoder_copy()] to hand out copies,
#'   [qda_intercoder_adopt()] to take over single codings
#' @export
#' @examples
#' dir <- tempfile()
#' qda_open(file.path(dir, "team.jellyqda"))
#' qda_import(system.file("extdata", c("interview_01.txt", "interview_02.md"), package = "jellyqda"))
#' qda_code_add("Career path"); qda_code_add("Team")
#' copy <- qda_intercoder_copy(file.path(dir, "anna.jellyqda"))   # a copy for Anna
#' qda_code(1, "Team", segment = 3)                                 # you code document 1
#' qda_close()
#' qda_open(copy)                                                   # Anna codes document 2
#' qda_code(2, "Career path", segment = 2); qda_code_add("Motivation")
#' qda_code(2, "Motivation", segment = 4)
#' qda_close()
#' qda_open(file.path(dir, "team.jellyqda"))
#' qda_merge(copy, dry_run = TRUE)                                  # what would happen?
#' qda_merge(copy)
#' qda_codings()[, c("source", "code")]
#' qda_close()
qda_merge <- function(other, add_documents = TRUE, dry_run = FALSE, backup = TRUE) {
  con <- qda_con()
  other <- normalizePath(other, mustWork = TRUE)
  if (identical(other, normalizePath(project_path(), mustWork = FALSE))) stop("That is the open project itself.", call. = FALSE)
  oc <- DBI::dbConnect(RSQLite::SQLite(), other, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(oc), add = TRUE)
  if (!all(c("sources", "codes", "codings") %in% DBI::dbListTables(oc))) stop("This is not a jellyqda project file.", call. = FALSE)
  O <- list(
    sources = .merge_read(oc, "sources", c("id", "name", "format", "frozen_text", "meta_json")),
    codes = .merge_read(oc, "codes", c("id", "label", "parent_id", "color", "description", "anchor", "coding_rule")),
    codings = .merge_read(oc, "codings", c("id", "source_id", "code_id", "start", "end", "memo", "paraphrase", "generalization")),
    memos = .merge_read(oc, "memos", c("id", "kind", "title", "text_", "source_id", "code_id", "start", "end", "created_at", "updated_at")),
    summaries = .merge_read(oc, "summaries", c("id", "code_id", "source_id", "text_", "updated_at")),
    segments = .merge_read(oc, "segments", c("id", "source_id", "start", "end")),
    cases = .merge_read(oc, "cases", c("id", "name", "description", "meta_json")),
    members = .merge_read(oc, "case_members", c("id", "case_id", "source_id", "start", "end")))
  n <- list()
  count <- function(what, added = 0L, already = 0L, conflicts = 0L) {
    old <- n[[what]] %||% c(0L, 0L, 0L)
    n[[what]] <<- old + c(added, already, conflicts)
  }
  if (!dry_run && isTRUE(backup)) qda_backup(quiet = TRUE)
  DBI::dbBegin(con)
  ok <- FALSE
  on.exit(if (!ok) try(DBI::dbRollback(con), silent = TRUE), add = TRUE)

  # --- documents: by text ------------------------------------------------------------
  hash <- function(x) vapply(x, digest::digest, character(1), algo = "md5", serialize = FALSE, USE.NAMES = FALSE)
  ours <- DBI::dbGetQuery(con, "SELECT id, name, meta_json FROM sources ORDER BY id")
  ours_hash <- hash(.texts(ours$id))
  smap <- stats::setNames(rep(NA_integer_, nrow(O$sources)), O$sources$id)
  for (i in seq_len(nrow(O$sources))) {
    s <- O$sources[i, ]
    k <- match(hash(s$frozen_text), ours_hash)
    if (!is.na(k)) {
      smap[[as.character(s$id)]] <- ours$id[k]
      fv <- .merge_fill_vars(DBI::dbGetQuery(con, "SELECT meta_json FROM sources WHERE id = ?", params = list(ours$id[k]))$meta_json,
                             .merge_vars(s$meta_json))
      if (fv$added > 0) DBI::dbExecute(con, "UPDATE sources SET meta_json = ? WHERE id = ?", params = list(fv$json, ours$id[k]))
      count("documents", already = 1L); count("variables", added = fv$added, conflicts = fv$conflicts)
    } else if (isTRUE(add_documents)) {
      taken <- DBI::dbGetQuery(con, "SELECT name FROM sources")$name
      m <- tryCatch(jsonlite::fromJSON(s$meta_json %||% "{}"), error = function(e) list())
      m$merged_from <- basename(other); m$original <- NULL     # the original file is not copied along
      DBI::dbExecute(con, "INSERT INTO sources (name, format, frozen_text, meta_json) VALUES (?, ?, ?, ?)",
                     params = list(.unique_name(s$name, .utf8(taken)), s$format, s$frozen_text, .to_json(m)))
      sid <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
      smap[[as.character(s$id)]] <- sid
      sg <- O$segments[O$segments$source_id == s$id, , drop = FALSE]
      for (j in seq_len(nrow(sg))) DBI::dbExecute(con, "INSERT INTO segments (source_id, start, end) VALUES (?, ?, ?)",
                                                  params = list(sid, sg$start[j], sg$end[j]))
      count("documents", added = 1L)
    }
  }
  skipped_docs <- sum(is.na(smap))

  # --- codes: by path, parents first ----------------------------------------------------
  tr <- .code_tree(transform(O$codes, color = ifelse(is.na(O$codes$color), "#E69F00", O$codes$color)))
  opath <- stats::setNames(.code_paths(O$codes), O$codes$id)
  cmap <- stats::setNames(rep(NA_integer_, nrow(O$codes)), O$codes$id)
  for (cid in tr$id) {
    r <- O$codes[O$codes$id == cid, ]
    here <- DBI::dbGetQuery(con, "SELECT id, label, parent_id, description, anchor, coding_rule FROM codes")
    hp <- stats::setNames(.code_paths(here), here$id)
    k <- match(opath[[as.character(cid)]], hp)
    if (!is.na(k)) {
      cmap[[as.character(cid)]] <- here$id[k]
      fill <- c(description = r$description, anchor = r$anchor, coding_rule = r$coding_rule)
      cur <- c(description = here$description[k], anchor = here$anchor[k], coding_rule = here$coding_rule[k])
      todo <- names(fill)[!is.na(fill) & nzchar(fill) & (is.na(cur) | !nzchar(cur))]
      for (f in todo) DBI::dbExecute(con, sprintf("UPDATE codes SET %s = ? WHERE id = ?", f), params = list(fill[[f]], here$id[k]))
      count("codes", already = 1L)
    } else {
      par <- if (is.na(r$parent_id)) NA_integer_ else cmap[[as.character(r$parent_id)]]
      DBI::dbExecute(con, "INSERT INTO codes (label, parent_id, color, description, anchor, coding_rule) VALUES (?, ?, ?, ?, ?, ?)",
                     params = list(r$label, par, .or(r$color, "#E69F00"), .or(r$description, ""), .or(r$anchor, ""), .or(r$coding_rule, "")))
      cmap[[as.character(cid)]] <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
      count("codes", added = 1L)
    }
  }

  # --- codings ---------------------------------------------------------------------------
  have <- DBI::dbGetQuery(con, "SELECT source_id, code_id, start, end FROM codings")
  key <- paste(have$source_id, have$code_id, have$start, have$end)
  for (i in seq_len(nrow(O$codings))) {
    r <- O$codings[i, ]
    s <- smap[[as.character(r$source_id)]]; c <- cmap[[as.character(r$code_id)]]
    if (is.na(s) || is.na(c)) next       # document not added (add_documents = FALSE)
    k <- paste(s, c, r$start, r$end)
    if (k %in% key) { count("codings", already = 1L); next }
    DBI::dbExecute(con, "INSERT INTO codings (source_id, code_id, start, end, memo, paraphrase, generalization) VALUES (?, ?, ?, ?, ?, ?, ?)",
                   params = list(s, c, r$start, r$end, .or(r$memo, ""), .or(r$paraphrase, ""), .or(r$generalization, "")))
    key <- c(key, k); count("codings", added = 1L)
  }

  # --- memos -----------------------------------------------------------------------------
  hm <- DBI::dbGetQuery(con, "SELECT kind, title, text_, source_id, code_id, start, end FROM memos")
  mkey <- function(kind, title, text, s, c, a, b) paste(kind, title, text, s, c, a, b, sep = "\r")
  keys <- mkey(hm$kind, .utf8(hm$title), .utf8(hm$text_), hm$source_id, hm$code_id, hm$start, hm$end)
  for (i in seq_len(nrow(O$memos))) {
    r <- O$memos[i, ]
    kind <- .or(r$kind, "project")
    s <- if (is.na(r$source_id)) NA_integer_ else smap[[as.character(r$source_id)]]
    c <- if (is.na(r$code_id)) NA_integer_ else cmap[[as.character(r$code_id)]]
    if ((!is.na(r$source_id) && is.na(s)) || (!is.na(r$code_id) && is.na(c))) next
    k <- mkey(kind, .or(r$title, ""), r$text_, s, c, r$start, r$end)
    if (k %in% keys) { count("memos", already = 1L); next }
    DBI::dbExecute(con, "INSERT INTO memos (kind, title, text_, source_id, code_id, start, end, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                   params = list(kind, .or(r$title, ""), r$text_, s, c, r$start, r$end,
                                 .or(r$created_at, .now()), r$updated_at))
    keys <- c(keys, k); count("memos", added = 1L)
  }

  # --- summary grid ----------------------------------------------------------------------
  for (i in seq_len(nrow(O$summaries))) {
    r <- O$summaries[i, ]
    s <- smap[[as.character(r$source_id)]]; c <- cmap[[as.character(r$code_id)]]
    if (is.na(s) || is.na(c) || !nzchar(.or(r$text_, ""))) next
    cur <- DBI::dbGetQuery(con, "SELECT id, text_ FROM summaries WHERE code_id = ? AND source_id = ?", params = list(c, s))
    if (nrow(cur) && nzchar(cur$text_)) {
      if (identical(.utf8(cur$text_), r$text_)) count("summaries", already = 1L) else count("summaries", conflicts = 1L)
      next
    }
    DBI::dbExecute(con, "INSERT INTO summaries (code_id, source_id, text_, updated_at) VALUES (?, ?, ?, ?)
                         ON CONFLICT(code_id, source_id) DO UPDATE SET text_ = excluded.text_, updated_at = excluded.updated_at",
                   params = list(c, s, r$text_, .now()))
    count("summaries", added = 1L)
  }

  # --- cases -----------------------------------------------------------------------------
  for (i in seq_len(nrow(O$cases))) {
    r <- O$cases[i, ]
    cur <- DBI::dbGetQuery(con, "SELECT id, meta_json FROM cases WHERE name = ?", params = list(r$name))
    if (nrow(cur)) {
      id <- cur$id; count("cases", already = 1L)
      fv <- .merge_fill_vars(cur$meta_json, .merge_vars(r$meta_json))
      if (fv$added > 0) DBI::dbExecute(con, "UPDATE cases SET meta_json = ? WHERE id = ?", params = list(fv$json, id))
      count("variables", added = fv$added, conflicts = fv$conflicts)
    } else {
      DBI::dbExecute(con, "INSERT INTO cases (name, description, meta_json) VALUES (?, ?, ?)",
                     params = list(r$name, .or(r$description, ""), .or(r$meta_json, "{}")))
      id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
      count("cases", added = 1L)
    }
    hv <- DBI::dbGetQuery(con, "SELECT source_id, start, end FROM case_members WHERE case_id = ?", params = list(id))
    hk <- paste(hv$source_id, hv$start, hv$end)
    om <- O$members[O$members$case_id == r$id, , drop = FALSE]
    for (j in seq_len(nrow(om))) {
      s <- smap[[as.character(om$source_id[j])]]
      if (is.na(s)) next
      k <- paste(s, om$start[j], om$end[j])
      if (k %in% hk) next
      DBI::dbExecute(con, "INSERT INTO case_members (case_id, source_id, start, end) VALUES (?, ?, ?, ?)",
                     params = list(id, s, om$start[j], om$end[j]))
      hk <- c(hk, k)
    }
  }

  kinds <- c("documents", "codes", "codings", "memos", "variables", "summaries", "cases")
  out <- tibble::tibble(what = kinds,
                        added = vapply(kinds, function(k) (n[[k]] %||% c(0L, 0L, 0L))[1], numeric(1), USE.NAMES = FALSE),
                        already = vapply(kinds, function(k) (n[[k]] %||% c(0L, 0L, 0L))[2], numeric(1), USE.NAMES = FALSE),
                        conflicts = vapply(kinds, function(k) (n[[k]] %||% c(0L, 0L, 0L))[3], numeric(1), USE.NAMES = FALSE))
  out$added <- as.integer(out$added); out$already <- as.integer(out$already); out$conflicts <- as.integer(out$conflicts)
  attr(out, "file") <- basename(other); attr(out, "dry_run") <- isTRUE(dry_run)
  attr(out, "skipped_documents") <- as.integer(skipped_docs)
  if (isTRUE(dry_run)) {
    DBI::dbRollback(con)
  } else {
    DBI::dbCommit(con)
    log_event("merge", list(file = basename(other), added = as.list(stats::setNames(out$added, out$what)),
                            conflicts = sum(out$conflicts)),
              desc = sprintf(.t("Projekt zusammengef\u00fchrt: %s (%d Codings, %d Memos neu)"), basename(other),
                             out$added[out$what == "codings"], out$added[out$what == "memos"]))
  }
  ok <- TRUE
  out
}
