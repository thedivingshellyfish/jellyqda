# Codebook -------------------------------------------------------------------

#' List the codebook
#'
#' @return A tibble with one row per code: `id`, `label`, `parent_id`, `color`,
#'   `description`, `path` (hierarchical `parent / child` label path) and
#'   `n_codings` (how many codings use this code).
#' @export
#' @examples
#' \dontrun{
#' qda_codes()
#' }
qda_codes <- function() {
  con <- qda_con()
  df <- DBI::dbGetQuery(con, "SELECT id, label, parent_id, color, description FROM codes ORDER BY id")
  cnt <- DBI::dbGetQuery(con, "SELECT code_id, COUNT(*) AS n FROM codings GROUP BY code_id")
  n <- cnt$n[match(df$id, cnt$code_id)]
  tibble::tibble(
    id = df$id,
    label = df$label,
    parent_id = df$parent_id,
    color = df$color,
    description = df$description,
    path = .code_paths(df),
    n_codings = ifelse(is.na(n), 0L, as.integer(n))
  )
}

#' Add a code to the codebook
#'
#' Codes form a tree: pass `parent` (id or label) to create a sub-code.
#' Inductive codes can simply be added without a parent while coding.
#'
#' @param label Code label. Unique per parent.
#' @param parent Optional parent code (id or unique label).
#' @param color Highlight color; a palette color is assigned automatically if
#'   omitted.
#' @param description Optional description of the code.
#' @return Invisibly, a one-row tibble describing the new code.
#' @export
#' @examples
#' \dontrun{
#' qda_code_add("Beruflicher Werdegang")                    # top-level
#' qda_code_add("KMU", parent = "Beruflicher Werdegang")    # sub-code
#' }
qda_code_add <- function(label, parent = NULL, color = NULL, description = "") {
  con <- qda_con()
  label <- as.character(label)
  parent_id <- if (is.null(parent)) NA_integer_ else .resolve_code(parent)$id
  dup <- DBI::dbGetQuery(
    con, "SELECT id FROM codes WHERE label = ? AND IFNULL(parent_id, 0) = ?",
    params = list(label, parent_id)
  )
  if (nrow(dup) > 0) {
    stop(sprintf("A code '%s' already exists under this parent.", label), call. = FALSE)
  }
  if (is.null(color)) {
    n <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM codes")$n
    color <- .PALETTE[(n %% length(.PALETTE)) + 1]
  }
  DBI::dbExecute(
    con, "INSERT INTO codes (label, parent_id, color, description) VALUES (?, ?, ?, ?)",
    params = list(label, parent_id, color, as.character(description))
  )
  id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
  log_event("code_add", list(code_id = id, label = label,
                             parent_id = if (is.na(parent_id)) NULL else parent_id))
  invisible(tibble::tibble(id = id, label = label, parent_id = parent_id,
                           color = color, description = as.character(description)))
}

#' Rename a code
#'
#' @param code Code id or unique label.
#' @param new_label New label (must be unique under the same parent).
#' @return Invisibly, a one-row tibble with the updated code.
#' @export
qda_code_rename <- function(code, new_label) {
  con <- qda_con()
  row <- .resolve_code(code)
  new_label <- as.character(new_label)
  dup <- DBI::dbGetQuery(
    con, "SELECT id FROM codes WHERE label = ? AND IFNULL(parent_id, 0) = IFNULL(?, 0) AND id != ?",
    params = list(new_label, row$parent_id, row$id)
  )
  if (nrow(dup) > 0) {
    stop(sprintf("A code '%s' already exists under this parent.", new_label), call. = FALSE)
  }
  DBI::dbExecute(con, "UPDATE codes SET label = ? WHERE id = ?",
                 params = list(new_label, row$id))
  log_event("code_rename", list(code_id = row$id, old_label = row$label, new_label = new_label))
  invisible(tibble::tibble(id = row$id, label = new_label, parent_id = row$parent_id))
}

#' Delete a code (and its sub-codes and their codings)
#'
#' @param code Code id or unique label.
#' @return Invisibly, a one-row tibble with the number of deleted codes and
#'   codings.
#' @export
qda_code_delete <- function(code) {
  con <- qda_con()
  row <- .resolve_code(code)
  ids <- DBI::dbGetQuery(con, "
    WITH RECURSIVE sub(id) AS (
      SELECT ? UNION SELECT c.id FROM codes c JOIN sub ON c.parent_id = sub.id
    ) SELECT id FROM sub", params = list(row$id))$id
  n_cod <- DBI::dbGetQuery(
    con, sprintf("SELECT COUNT(*) AS n FROM codings WHERE code_id IN (%s)",
                 paste(ids, collapse = ",")))$n
  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, sprintf("DELETE FROM codings WHERE code_id IN (%s)",
                                paste(ids, collapse = ",")))
    DBI::dbExecute(con, sprintf("DELETE FROM codes WHERE id IN (%s)",
                                paste(ids, collapse = ",")))
  })
  log_event("code_delete", list(code_id = row$id, label = row$label,
                                deleted_code_ids = ids, deleted_codings = n_cod))
  invisible(tibble::tibble(codes_deleted = length(ids), codings_deleted = n_cod))
}

#' Move a code to a new parent (re-parent), e.g. after drag & drop in the app
#'
#' @param code Code id or label to move.
#' @param parent New parent code id/label, or `NULL` to move to the top level.
#' @return Invisibly, a one-row tibble with the updated code.
#' @export
qda_code_move <- function(code, parent = NULL) {
  con <- qda_con()
  row <- .resolve_code(code)
  parent_id <- if (is.null(parent) || parent == "") NA_integer_ else .resolve_code(parent)$id
  if (!is.na(parent_id) && parent_id == row$id) {
    stop("A code cannot be its own parent.", call. = FALSE)
  }
  if (!is.na(parent_id)) {
    # cycle check: walk up from the new parent; must never reach the moved code
    cur <- parent_id
    while (!is.na(cur) && cur != 0) {
      if (cur == row$id) stop("Cannot move a code under one of its own sub-codes.", call. = FALSE)
      cur <- DBI::dbGetQuery(con, "SELECT IFNULL(parent_id, 0) AS p FROM codes WHERE id = ?",
                            params = list(cur))$p[1]
    }
  }
  DBI::dbExecute(con, "UPDATE codes SET parent_id = ? WHERE id = ?",
                 params = list(if (is.na(parent_id)) NA_integer_ else parent_id, row$id))
  log_event("code_move", list(code_id = row$id,
                              old_parent_id = if (is.na(row$parent_id)) NULL else row$parent_id,
                              new_parent_id = if (is.na(parent_id)) NULL else parent_id))
  invisible(tibble::tibble(id = row$id, parent_id = parent_id))
}
