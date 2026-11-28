# jellyqda :: history.R -- snapshot-based undo / redo
#
# Idea: every undoable action stores, in its audit-trail event
# (events.details), a snapshot of the affected database rows BEFORE and AFTER
# the action:
#
#   details$changes = list(
#     list(table = "codings", before = <rows>, after = <rows>),
#     list(table = "codes",   before = <rows>, after = <rows>), ...)
#
# Undo  = restore the "before" rows of the last action.
# Redo  = restore the "after"  rows of the last undone action.
#
# This works the same way for every action (codings, codes incl. cascading
# deletes, memos, variables, summaries, segments ...) -- no per-action undo
# code needed. Events written by older jellyqda versions have no snapshot;
# for those the old per-action logic in undo.R (.legacy_undo) is used.
#
# The undo/redo stacks are not stored separately; they are recomputed from
# the events table (.history_state), so the history survives restarts and is
# part of the audit trail.

# Snapshots ------------------------------------------------------------------

# Columns stored in snapshots. sources: only meta_json (variables), never the
# (possibly huge and anyway immutable) frozen text.
.SNAP_COLS <- list(
  sources   = c("id", "meta_json"),
  codes     = c("id", "label", "parent_id", "color", "description", "anchor", "coding_rule"),
  codings   = c("id", "source_id", "code_id", "start", "end", "memo", "paraphrase", "generalization"),
  memos     = c("id", "kind", "title", "text_", "source_id", "code_id", "start", "end",
                "created_at", "updated_at"),
  summaries = c("id", "code_id", "source_id", "text_", "updated_at"),
  segments  = c("id", "source_id", "start", "end"),
  cases     = c("id", "name", "description", "meta_json"),
  case_members = c("id", "case_id", "source_id", "start", "end")
)

# Order in which tables are written when restoring (parents before children)
# and deleted (children before parents).
.SNAP_ORDER <- c("sources", "codes", "codings", "memos", "summaries", "segments",
                 "cases", "case_members")

#' Read the current rows `ids` of `table` (only the snapshot columns).
#' @noRd
.snap <- function(table, ids) {
  cols <- .SNAP_COLS[[table]]
  ids <- unique(as.integer(ids[!is.na(ids)]))
  if (length(ids) == 0) {
    return(DBI::dbGetQuery(qda_con(), sprintf(
      "SELECT %s FROM %s WHERE 0", paste0("\"", cols, "\"", collapse = ", "), table)))
  }
  DBI::dbGetQuery(qda_con(), sprintf(
    "SELECT %s FROM %s WHERE id IN (%s) ORDER BY id",
    paste0("\"", cols, "\"", collapse = ", "), table, paste(ids, collapse = ",")))
}

#' One change record for log_event(changes = ...).
#' @noRd
.chg <- function(table, before, after) {
  list(table = table, before = before, after = after)
}

#' Run `expr` (which modifies rows `ids` of the given tables) and return the
#' value of `expr` with the before/after snapshot attached as attribute
#' "changes". `ids_after` may be a function evaluated after `expr` (for rows
#' that only exist afterwards, e.g. a new coding id).
#' @noRd
.with_changes <- function(tables_ids, expr, ids_after = NULL) {
  before <- lapply(names(tables_ids), function(t) .snap(t, tables_ids[[t]]))
  names(before) <- names(tables_ids)
  value <- force(expr)
  extra <- if (is.function(ids_after)) ids_after() else list()
  changes <- lapply(names(tables_ids), function(t) {
    ids <- c(tables_ids[[t]], extra[[t]])
    .chg(t, before[[t]], .snap(t, ids))
  })
  attr(value, "changes") <- changes
  value
}

# Restore ----------------------------------------------------------------------

#' Rows of a snapshot as data.frame (handles the JSON round trip: an empty
#' snapshot comes back as list(), missing values as missing fields).
#' @noRd
.rows <- function(x, table) {
  cols <- .SNAP_COLS[[table]]
  if (is.null(x) || length(x) == 0) {
    df <- as.data.frame(stats::setNames(replicate(length(cols), logical(), simplify = FALSE), cols))
    return(df)
  }
  df <- as.data.frame(x, stringsAsFactors = FALSE)
  for (c in setdiff(cols, names(df))) df[[c]] <- NA
  df[, cols, drop = FALSE]
}

#' Bring the given tables into state `which` ("before" or "after") of a
#' change list. Rows present in the other state but not in the target state
#' are deleted; all target rows are inserted or updated (upsert, so existing
#' rows are never deleted+reinserted, which would trigger ON DELETE CASCADE).
#' @noRd
.apply_changes <- function(changes, which = c("before", "after")) {
  which <- match.arg(which)
  other <- if (which == "before") "after" else "before"
  con <- qda_con()
  tabs <- vapply(changes, function(ch) ch$table, character(1))
  ord_up <- order(match(tabs, .SNAP_ORDER))
  ord_del <- rev(ord_up)
  DBI::dbWithTransaction(con, {
    # foreign keys are checked at COMMIT, so e.g. a code and its sub-codes
    # can be restored in any order
    DBI::dbExecute(con, "PRAGMA defer_foreign_keys = ON")
    for (i in ord_up) {
      ch <- changes[[i]]; t <- ch$table
      target <- .rows(ch[[which]], t)
      if (nrow(target) == 0) next
      cols <- names(target)
      q <- paste0("\"", cols, "\"")
      upd <- setdiff(cols, "id")
      sql <- sprintf(
        "INSERT INTO %s (%s) VALUES (%s) ON CONFLICT(id) DO UPDATE SET %s",
        t, paste(q, collapse = ", "), paste(rep("?", length(cols)), collapse = ", "),
        paste(sprintf("\"%s\" = excluded.\"%s\"", upd, upd), collapse = ", "))
      if (t == "sources") {
        # sources are never created or deleted by undo; only update variables
        sql <- "UPDATE sources SET meta_json = ? WHERE id = ?"
        for (r in seq_len(nrow(target))) {
          DBI::dbExecute(con, sql, params = list(target$meta_json[r], target$id[r]))
        }
        next
      }
      for (r in seq_len(nrow(target))) {
        DBI::dbExecute(con, sql, params = unname(as.list(target[r, , drop = FALSE])))
      }
    }
    for (i in ord_del) {
      ch <- changes[[i]]; t <- ch$table
      if (t == "sources") next
      gone <- setdiff(.rows(ch[[other]], t)$id, .rows(ch[[which]], t)$id)
      if (length(gone) > 0) {
        DBI::dbExecute(con, sprintf("DELETE FROM %s WHERE id IN (%s)", t,
                                    paste(as.integer(gone), collapse = ",")))
      }
    }
  })
  invisible(NULL)
}

# History state -----------------------------------------------------------------

# Actions that can be undone (if they carry a snapshot or the legacy logic
# in undo.R knows them).
.UNDOABLE <- c("coding_add", "coding_delete", "coding_memo", "coding_update",
               "memo_add", "memo_delete", "memo_update",
               "code_add", "code_rename", "code_delete", "code_move", "code_update", "code_merge",
               "source_var_set", "source_var_del", "summary_set",
               "segments_set", "segment_split", "segment_merge", "segment_adjust",
               "case_add", "case_update", "case_delete", "case_assign", "case_unassign",
               "case_var_set", "case_var_del", "cases_build")

# Legacy events (no snapshot) that the old logic can undo.
.LEGACY_UNDOABLE <- c("coding_add", "coding_delete", "coding_memo", "memo_add",
                      "memo_delete", "memo_update", "code_add", "code_rename", "code_move")

#' Recompute the undo and redo stacks from the audit trail.
#'
#' Walks all events in order: an undoable action is pushed on the undo stack
#' (and clears the redo stack, as in every editor); 'undo' moves the event
#' to the redo stack; 'redo' moves it back.
#' @return list(undo = data.frame, redo = data.frame), each with columns
#'   id, action, details (JSON) -- last element = next to undo / redo; only
#'   the last element carries its details (the others may be NA).
#' @noRd
.history_state <- function() {
  # Incremental: events are only ever appended, so the stacks of the last
  # call are kept (per open project, .jellyqda_env$hist; reset by
  # qda_open/qda_close) and only the new events are walked. In a project with
  # thousands of actions, re-walking everything cost time on every action.
  h <- .jellyqda_env$hist
  if (is.null(h)) h <- list(max_id = 0L, undo = integer(), redo = integer(), action = character())
  # details (with before/after snapshots) can be large: read them only for
  # undo/redo events (to know which event they refer to) and, at the end,
  # for the last entry of each stack; has_snap is computed in SQL
  ev <- DBI::dbGetQuery(qda_con(), sprintf(
    "SELECT id, action,
            CASE WHEN action IN ('undo', 'redo') THEN details ELSE NULL END AS details,
            instr(details, '\"changes\"') > 0 AS has_snap
     FROM events
     WHERE id > %d AND (action IN ('undo', 'redo', 'memo_migrate') OR action IN (%s)) ORDER BY id",
    as.integer(h$max_id), paste0("'", .UNDOABLE, "'", collapse = ",")))
  undo <- h$undo; redo <- h$redo
  for (i in seq_len(nrow(ev))) {
    a <- ev$action[i]
    # the one-time memo migration is a barrier: nothing before it can be
    # undone (old events may reference the removed reserved 'Memo' code)
    if (a == "memo_migrate") { undo <- integer(); redo <- integer(); next }
    if (a == "undo" || a == "redo") {
      d <- jsonlite::fromJSON(ev$details[i])
      id <- if (a == "undo") d$undid_event_id else d$redid_event_id
      if (is.null(id)) next
      if (a == "undo") { undo <- setdiff(undo, id); redo <- c(redo, id) }
      else             { redo <- setdiff(redo, id); undo <- c(undo, id) }
    } else {
      has_snap <- isTRUE(as.logical(ev$has_snap[i]))
      # legacy events without snapshot that the old logic cannot undo are
      # skipped, so they never block the undo stack
      if (has_snap || a %in% .LEGACY_UNDOABLE) {
        undo <- c(undo, ev$id[i]); redo <- integer()
      }
    }
  }
  action <- h$action
  keep <- ev$action != "undo" & ev$action != "redo" & ev$action != "memo_migrate"
  if (any(keep)) action[as.character(ev$id[keep])] <- ev$action[keep]
  .jellyqda_env$hist <- list(max_id = max(c(h$max_id, ev$id)), undo = undo, redo = redo, action = action)
  pick <- function(ids) {
    if (length(ids) == 0) return(data.frame(id = integer(), action = character(), details = character()))
    out <- data.frame(id = as.integer(ids), action = unname(action[as.character(ids)]),
                      details = NA_character_, stringsAsFactors = FALSE)
    # full details only for the last entry (the next one to undo / redo)
    n <- nrow(out)
    out$details[n] <- DBI::dbGetQuery(qda_con(), "SELECT details FROM events WHERE id = ?",
                                      params = list(out$id[n]))$details
    out
  }
  list(undo = pick(undo), redo = pick(redo))
}

# German, human-readable labels for the undo/redo tooltips -----------------------

.ACTION_DE <- c(
  coding_add = "Coding hinzugef\u00fcgt", coding_delete = "Coding gel\u00f6scht",
  coding_memo = "Coding-Memo ge\u00e4ndert", coding_update = "Coding ge\u00e4ndert",
  memo_add = "Memo angelegt", memo_delete = "Memo gel\u00f6scht", memo_update = "Memo ge\u00e4ndert",
  code_add = "Code angelegt", code_rename = "Code umbenannt", code_delete = "Code gel\u00f6scht",
  code_move = "Code verschoben", code_update = "Code ge\u00e4ndert", code_merge = "Codes zusammengef\u00fchrt",
  source_var_set = "Variable gesetzt", source_var_del = "Variable gel\u00f6scht",
  summary_set = "Summary ge\u00e4ndert", segments_set = "Segmente neu eingeteilt",
  segment_split = "Segment geteilt", segment_merge = "Segmente zusammengef\u00fchrt",
  segment_adjust = "Segmentgrenze verschoben")

#' Short description of an event, e.g. "Coding hinzugefuegt: 'Thema A' in
#' interview_01.txt (Zeichen 120-340)". New events carry details$desc.
#' @noRd
.describe_event <- function(action, details_json) {
  d <- tryCatch(jsonlite::fromJSON(details_json), error = function(e) list())
  if (!is.null(d$desc) && nzchar(d$desc)) return(d$desc)
  lbl <- if (is.null(.ACTION_DE[[action]])) action else .t(.ACTION_DE[[action]])
  extra <- d$label %||% d$new_label %||% d$key %||% NULL
  if (!is.null(extra)) paste0(lbl, ": '", extra, "'") else lbl
}

# Public API ---------------------------------------------------------------------

#' What would undo / redo do next?
#'
#' @return A list with `undo` and `redo`: each either `NULL` (nothing to
#'   undo/redo) or a description string such as
#'   `"Coding hinzugefuegt: 'Thema A' in interview_01.txt (Zeichen 120-340)"`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_history()$undo   # what the next qda_undo() would revert
#' qda_close()
qda_history <- function() {
  st <- .history_state()
  desc <- function(df) {
    if (nrow(df) == 0) return(NULL)
    n <- nrow(df)
    .describe_event(df$action[n], df$details[n])
  }
  list(undo = desc(st$undo), redo = desc(st$redo),
       n_undo = nrow(st$undo), n_redo = nrow(st$redo))
}

#' Redo the last undone action
#'
#' Re-applies the action that the last [qda_undo()] reverted. Like in every
#' editor, the redo list is cleared as soon as a new action is done.
#'
#' @return Invisibly, a one-row tibble `redone` (action) and `detail`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_undo()  # oops
#' qda_redo()  # back again
#' qda_close()
qda_redo <- function() {
  st <- .history_state()
  if (nrow(st$redo) == 0) {
    return(invisible(tibble::tibble(redone = "nothing", detail = "nothing to redo")))
  }
  n <- nrow(st$redo)
  ev <- st$redo[n, , drop = FALSE]
  if (!grepl("\"changes\"", ev$details, fixed = TRUE)) {
    stop(.t("Diese Aktion stammt aus einer \u00e4lteren jellyqda-Version und kann nicht wiederholt werden."),
         call. = FALSE)
  }
  .apply_changes(.changes_from_json(ev$details), "after")
  desc <- .describe_event(ev$action, ev$details)
  log_event("redo", list(redid_event_id = ev$id, action = ev$action, detail = desc))
  invisible(tibble::tibble(redone = ev$action, detail = desc))
}

#' Parse details$changes from an event's JSON into a list of change records
#' list(table, before = data.frame, after = data.frame). Parsed without
#' jsonlite's automatic simplification, so the result is always predictable.
#' @noRd
.changes_from_json <- function(json) {
  d <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  to_df <- function(rows, table) {
    if (length(rows) == 0) return(.rows(NULL, table))
    df <- do.call(rbind, lapply(rows, function(r) {
      as.data.frame(lapply(r, function(v) if (is.null(v)) NA else v),
                    stringsAsFactors = FALSE)
    }))
    .rows(df, table)
  }
  lapply(d$changes, function(ch) {
    list(table = ch$table, before = to_df(ch$before, ch$table),
         after = to_df(ch$after, ch$table))
  })
}
