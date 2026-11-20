# Memos ----------------------------------------------------------------------

#' Add a free memo to the project
#'
#' @param text_ Memo text.
#' @return Invisibly, a one-row tibble with the new memo.
#' @export
qda_memo_add <- function(text_) {
  con <- qda_con()
  DBI::dbExecute(con, "INSERT INTO memos (text_, created_at) VALUES (?, ?)",
                 params = list(as.character(text_), .now()))
  id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
  log_event("memo_add", list(memo_id = id, text = as.character(text_)))
  invisible(tibble::tibble(id = id, text_ = as.character(text_), created_at = .now()))
}

#' List all memos
#'
#' @return A tibble: `id`, `text_`, `created_at`.
#' @export
qda_memos <- function() {
  con <- qda_con()
  df <- DBI::dbGetQuery(con, "SELECT id, text_, created_at FROM memos ORDER BY id")
  tibble::tibble(id = df$id, text_ = df$text_, created_at = df$created_at)
}

#' Delete a memo
#'
#' @param memo Memo id.
#' @return Invisibly `NULL`.
#' @export
qda_memo_delete <- function(memo) {
  con <- qda_con()
  id <- as.integer(memo)
  row <- DBI::dbGetQuery(con, "SELECT id FROM memos WHERE id = ?", params = list(id))
  if (nrow(row) == 0) stop(sprintf("No memo found with id '%s'.", memo), call. = FALSE)
  DBI::dbExecute(con, "DELETE FROM memos WHERE id = ?", params = list(id))
  log_event("memo_delete", list(memo_id = id))
  invisible(NULL)
}

#' Edit (overwrite) the text of an existing memo
#'
#' @param memo Memo id.
#' @param text_ New memo text.
#' @return Invisibly, a one-row tibble with the updated memo.
#' @export
qda_memo_update <- function(memo, text_) {
  con <- qda_con()
  id <- as.integer(memo)
  row <- DBI::dbGetQuery(con, "SELECT id FROM memos WHERE id = ?", params = list(id))
  if (nrow(row) == 0) stop(sprintf("No memo found with id '%s'.", memo), call. = FALSE)
  DBI::dbExecute(con, "UPDATE memos SET text_ = ? WHERE id = ?",
                 params = list(as.character(text_), id))
  log_event("memo_update", list(memo_id = id, text = as.character(text_)))
  invisible(tibble::tibble(id = id, text_ = as.character(text_)))
}
