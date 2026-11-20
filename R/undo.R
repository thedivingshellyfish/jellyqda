# Undo -----------------------------------------------------------------------
# Reverts the last undoable action, using the audit trail (events.details).
# Undone events are remembered (in the undo event's details) so repeated
# qda_undo() calls walk backwards through the history, not in circles.

#' Undo the last undoable action
#'
#' Reverts the most recent action that can be reverted exactly:
#' `coding_add` / `coding_delete` / `coding_memo`, `memo_add` / `memo_delete` /
#' `memo_update`, `code_add` (only while the code has no sub-codes/codings) and
#' `code_rename`. System actions (`import`, `export`, `backup`,
#' `auto_snapshot`, project open/close) are not undoable. Repeated calls walk
#' backwards through the history (each reverted event is remembered in the
#' audit trail via `undo` events).
#'
#' @return Invisibly, a one-row tibble: `undone` (action that was reverted) and
#'   `detail` (human-readable description).
#' @export
#' @examples
#' \dontrun{
#' qda_code_add("Theme A")
#' qda_code("interview_01.txt", "Theme A", segment = 1)
#' qda_undo()  # removes the coding again
#' qda_undo()  # removes the code again
#' }
qda_undo <- function() {
  con <- qda_con()
  skip <- c("undo", "auto_snapshot", "backup", "export", "project_create",
            "project_open", "project_close", "import")
  # event ids already reverted by previous undo calls
  undone_ids <- integer()
  und <- DBI::dbGetQuery(con, "SELECT details FROM events WHERE action = 'undo'")
  if (nrow(und) > 0) {
    undone_ids <- unique(unlist(lapply(und$details, function(j) {
      jsonlite::fromJSON(j)$undid_event_id
    })))
  }
  ev <- DBI::dbGetQuery(con, "SELECT id, action, details FROM events ORDER BY id DESC")
  ev <- ev[!ev$action %in% skip & !ev$id %in% undone_ids, , drop = FALSE]
  if (nrow(ev) > 0) ev <- ev[1, , drop = FALSE]
  if (nrow(ev) == 0) {
    return(invisible(tibble::tibble(undone = "nothing", detail = "no undoable action")))
  }
  d <- jsonlite::fromJSON(ev$details[1], simplifyVector = FALSE)
  action <- ev$action[1]
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
  log_event("undo", list(undid_event_id = ev$id[1], action = action, detail = out))
  invisible(tibble::tibble(undone = action, detail = out))
}
