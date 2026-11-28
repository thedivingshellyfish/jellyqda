# jellyqda :: cases_build.R -- build many cases at once
#
#   qda_cases_from_speakers()  group interview: one case per speaker, with
#                              all turns of that speaker
#   qda_cases_from_variable()  one case per value of a document variable,
#                              e.g. several interviews of the same person
#
# Both create missing cases, add the members and set a case variable; all of
# it is ONE undo step ("cases_build"). Existing cases with the same name are
# extended, not duplicated. Single cases: cases.R.

#' Speaker label at the start of a segment, or NA ("[00:01:12] B2: ..." -> "B2").
#' @noRd
.speaker_of <- function(txt) {
  m <- regmatches(txt, regexec(paste0("^[ \t\r\n]*(\\[?[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?([.,][0-9]+)?\\]?[ \t]*)?",
                                      "(\\p{L}[\\p{L}\\p{N}_-]{0,24}):([ \t]|$)"), txt, perl = TRUE))
  vapply(m, function(x) if (length(x)) x[5] else NA_character_, character(1))
}

#' Write a set of new members (and missing cases) as one undo step.
#' @param plan data.frame: case (name), source_id, start, end (NA = whole document)
#' @param vars named list: case name -> named character of case variables to set
#' @noRd
.cases_build <- function(plan, vars = list(), desc = "") {
  con <- qda_con()
  if (nrow(plan) == 0) return(invisible(qda_cases()[0, ]))
  names_ <- unique(plan$case)
  old <- DBI::dbGetQuery(con, "SELECT id, name FROM cases")
  old$name <- .utf8(old$name)
  touched_old <- old$id[old$name %in% names_]
  before_cases <- .snap("cases", touched_old)
  before_ids <- DBI::dbGetQuery(con, "SELECT id FROM case_members")$id
  key <- function(a, b) paste(ifelse(is.na(a), "-", a), ifelse(is.na(b), "-", b))
  DBI::dbWithTransaction(con, {
    for (nm in names_) {
      id <- old$id[old$name == nm]
      if (length(id) == 0) {
        DBI::dbExecute(con, "INSERT INTO cases (name, description, meta_json) VALUES (?, '', '{}')", params = list(nm))
        id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
      }
      p <- plan[plan$case == nm, , drop = FALSE]
      have <- DBI::dbGetQuery(con, "SELECT source_id, start, end FROM case_members WHERE case_id = ?", params = list(id))
      p <- p[!paste(p$source_id, key(p$start, p$end)) %in% paste(have$source_id, key(have$start, have$end)), , drop = FALSE]
      for (i in seq_len(nrow(p))) {
        DBI::dbExecute(con, "INSERT INTO case_members (case_id, source_id, start, end) VALUES (?, ?, ?, ?)",
                       params = list(id, p$source_id[i], p$start[i], p$end[i]))
      }
      var <- vars[[nm]]
      if (length(var)) {
        mj <- DBI::dbGetQuery(con, "SELECT meta_json FROM cases WHERE id = ?", params = list(id))$meta_json
        m <- tryCatch(jsonlite::fromJSON(mj %||% "{}"), error = function(e) list())
        if (is.null(m$variables)) m$variables <- list()
        for (k in names(var)) m$variables[[k]] <- unname(var[[k]])
        DBI::dbExecute(con, "UPDATE cases SET meta_json = ? WHERE id = ?", params = list(.to_json(m), id))
      }
    }
  })
  now <- DBI::dbGetQuery(con, "SELECT id, name FROM cases")
  ids <- now$id[.utf8(now$name) %in% names_]
  new_members <- setdiff(DBI::dbGetQuery(con, "SELECT id FROM case_members")$id, before_ids)
  log_event("cases_build", list(cases = length(ids), members = length(new_members)),
            changes = list(.chg("cases", before_cases, .snap("cases", ids)),
                           .chg("case_members", .snap("case_members", integer()), .snap("case_members", new_members))),
            desc = desc)
  out <- qda_cases()
  invisible(out[out$id %in% ids, ])
}

#' One case per speaker of a group interview
#'
#' For group interviews and focus groups: every speaker label found at the
#' start of a segment (`"B1: ..."`, `"[00:03:10] Anna: ..."`) becomes a case
#' that contains all turns of this speaker. Segment the document by speaker
#' turns first ([qda_segments_set()] with `"speaker"`, or import with
#' `segments = "speaker"`). Interviewer labels are left out. The case variable
#' `document` records where the speaker comes from.
#'
#' @param source Document (id or name) -- or several.
#' @param exclude Speaker labels that are not cases (interviewer, moderator).
#' @param prefix If `TRUE` (default) the case name starts with the document
#'   name (`"group_1 - B1"`), so that `B1` of two groups are different cases.
#'   With `FALSE` the label alone is the name -- then the same person can
#'   collect turns from several documents.
#' @return Invisibly, the touched cases (see [qda_cases()]).
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' f <- file.path(tempdir(), "group.txt")
#' writeLines(c("I: How do you organise the shifts?", "B1: We plan them together.",
#'              "B2: Mostly the manager does it.", "B1: But we can swap."), f)
#' qda_import(f, segments = "speaker")
#' qda_cases_from_speakers(1)
#' qda_cases()
#' qda_close()
qda_cases_from_speakers <- function(source, exclude = c("I", "Int", "Interviewer", "Interviewerin", "Moderation", "Mod", "M"),
                                    prefix = TRUE) {
  plan <- list()
  for (s in source) {
    src <- .resolve_source(s)
    sg <- .segments_for(src)
    if (nrow(sg) == 0) next
    lab <- .speaker_of(substring(src$frozen_text, sg$start, sg$end))
    ok <- !is.na(lab) & !tolower(lab) %in% tolower(exclude)
    if (!any(ok)) next
    nm <- sub("\\.[A-Za-z0-9]+$", "", .utf8(src$name))
    plan[[length(plan) + 1]] <- data.frame(case = if (isTRUE(prefix)) paste(nm, "-", lab[ok]) else lab[ok],
                                           source_id = src$id, start = sg$start[ok], end = sg$end[ok], doc = .utf8(src$name),
                                           stringsAsFactors = FALSE)
  }
  plan <- do.call(rbind, plan)
  if (is.null(plan)) stop("No speaker labels found. Segment the document by speaker turns first (qda_segments_set(source, \"speaker\")).", call. = FALSE)
  # where each speaker comes from (a variable, so it can be compared)
  vars <- lapply(stats::setNames(unique(plan$case), unique(plan$case)),
                 function(nm) c(document = paste(unique(plan$doc[plan$case == nm]), collapse = ", ")))
  .cases_build(plan[, c("case", "source_id", "start", "end")], vars = vars,
               desc = sprintf(.t("F\u00e4lle aus Sprecher*innen: %d"), length(unique(plan$case))))
}

#' One case per value of a document variable
#'
#' For several documents per case: give the documents a variable that names
#' the case (e.g. `person = "P07"` on both interviews of P07), then this
#' function creates one case per value and assigns the documents as a whole.
#' The variable is also set on the case, so `qda_case_matrix(by = key,
#' unit = "case")` works right away.
#'
#' @param key Name of the document variable.
#' @return Invisibly, the touched cases (see [qda_cases()]).
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", c("interview_01.txt", "interview_02.md", "interview_03.docx"),
#'                        package = "jellyqda"))
#' qda_source_set_var(1, "person", "P1"); qda_source_set_var(2, "person", "P1")
#' qda_source_set_var(3, "person", "P2")
#' qda_cases_from_variable("person")
#' qda_cases()
#' qda_close()
qda_cases_from_variable <- function(key) {
  key <- as.character(key)
  av <- .all_source_vars()
  val <- vapply(av, function(v) unname(v[key] %||% NA_character_), character(1))
  val <- val[!is.na(val) & nzchar(val)]
  if (length(val) == 0) stop(sprintf("No document has the variable '%s'.", key), call. = FALSE)
  plan <- data.frame(case = unname(val), source_id = as.integer(names(val)), start = NA_integer_, end = NA_integer_,
                     stringsAsFactors = FALSE)
  vars <- lapply(stats::setNames(unique(plan$case), unique(plan$case)), function(v) stats::setNames(v, key))
  .cases_build(plan, vars = vars, desc = sprintf(.t("F\u00e4lle aus Variable %s: %d"), key, length(vars)))
}
