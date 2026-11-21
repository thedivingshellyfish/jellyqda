# jellyqda :: undo.R -- qda_undo(): revert the last action. Uses the
# snapshot-based history from history.R; events from older versions are
# reverted by .legacy_undo(). Redo: qda_redo() in history.R.

# Undo -----------------------------------------------------------------------
# The undo/redo stacks are computed from the audit trail in history.R
# (.history_state). New events carry a before/after snapshot and are reverted
# generically (.apply_changes). Events from older jellyqda versions have no
# snapshot; they are reverted by .legacy_undo() below (the original logic).

#' Undo the last action
#'
#' Reverts the most recent action. Every content change can be undone:
#' codings (add, delete, memo), memos, codes (add, rename, move and
#' **delete** -- including all sub-codes, codings and summaries that were
#' removed with it), document variables, summaries and segment changes.
#' System actions (`import`, `export`, `backup`, `auto_snapshot`, project
#' open/close) are not undoable. Repeated calls walk backwards through the
#' history; [qda_redo()] re-applies undone actions. In the app: button
#' "Rueckgaengig" or Strg+Z, redo with Strg+Y.
#'
#' Actions recorded by older jellyqda versions (without snapshot) are
#' reverted with the previous per-action logic where possible.
#'
#' @return Invisibly, a one-row tibble: `undone` (action that was reverted) and
#'   `detail` (human-readable description).
#' @seealso [qda_redo()], [qda_history()]
#' @export
#' @examples
#' \dontrun{
#' qda_code_add("Theme A")
#' qda_code("interview_01.txt", "Theme A", segment = 1)
#' qda_undo()  # removes the coding again
#' qda_undo()  # removes the code again
#' qda_redo()  # the code is back
#' }
qda_undo <- function() {
  st <- .history_state()
  if (nrow(st$undo) == 0) {
    return(invisible(tibble::tibble(undone = "nothing", detail = "no undoable action")))
  }
  ev <- st$undo[nrow(st$undo), , drop = FALSE]
  action <- ev$action
  if (grepl("\"changes\"", ev$details, fixed = TRUE)) {
    .apply_changes(.changes_from_json(ev$details), "before")
    out <- .describe_event(action, ev$details)
  } else {
    out <- .legacy_undo(action, ev$details)
  }
  log_event("undo", list(undid_event_id = ev$id, action = action, detail = out))
  invisible(tibble::tibble(undone = action, detail = out))
}

#' Original per-action undo for events without snapshot (older versions).
#' @noRd
.legacy_undo <- function(action, details_json) {
  con <- qda_con()
  d <- jsonlite::fromJSON(details_json, simplifyVector = FALSE)
  out <- switch(action,
    coding_add = {
      DBI::dbExecute(con, "DELETE FROM codings WHERE id = ?", params = list(d$coding_id))
      sprintf("coding #%s deleted", d$coding_id)
    },
    coding_delete = {
      DBI::dbExecute(con, "
        INSERT INTO codings (id, source_id, code_id, start, end, memo)
        VALUES (?, ?, ?, ?, ?, ?)",
        params = list(d$coding_id, d$source_id, d$code_id, d$start, d$end,
                      if (is.null(d$memo)) "" else d$memo))
      sprintf("coding #%s restored", d$coding_id)
    },
    coding_memo = {
      DBI::dbExecute(con, "UPDATE codings SET memo = ? WHERE id = ?",
                     params = list(if (is.null(d$old_memo)) "" else d$old_memo, d$coding_id))
      sprintf("memo of coding #%s reverted", d$coding_id)
    },
    memo_add = {
      DBI::dbExecute(con, "DELETE FROM memos WHERE id = ?", params = list(d$memo_id))
      sprintf("memo #%s deleted", d$memo_id)
    },
    memo_delete = {
      DBI::dbExecute(con, "INSERT INTO memos (id, text_, created_at) VALUES (?, ?, ?)",
                     params = list(d$memo_id, d$text, d$created_at))
      sprintf("memo #%s restored", d$memo_id)
    },
    memo_update = {
      DBI::dbExecute(con, "UPDATE memos SET text_ = ? WHERE id = ?",
                     params = list(if (is.null(d$old_text)) "" else d$old_text, d$memo_id))
      sprintf("memo #%s text reverted", d$memo_id)
    },
    code_add = {
      n_child <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM codes WHERE parent_id = ?",
                                 params = list(d$code_id))$n
      n_cod <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM codings WHERE code_id = ?",
                               params = list(d$code_id))$n
      if (n_child > 0 || n_cod > 0) {
        stop("Cannot undo code_add: the code now has sub-codes or codings. Delete those first.",
             call. = FALSE)
      }
      DBI::dbExecute(con, "DELETE FROM codes WHERE id = ?", params = list(d$code_id))
      sprintf("code '%s' (#%s) deleted", d$label, d$code_id)
    },
    code_rename = {
      DBI::dbExecute(con, "UPDATE codes SET label = ? WHERE id = ?",
                     params = list(d$old_label, d$code_id))
      sprintf("code #%s renamed back to '%s'", d$code_id, d$old_label)
    },
    code_move = {
      DBI::dbExecute(con, "UPDATE codes SET parent_id = ? WHERE id = ?",
                     params = list(if (is.null(d$old_parent_id)) NA_integer_ else d$old_parent_id,
                                   d$code_id))
      sprintf("code #%s moved back", d$code_id)
    },
    {
      stop(sprintf("Action '%s' is not undoable.", action), call. = FALSE)
    }
  )
  out
}
