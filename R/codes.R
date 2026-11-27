# jellyqda :: codes.R -- codebook CRUD: qda_codes(), qda_code_add/rename/delete/move
# Codes are a self-referencing tree (parent_id); paths are 'A / B / C'.
# qda_code_move() has a cycle check. Deleting a code deletes sub-codes+codings.

# Codebook -------------------------------------------------------------------

#' List the codebook
#'
#' @return A tibble with one row per code: `id`, `label`, `parent_id`, `color`,
#'   `description` (definition), `anchor` (anchor examples), `coding_rule`,
#'   `path` (hierarchical `parent / child` label path) and
#'   `n_codings` (how many codings use this code).
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_codes()
#' qda_close()
qda_codes <- function() {
  con <- qda_con()
  df <- DBI::dbGetQuery(con, "SELECT id, label, parent_id, color, description, anchor, coding_rule FROM codes ORDER BY id")
  cnt <- DBI::dbGetQuery(con, "SELECT code_id, COUNT(*) AS n FROM codings GROUP BY code_id")
  n <- cnt$n[match(df$id, cnt$code_id)]
  tibble::tibble(
    id = df$id,
    label = df$label,
    parent_id = df$parent_id,
    color = df$color,
    description = df$description,
    anchor = ifelse(is.na(df$anchor), "", df$anchor),
    coding_rule = ifelse(is.na(df$coding_rule), "", df$coding_rule),
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
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")                    # top level
#' qda_code_add("SME", parent = "Career path")    # subcode (inherits the colour)
#' qda_code_add("Motivation", color = "#56B4E9", description = "Reasons and drives")
#' qda_codes()
#' qda_close()
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
  if (is.null(color) && !is.na(parent_id)) {
    # a subcode takes the colour of its code family (top-level code)
    tr <- .code_tree(DBI::dbGetQuery(con, "SELECT id, label, parent_id, color FROM codes"))
    color <- tr$root_color[tr$id == parent_id][1]
  }
  if (is.null(color)) {
    # next palette colour not yet used by a top-level code
    used <- DBI::dbGetQuery(con, "SELECT color FROM codes WHERE parent_id IS NULL")$color
    free <- setdiff(.PALETTE, used)
    n <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM codes WHERE parent_id IS NULL")$n
    color <- if (length(free)) free[1] else .PALETTE[(n %% length(.PALETTE)) + 1]
  }
  DBI::dbExecute(
    con, "INSERT INTO codes (label, parent_id, color, description) VALUES (?, ?, ?, ?)",
    params = list(label, parent_id, color, as.character(description))
  )
  id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
  log_event("code_add", list(code_id = id, label = label,
                             parent_id = if (is.na(parent_id)) NULL else parent_id),
            changes = list(.chg("codes", .snap("codes", integer()), .snap("codes", id))),
            desc = sprintf(.t("Code angelegt: '%s'"), label))
  invisible(tibble::tibble(id = id, label = label, parent_id = parent_id,
                           color = color, description = as.character(description)))
}

#' Rename a code
#'
#' @param code Code id or unique label.
#' @param new_label New label (must be unique under the same parent).
#' @return Invisibly, a one-row tibble with the updated code.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_code_rename("SME", "Small company")
#' qda_codes()$path
#' qda_close()
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
  before <- .snap("codes", row$id)
  DBI::dbExecute(con, "UPDATE codes SET label = ? WHERE id = ?",
                 params = list(new_label, row$id))
  log_event("code_rename", list(code_id = row$id, old_label = row$label, new_label = new_label),
            changes = list(.chg("codes", before, .snap("codes", row$id))),
            desc = sprintf(.t("Code umbenannt: '%s' -> '%s'"), row$label, new_label))
  invisible(tibble::tibble(id = row$id, label = new_label, parent_id = row$parent_id))
}

#' Delete a code (and its sub-codes and their codings)
#'
#' @param code Code id or unique label.
#' @return Invisibly, a one-row tibble with the number of deleted codes and
#'   codings.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_code(1, "SME", segment = 2)
#' qda_code_delete("Career path")   # with its subcodes and codings
#' nrow(qda_codes())
#' qda_undo()                       # everything is back
#' nrow(qda_codes())
#' qda_close()
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
  # snapshot for undo: the codes, ALL their codings and summaries (summaries
  # are removed by ON DELETE CASCADE) -- so undo restores everything
  in_ids <- paste(ids, collapse = ",")
  cod_ids <- DBI::dbGetQuery(con, sprintf("SELECT id FROM codings WHERE code_id IN (%s)", in_ids))$id
  sum_ids <- DBI::dbGetQuery(con, sprintf("SELECT id FROM summaries WHERE code_id IN (%s)", in_ids))$id
  # code memos are removed by ON DELETE CASCADE as well
  memo_ids <- DBI::dbGetQuery(con, sprintf("SELECT id FROM memos WHERE code_id IN (%s)", in_ids))$id
  before <- list(codes = .snap("codes", ids), codings = .snap("codings", cod_ids),
                 summaries = .snap("summaries", sum_ids), memos = .snap("memos", memo_ids))
  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, sprintf("DELETE FROM codings WHERE code_id IN (%s)",
                                paste(ids, collapse = ",")))
    DBI::dbExecute(con, sprintf("DELETE FROM codes WHERE id IN (%s)",
                                paste(ids, collapse = ",")))
  })
  log_event("code_delete", list(code_id = row$id, label = row$label,
                                deleted_code_ids = ids, deleted_codings = n_cod),
            changes = list(.chg("codes", before$codes, .snap("codes", integer())),
                           .chg("codings", before$codings, .snap("codings", integer())),
                           .chg("summaries", before$summaries, .snap("summaries", integer())),
                           .chg("memos", before$memos, .snap("memos", integer()))),
            desc = sprintf(.t("Code gel\u00f6scht: '%s' (mit %d Unter-Codes und %d Codings)"),
                           row$label, length(ids) - 1L, n_cod))
  invisible(tibble::tibble(codes_deleted = length(ids), codings_deleted = n_cod))
}

#' Move a code to a new parent (re-parent), e.g. after drag & drop in the app
#'
#' @param code Code id or label to move.
#' @param parent New parent code id/label, or `NULL` to move to the top level.
#' @return Invisibly, a one-row tibble with the updated code.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_code_add("Motivation")
#' qda_code_move("SME", parent = "Motivation")
#' qda_code_move("SME", parent = NULL)   # back to the top level
#' qda_codes()$path
#' qda_close()
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
  before <- .snap("codes", row$id)
  DBI::dbExecute(con, "UPDATE codes SET parent_id = ? WHERE id = ?",
                 params = list(if (is.na(parent_id)) NA_integer_ else parent_id, row$id))
  log_event("code_move", list(code_id = row$id,
                              old_parent_id = if (is.na(row$parent_id)) NULL else row$parent_id,
                              new_parent_id = if (is.na(parent_id)) NULL else parent_id),
            changes = list(.chg("codes", before, .snap("codes", row$id))),
            desc = sprintf(.t("Code verschoben: '%s'"), row$label))
  invisible(tibble::tibble(id = row$id, parent_id = parent_id))
}

#' Change the colour of a code
#'
#' In the app, subcodes are always shown in the colour of their top-level
#' code; changing the colour of a top-level code therefore re-colours the
#' whole code family. With `family = TRUE` (default) the stored colour of all
#' subcodes is updated as well, so exports show the same colour.
#'
#' @param code Code id or unique label.
#' @param color New colour as `"#RRGGBB"`.
#' @param family Logical; also set the colour of all subcodes.
#' @return Invisibly, a one-row tibble with the updated code.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_code_set_color("Career path", "#0072B2")   # whole code family
#' qda_codes()$color
#' qda_close()
qda_code_set_color <- function(code, color, family = TRUE) {
  con <- qda_con()
  row <- .resolve_code(code)
  color <- as.character(color)
  if (!grepl("^#[0-9A-Fa-f]{6}$", color)) {
    stop("color must be a hex colour like '#E69F00'.", call. = FALSE)
  }
  ids <- row$id
  if (isTRUE(family)) {
    ids <- .code_descendants(DBI::dbGetQuery(con, "SELECT id, parent_id FROM codes"), row$id)
  }
  before <- .snap("codes", ids)
  DBI::dbExecute(con, sprintf("UPDATE codes SET color = ? WHERE id IN (%s)",
                              paste(ids, collapse = ",")), params = list(color))
  log_event("code_update", list(code_id = row$id, old_color = row$color, new_color = color),
            changes = list(.chg("codes", before, .snap("codes", ids))),
            desc = sprintf(.t("Farbe von Code '%s' ge\u00e4ndert"), row$label))
  invisible(tibble::tibble(id = row$id, label = row$label, color = color))
}
