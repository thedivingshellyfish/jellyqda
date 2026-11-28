# jellyqda :: cases_vars.R -- variables of cases
#
#   qda_case_vars()     the variables of one case
#   qda_case_set_var()  set a variable (e.g. age = 34)
#   qda_case_del_var()  delete a variable
#
# Same idea as document variables (sources.R), but for cases: they are kept
# in cases.meta_json as {"variables": {...}}. Every change is one undo step.
# qda_case_matrix(by = "<variable>", unit = "case") compares groups of cases.

#' Variables of all cases: named list (case id -> named character vector).
#' @noRd
.all_case_vars <- function() {
  m <- DBI::dbGetQuery(qda_con(), "SELECT id, meta_json FROM cases ORDER BY id")
  out <- lapply(m$meta_json, function(j) {
    v <- tryCatch(jsonlite::fromJSON(j %||% "{}")$variables, error = function(e) NULL)
    if (is.null(v)) character() else { v <- unlist(v); stats::setNames(.utf8(as.character(v)), .utf8(names(v))) }
  })
  stats::setNames(out, as.character(m$id))
}

#' Variables of a case
#'
#' @param case Case id or name.
#' @return Named character vector (variable name -> value).
#' @seealso [qda_case_set_var()], [qda_source_vars()] for document variables
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_case_add("Person A")
#' qda_case_set_var("Person A", "age", "34")
#' qda_case_vars("Person A")
#' qda_close()
qda_case_vars <- function(case) {
  .all_case_vars()[[as.character(.resolve_case(case)$id)]] %||% character()
}

#' Set a variable of a case
#'
#' @param case Case id or name.
#' @param key Variable name (e.g. `"age"`).
#' @param value Value (stored as text).
#' @return Invisibly, all variables of the case.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_case_add("Person A")
#' qda_case_set_var("Person A", "role", "nurse")
#' qda_case_set_var("Person A", "age", 34)
#' qda_case_vars("Person A")
#' qda_close()
qda_case_set_var <- function(case, key, value) {
  .case_var_change(case, as.character(key), as.character(value))
}

#' Delete a variable of a case
#'
#' @param case Case id or name.
#' @param key Variable name.
#' @return Invisibly, the remaining variables of the case.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_case_add("Person A")
#' qda_case_set_var("Person A", "age", "34")
#' qda_case_del_var("Person A", "age")
#' qda_case_vars("Person A")
#' qda_close()
qda_case_del_var <- function(case, key) {
  .case_var_change(case, as.character(key), NULL)
}

#' Set (value) or delete (NULL) one case variable, as one undo step.
#' @noRd
.case_var_change <- function(case, key, value) {
  con <- qda_con()
  cs <- .resolve_case(case)
  if (!nzchar(trimws(key))) stop("A variable needs a name.", call. = FALSE)
  m <- tryCatch(jsonlite::fromJSON(cs$meta_json %||% "{}"), error = function(e) list())
  if (is.null(m$variables)) m$variables <- list()
  m$variables[[key]] <- value
  before <- .snap("cases", cs$id)
  DBI::dbExecute(con, "UPDATE cases SET meta_json = ? WHERE id = ?", params = list(.to_json(m), cs$id))
  if (is.null(value)) {
    log_event("case_var_del", list(case_id = cs$id, key = key), changes = list(.chg("cases", before, .snap("cases", cs$id))),
              desc = sprintf(.t("Fallvariable gel\u00f6scht: %s (%s)"), key, cs$name))
  } else {
    log_event("case_var_set", list(case_id = cs$id, key = key, value = value), changes = list(.chg("cases", before, .snap("cases", cs$id))),
              desc = sprintf(.t("Fallvariable gesetzt: %s = '%s' (%s)"), key, value, cs$name))
  }
  invisible(qda_case_vars(cs$id))
}
