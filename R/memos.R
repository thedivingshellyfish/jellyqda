# jellyqda :: memos.R -- memos of four kinds
#
#   kind        reference               typical content
#   ----------  ----------------------  ------------------------------------
#   "passage"   source + start/end      idea about exactly this text passage
#   "document"  source                  postscript, context, case summary
#   "code"      code                    definition, anchor example, rule
#   "project"   --                      research diary, theoretical notes
#
# In addition every coding can carry a short comment (codings.memo, see
# coding.R); the app lists those as "Kommentare zu Codings".
#
# Older jellyqda versions stored passage memos as codings with a reserved
# code "Memo". .migrate_memo_codings() converts them once, when a project is
# opened (see open.R), and removes the reserved code.

.MEMO_KINDS <- c(passage = "Textstelle", document = "Dokument", code = "Code",
                 project = "Projekt")

# Create ------------------------------------------------------------------------

#' Add a memo
#'
#' Creates a memo of one of four kinds. The kind follows from the arguments
#' unless given explicitly: `start`/`end` (with `source`) -> passage memo,
#' only `source` -> document memo, `code` -> code memo, nothing -> project
#' memo (as in earlier versions: `qda_memo_add("text")`).
#'
#' @param text_ Memo text.
#' @param source Source id or name (passage and document memos).
#' @param start,end 1-based character offsets of the passage (passage memos).
#' @param code Code id or label (code memos).
#' @param title Optional short title.
#' @param kind Optional, one of `"passage"`, `"document"`, `"code"`,
#'   `"project"`.
#' @return Invisibly, a one-row tibble with the new memo.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_memo_add("Sharpen question 3 of the guide")                  # project
#' qda_memo_add("Calm atmosphere, interviewee nervous", source = 1)  # document
#' qda_memo_add("Only code explicit statements", code = "SME",
#'              title = "Coding rule")                                # code
#' qda_memo_add("Turning point?", source = 1, start = 120, end = 200)  # passage
#' qda_memos()
#' qda_close()
qda_memo_add <- function(text_, source = NULL, start = NULL, end = NULL, code = NULL,
                         title = "", kind = NULL) {
  con <- qda_con()
  if (is.null(kind)) {
    kind <- if (!is.null(start) || !is.null(end)) "passage"
            else if (!is.null(source)) "document"
            else if (!is.null(code)) "code"
            else "project"
  }
  kind <- match.arg(kind, names(.MEMO_KINDS))
  src_id <- NA_integer_; code_id <- NA_integer_; s <- NA_integer_; e <- NA_integer_
  ref <- ""
  if (kind %in% c("passage", "document")) {
    if (is.null(source)) stop(sprintf("A %s memo needs `source`.", kind), call. = FALSE)
    src <- .resolve_source(source); src_id <- src$id; ref <- src$name
  }
  if (kind == "passage") {
    s <- as.integer(start); e <- as.integer(end)
    n <- nchar(src$frozen_text, type = "chars")
    if (length(s) != 1 || length(e) != 1 || is.na(s) || is.na(e) || s < 1L || e > n || s > e) {
      stop(sprintf("Invalid offsets start=%s, end=%s for source '%s' (%d chars).",
                   format(start), format(end), src$name, n), call. = FALSE)
    }
    ref <- sprintf("%s, Zeichen %d-%d", src$name, s, e)
  }
  if (kind == "code") {
    if (is.null(code)) stop("A code memo needs `code`.", call. = FALSE)
    cod <- .resolve_code(code); code_id <- cod$id; ref <- cod$label
  }
  now <- .now()
  DBI::dbExecute(con, "
    INSERT INTO memos (kind, title, text_, source_id, code_id, start, end, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(kind, as.character(title), as.character(text_), src_id, code_id, s, e, now, now))
  id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
  log_event("memo_add", list(memo_id = id, kind = kind, text = as.character(text_)),
            changes = list(.chg("memos", .snap("memos", integer()), .snap("memos", id))),
            desc = sprintf(.t("%s-Memo angelegt%s"), .t(.MEMO_KINDS[[kind]]), if (nzchar(ref)) paste0(" (", ref, ")") else ""))
  invisible(qda_memos()[qda_memos()$id == id, , drop = FALSE])
}

# Read --------------------------------------------------------------------------

#' List memos
#'
#' @param kind Optional filter: one or more of `"passage"`, `"document"`,
#'   `"code"`, `"project"`.
#' @param source Optional source id/name: only memos referring to it
#'   (passage and document memos).
#' @param code Optional code id/label: only memos of this code.
#' @return A tibble: `id`, `kind`, `title`, `text_`, `source_id`, `source`,
#'   `code_id`, `code`, `start`, `end`, `passage` (the memo'd text for
#'   passage memos), `created_at`, `updated_at`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_memo_add("Research diary entry")
#' qda_memo_add("Definition of SME", code = "SME")
#' qda_memos()
#' qda_memos(kind = "code")
#' qda_close()
qda_memos <- function(kind = NULL, source = NULL, code = NULL) {
  con <- qda_con()
  df <- DBI::dbGetQuery(con, "
    SELECT m.id, m.kind, m.title, m.text_, m.source_id, s.name AS source,
           m.code_id, k.label AS code, m.start, m.end, s.frozen_text,
           m.created_at, IFNULL(m.updated_at, m.created_at) AS updated_at
    FROM memos m
    LEFT JOIN sources s ON s.id = m.source_id
    LEFT JOIN codes k ON k.id = m.code_id
    ORDER BY m.id")
  df$frozen_text <- .utf8(df$frozen_text)
  if (!is.null(kind)) df <- df[df$kind %in% kind, , drop = FALSE]
  if (!is.null(source)) df <- df[!is.na(df$source_id) & df$source_id == .resolve_source(source)$id, , drop = FALSE]
  if (!is.null(code)) df <- df[!is.na(df$code_id) & df$code_id == .resolve_code(code)$id, , drop = FALSE]
  passage <- ifelse(df$kind == "passage" & !is.na(df$start),
                    substring(df$frozen_text, df$start, df$end), NA_character_)
  tibble::tibble(
    id = df$id, kind = df$kind, title = df$title, text_ = df$text_,
    source_id = df$source_id, source = df$source, code_id = df$code_id, code = df$code,
    start = df$start, end = df$end, passage = passage,
    created_at = df$created_at, updated_at = df$updated_at
  )
}

# Update / delete -------------------------------------------------------------------

#' Delete a memo
#'
#' @param memo Memo id.
#' @return Invisibly `NULL`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' m <- qda_memo_add("A thought")
#' qda_memo_delete(m$id)
#' nrow(qda_memos())
#' qda_close()
qda_memo_delete <- function(memo) {
  con <- qda_con()
  id <- as.integer(memo)
  row <- DBI::dbGetQuery(con, "SELECT id, kind, text_, created_at FROM memos WHERE id = ?",
                         params = list(id))
  if (nrow(row) == 0) stop(sprintf("No memo found with id '%s'.", memo), call. = FALSE)
  before <- .snap("memos", id)
  DBI::dbExecute(con, "DELETE FROM memos WHERE id = ?", params = list(id))
  log_event("memo_delete", list(memo_id = id, text = row$text_[1], created_at = row$created_at[1]),
            changes = list(.chg("memos", before, .snap("memos", integer()))),
            desc = sprintf(.t("%s-Memo #%d geloescht"), .t(.MEMO_KINDS[[row$kind[1]]]), id))
  invisible(NULL)
}

#' Edit an existing memo
#'
#' @param memo Memo id.
#' @param text_ New memo text (`NULL` = keep).
#' @param title New title (`NULL` = keep).
#' @return Invisibly, a one-row tibble with the updated memo.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' m <- qda_memo_add("A first thought")
#' qda_memo_update(m$id, text_ = "A better thought", title = "Idea")
#' qda_memos()[, c("title", "text_")]
#' qda_close()
qda_memo_update <- function(memo, text_ = NULL, title = NULL) {
  con <- qda_con()
  id <- as.integer(memo)
  row <- DBI::dbGetQuery(con, "SELECT id, kind, title, text_ FROM memos WHERE id = ?",
                         params = list(id))
  if (nrow(row) == 0) stop(sprintf("No memo found with id '%s'.", memo), call. = FALSE)
  before <- .snap("memos", id)
  DBI::dbExecute(con, "UPDATE memos SET text_ = ?, title = ?, updated_at = ? WHERE id = ?",
                 params = list(as.character(text_ %||% row$text_), as.character(title %||% row$title),
                               .now(), id))
  log_event("memo_update", list(memo_id = id, text = as.character(text_ %||% row$text_),
                                old_text = row$text_[1]),
            changes = list(.chg("memos", before, .snap("memos", id))),
            desc = sprintf(.t("%s-Memo #%d geaendert"), .t(.MEMO_KINDS[[row$kind[1]]]), id))
  invisible(qda_memos()[qda_memos()$id == id, , drop = FALSE])
}

# Migration from older versions ----------------------------------------------------------

#' Older versions stored passage memos as codings with the reserved code
#' "Memo" (top level). Convert each of them into a passage memo (same
#' passage, memo text, creation time from the audit trail if available) and
#' remove the reserved code if nothing else uses it. Runs once per project;
#' logged as "memo_migrate" (a barrier for undo, see history.R).
#' @noRd
.migrate_memo_codings <- function() {
  con <- qda_con()
  # same rule as the old app (memo_code_id): a top-level code named "Memo"
  mc <- DBI::dbGetQuery(con, "SELECT id FROM codes WHERE label = 'Memo' AND IFNULL(parent_id, 0) = 0")
  if (nrow(mc) == 0) return(invisible(0L))
  mid <- mc$id[1]
  rows <- DBI::dbGetQuery(con, "SELECT id, source_id, start, end, memo FROM codings WHERE code_id = ?",
                          params = list(mid))
  n_child <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM codes WHERE parent_id = ?",
                             params = list(mid))$n
  # a "Memo" code with sub-codes was clearly built by hand -> leave it alone
  if (n_child > 0) return(invisible(0L))
  created <- function(cid) {
    ev <- DBI::dbGetQuery(con, "SELECT created_at FROM events WHERE action = 'coding_add'
                                AND details LIKE ? ORDER BY id LIMIT 1",
                          params = list(sprintf('%%"coding_id":%d,%%', cid)))
    if (nrow(ev) == 0) .now() else ev$created_at[1]
  }
  DBI::dbWithTransaction(con, {
    for (i in seq_len(nrow(rows))) {
      t <- created(rows$id[i])
      DBI::dbExecute(con, "
        INSERT INTO memos (kind, title, text_, source_id, start, end, created_at, updated_at)
        VALUES ('passage', '', ?, ?, ?, ?, ?, ?)",
        params = list(rows$memo[i], rows$source_id[i], rows$start[i], rows$end[i], t, t))
    }
    DBI::dbExecute(con, "DELETE FROM codings WHERE code_id = ?", params = list(mid))
    DBI::dbExecute(con, "DELETE FROM summaries WHERE code_id = ?", params = list(mid))
    DBI::dbExecute(con, "DELETE FROM codes WHERE id = ?", params = list(mid))
  })
  log_event("memo_migrate", list(converted = nrow(rows), removed_code_id = mid),
            desc = sprintf(.t("%d Memo-Markierungen in Textstellen-Memos umgewandelt"), nrow(rows)))
  invisible(nrow(rows))
}
