# jellyqda :: cases.R -- cases independent of documents
#
#   qda_cases()          all cases with their number of documents and passages
#   qda_case_add()       a new case, optionally with whole documents
#   qda_case_update()    rename a case or change its description
#   qda_case_delete()    delete a case (the documents stay)
#   qda_case_assign()    add a whole document, a passage or segments to a case
#   qda_case_unassign()  take documents or passages out of a case
#   qda_case_members()   what belongs to a case
#
# A case is the unit you compare: a person, a team, an organisation. Often a
# case is simply one interview -- then document variables are enough. Cases
# are needed when that does not fit:
#   * several documents per case (a person interviewed twice, interview +
#     field notes on the same team)            -> whole documents
#   * several cases per document (group interview, focus group)
#                                              -> passages, e.g. speaker turns
# Tables (schema.R): cases (name, description, meta_json with the case
# variables) and case_members (case_id, source_id, start/end; NULL = the whole
# document). Every change is one undo step. Case variables: cases_vars.R;
# building cases automatically: cases_build.R; codings per case: cases_data.R.

#' Resolve a case argument (id or name) to its row.
#' @noRd
.resolve_case <- function(x) {
  con <- qda_con()
  row <- if (is.numeric(x)) {
    DBI::dbGetQuery(con, "SELECT id, name, description, meta_json FROM cases WHERE id = ?", params = list(as.integer(x)))
  } else {
    DBI::dbGetQuery(con, "SELECT id, name, description, meta_json FROM cases WHERE name = ?", params = list(as.character(x)))
  }
  if (nrow(row) == 0) stop(sprintf("No case found for '%s'.", x), call. = FALSE)
  row$name <- .utf8(row$name); row$description <- .utf8(row$description %||% "")
  row
}

#' Member ids of a case (for undo snapshots).
#' @noRd
.case_member_ids <- function(case_id) {
  DBI::dbGetQuery(qda_con(), "SELECT id FROM case_members WHERE case_id = ?", params = list(as.integer(case_id)))$id
}

#' List the cases of the project
#'
#' @return A tibble with one row per case: `id`, `name`, `description`,
#'   `documents` (number of documents with at least a part in the case),
#'   `passages` (number of passages, i.e. parts of documents), `sources`
#'   (names of the documents, comma-separated) and one column per case
#'   variable.
#' @seealso [qda_case_add()], [qda_case_vars()], [qda_case_matrix()]
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", c("interview_01.txt", "interview_02.md"), package = "jellyqda"))
#' qda_case_add("Person A", sources = 1:2)   # interviewed twice
#' qda_cases()
#' qda_close()
qda_cases <- function() {
  con <- qda_con()
  cs <- DBI::dbGetQuery(con, "SELECT id, name, description, meta_json FROM cases ORDER BY name COLLATE NOCASE, id")
  m <- DBI::dbGetQuery(con, "SELECT m.case_id, m.source_id, m.start, s.name AS source FROM case_members m
                             JOIN sources s ON s.id = m.source_id ORDER BY m.case_id, m.source_id, m.start")
  m$source <- .utf8(m$source)
  out <- tibble::tibble(
    id = as.integer(cs$id), name = .utf8(cs$name), description = .utf8(cs$description %||% character()),
    documents = vapply(cs$id, function(i) length(unique(m$source_id[m$case_id == i])), integer(1)),
    passages = vapply(cs$id, function(i) sum(m$case_id == i & !is.na(m$start)), integer(1)),
    sources = vapply(cs$id, function(i) paste(unique(m$source[m$case_id == i]), collapse = ", "), character(1)))
  vars <- .all_case_vars()
  keys <- sort(unique(unlist(lapply(vars, names))))
  for (k in keys) out[[k]] <- vapply(as.character(out$id), function(i) unname(vars[[i]][k] %||% NA_character_),
                                     character(1), USE.NAMES = FALSE)
  out
}

#' Create a case
#'
#' A case is the unit you want to compare -- a person, a group, an
#' organisation. It can consist of several whole documents (a person
#' interviewed twice) or of passages (the speaker turns of one participant
#' in a group interview, see [qda_cases_from_speakers()]). Codings count for
#' a case when they lie in one of its documents or passages.
#'
#' @param name Unique name of the case.
#' @param sources Optional documents (ids or names) that belong to the case
#'   as a whole.
#' @param description Optional short description.
#' @return Invisibly, the new case as one-row tibble (see [qda_cases()]).
#' @seealso [qda_case_assign()], [qda_case_set_var()], [qda_cases_from_variable()]
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", c("interview_01.txt", "interview_02.md"), package = "jellyqda"))
#' qda_case_add("Team North", sources = 1, description = "Project team, site North")
#' qda_cases()
#' qda_close()
qda_case_add <- function(name, sources = NULL, description = "") {
  con <- qda_con()
  name <- trimws(as.character(name))
  if (!nzchar(name)) stop("A case needs a name.", call. = FALSE)
  if (nrow(DBI::dbGetQuery(con, "SELECT id FROM cases WHERE name = ?", params = list(name)))) {
    stop(sprintf("A case named '%s' already exists.", name), call. = FALSE)
  }
  sids <- vapply(sources %||% integer(), function(s) as.integer(.resolve_source(s)$id), integer(1))
  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, "INSERT INTO cases (name, description, meta_json) VALUES (?, ?, '{}')",
                   params = list(name, as.character(description %||% "")))
    cid <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
    for (s in unique(sids)) DBI::dbExecute(con, "INSERT INTO case_members (case_id, source_id) VALUES (?, ?)", params = list(cid, s))
  })
  log_event("case_add", list(case_id = cid, name = name, documents = length(unique(sids))),
            changes = list(.chg("cases", .snap("cases", integer()), .snap("cases", cid)),
                           .chg("case_members", .snap("case_members", integer()), .snap("case_members", .case_member_ids(cid)))),
            desc = sprintf(.t("Fall angelegt: %s"), name))
  invisible(qda_cases()[qda_cases()$id == cid, ])
}

#' Rename a case or change its description
#'
#' @param case Case id or name.
#' @param name New name (optional).
#' @param description New description (optional).
#' @return Invisibly, the case as one-row tibble.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_case_add("P1")
#' qda_case_update("P1", name = "Person 1", description = "nurse, night shifts")
#' qda_cases()
#' qda_close()
qda_case_update <- function(case, name = NULL, description = NULL) {
  con <- qda_con()
  cs <- .resolve_case(case)
  new_name <- if (is.null(name)) cs$name else trimws(as.character(name))
  if (!nzchar(new_name)) stop("A case needs a name.", call. = FALSE)
  if (new_name != cs$name && nrow(DBI::dbGetQuery(con, "SELECT id FROM cases WHERE name = ?", params = list(new_name)))) {
    stop(sprintf("A case named '%s' already exists.", new_name), call. = FALSE)
  }
  before <- .snap("cases", cs$id)
  DBI::dbExecute(con, "UPDATE cases SET name = ?, description = ? WHERE id = ?",
                 params = list(new_name, as.character(description %||% cs$description), cs$id))
  log_event("case_update", list(case_id = cs$id), changes = list(.chg("cases", before, .snap("cases", cs$id))),
            desc = if (new_name != cs$name) sprintf(.t("Fall umbenannt: %s -> %s"), cs$name, new_name)
                   else sprintf(.t("Fall bearbeitet: %s"), cs$name))
  invisible(qda_cases()[qda_cases()$id == cs$id, ])
}

#' Delete a case
#'
#' Removes the case and its assignments. The documents, codings and memos
#' stay untouched. Can be undone with [qda_undo()].
#'
#' @param case Case id or name.
#' @return Invisibly, `TRUE`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_case_add("P1")
#' qda_case_delete("P1")
#' qda_cases()
#' qda_close()
qda_case_delete <- function(case) {
  con <- qda_con()
  cs <- .resolve_case(case)
  mids <- .case_member_ids(cs$id)
  before <- list(.snap("cases", cs$id), .snap("case_members", mids))
  DBI::dbExecute(con, "DELETE FROM cases WHERE id = ?", params = list(cs$id))   # members: ON DELETE CASCADE
  log_event("case_delete", list(case_id = cs$id, name = cs$name),
            changes = list(.chg("cases", before[[1]], .snap("cases", integer())),
                           .chg("case_members", before[[2]], .snap("case_members", integer()))),
            desc = sprintf(.t("Fall gel\u00f6scht: %s"), cs$name))
  invisible(TRUE)
}

#' Assign documents or passages to a case
#'
#' Without `start`/`end`/`segment` the whole document belongs to the case.
#' With `start` and `end` (character positions, 1-based, as in
#' [qda_code()]) or `segment` (segment numbers) only these passages belong to
#' it -- e.g. the turns of one participant in a group interview. A document
#' can belong to several cases. Assigning the same thing twice is ignored.
#'
#' @param case Case id or name.
#' @param source Document (id or name).
#' @param start,end Optional passage (character positions, inclusive).
#' @param segment Optional segment number(s) of the document.
#' @return Invisibly, the members of the case (see [qda_case_members()]).
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", c("interview_01.txt", "interview_02.md"), package = "jellyqda"))
#' qda_case_add("Person A")
#' qda_case_assign("Person A", 1)                   # the whole first interview
#' qda_case_assign("Person A", 2, segment = c(3, 5)) # two turns of the second
#' qda_case_members("Person A")
#' qda_close()
qda_case_assign <- function(case, source, start = NULL, end = NULL, segment = NULL) {
  con <- qda_con()
  cs <- .resolve_case(case)
  src <- .resolve_source(source)
  n <- nchar(src$frozen_text, type = "chars")
  ranges <- if (!is.null(segment)) {
    sg <- .segments_for(src)
    bad <- setdiff(as.integer(segment), sg$segment)
    if (length(bad)) stop(sprintf("No segment %s in '%s'.", paste(bad, collapse = ", "), src$name), call. = FALSE)
    sg[sg$segment %in% as.integer(segment), c("start", "end")]
  } else if (!is.null(start) || !is.null(end)) {
    if (is.null(start) || is.null(end)) stop("Give both `start` and `end` (or neither).", call. = FALSE)
    if (start < 1 || end < start || end > n) stop(sprintf("Invalid passage %s-%s (the document has %d characters).", start, end, n), call. = FALSE)
    data.frame(start = as.integer(start), end = as.integer(end))
  } else data.frame(start = NA_integer_, end = NA_integer_)
  have <- DBI::dbGetQuery(con, "SELECT start, end FROM case_members WHERE case_id = ? AND source_id = ?", params = list(cs$id, src$id))
  key <- function(a, b) paste(ifelse(is.na(a), "-", a), ifelse(is.na(b), "-", b))
  ranges <- ranges[!key(ranges$start, ranges$end) %in% key(have$start, have$end), , drop = FALSE]
  if (nrow(ranges) == 0) return(invisible(qda_case_members(cs$id)))
  before_ids <- .case_member_ids(cs$id)
  DBI::dbWithTransaction(con, {
    for (i in seq_len(nrow(ranges))) {
      DBI::dbExecute(con, "INSERT INTO case_members (case_id, source_id, start, end) VALUES (?, ?, ?, ?)",
                     params = list(cs$id, src$id, ranges$start[i], ranges$end[i]))
    }
  })
  new_ids <- setdiff(.case_member_ids(cs$id), before_ids)
  log_event("case_assign", list(case_id = cs$id, source_id = src$id, n = length(new_ids)),
            changes = list(.chg("case_members", .snap("case_members", integer()), .snap("case_members", new_ids))),
            desc = if (is.na(ranges$start[1])) sprintf(.t("Dokument zum Fall %s: %s"), cs$name, .utf8(src$name))
                   else sprintf(.t("%d Stelle(n) aus %s zum Fall %s"), length(new_ids), .utf8(src$name), cs$name))
  invisible(qda_case_members(cs$id))
}

#' Take documents or passages out of a case
#'
#' @param case Case id or name.
#' @param source Optional document (id or name): everything of this document
#'   is taken out of the case.
#' @param member Optional member ids (column `id` of [qda_case_members()]).
#' @return Invisibly, the remaining members of the case.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", c("interview_01.txt", "interview_02.md"), package = "jellyqda"))
#' qda_case_add("Person A", sources = 1:2)
#' qda_case_unassign("Person A", source = 2)
#' qda_case_members("Person A")
#' qda_close()
qda_case_unassign <- function(case, source = NULL, member = NULL) {
  con <- qda_con()
  cs <- .resolve_case(case)
  m <- DBI::dbGetQuery(con, "SELECT id, source_id FROM case_members WHERE case_id = ?", params = list(cs$id))
  ids <- if (!is.null(member)) intersect(as.integer(member), m$id)
         else if (!is.null(source)) m$id[m$source_id == .resolve_source(source)$id]
         else stop("Give `source` or `member`.", call. = FALSE)
  if (length(ids) == 0) return(invisible(qda_case_members(cs$id)))
  before <- .snap("case_members", ids)
  DBI::dbExecute(con, sprintf("DELETE FROM case_members WHERE id IN (%s)", paste(ids, collapse = ",")))
  log_event("case_unassign", list(case_id = cs$id, n = length(ids)),
            changes = list(.chg("case_members", before, .snap("case_members", integer()))),
            desc = sprintf(.t("%d Teil(e) aus dem Fall %s entfernt"), length(ids), cs$name))
  invisible(qda_case_members(cs$id))
}

#' What belongs to a case
#'
#' @param case Case id or name.
#' @return A tibble, one row per member: `id`, `source_id`, `source`,
#'   `start`, `end` (`NA` for a whole document), `chars` and `text` (the
#'   passage; for whole documents the first 200 characters).
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_case_add("Person A")
#' qda_case_assign("Person A", 1, segment = 2)
#' qda_case_members("Person A")
#' qda_close()
qda_case_members <- function(case) {
  cs <- .resolve_case(case)
  m <- DBI::dbGetQuery(qda_con(), "SELECT m.id, m.source_id, s.name AS source, m.start, m.end FROM case_members m
                                   JOIN sources s ON s.id = m.source_id WHERE m.case_id = ? ORDER BY m.source_id, m.start",
                       params = list(cs$id))
  txt <- .texts(m$source_id)
  whole <- is.na(m$start)
  len <- nchar(txt, type = "chars")
  st <- ifelse(whole, 1L, m$start); en <- ifelse(whole, pmin(len, 200L), m$end)
  tibble::tibble(id = as.integer(m$id), source_id = as.integer(m$source_id), source = .utf8(m$source),
                 start = as.integer(m$start), end = as.integer(m$end),
                 chars = as.integer(ifelse(whole, len, m$end - m$start + 1L)),
                 text = if (nrow(m)) substring(txt, st, en) else character())
}
