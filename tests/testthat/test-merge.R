# Merging a team copy into the open project (R/merge.R)

# Lead project with two documents and a code system; a copy for "Anna".
merge_setup <- function() {
  d <- tempfile("merge-"); dir.create(d)
  lead <- file.path(d, "lead.jellyqda")
  qda_open(lead, auto_snapshot = Inf)
  qda_import(ext(c("interview_01.txt", "interview_02.md")))
  qda_code_add("Team"); qda_code_add("Support", parent = "Team"); qda_code_add("Career path")
  qda_source_set_var(1, "role", "nurse")
  copy <- qda_intercoder_copy(file.path(d, "anna.jellyqda"))
  list(dir = d, lead = lead, copy = copy)
}

test_that("codings, new codes, memos, variables, documents and cases come over; nothing twice", {
  p <- merge_setup(); on.exit(qda_close(), add = TRUE)
  qda_code(1, "Support", segment = 2)                   # lead codes document 1
  qda_close()
  qda_open(p$copy, auto_snapshot = Inf)                  # Anna codes document 2 and adds things
  qda_code(2, "Career path", segment = 2)
  qda_code(1, "Support", segment = 2)                   # the same as the lead: not twice
  qda_code_add("Motivation", parent = "Team"); qda_code(2, "Motivation", segment = 3)
  qda_code_guide("Career path", definition = "How people got into the job")
  qda_memo_add("Strong passage", source = 2, start = 1, end = 20, title = "Note")
  qda_memo_add("Anna's thoughts on the project")
  qda_source_set_var(1, "role", "doctor")                # conflict: lead says nurse
  qda_source_set_var(2, "site", "North")
  f <- file.path(p$dir, "extra.txt"); writeLines(c("I: Hello.", "B: An extra interview only Anna has."), f)
  qda_import(f); qda_code(3, "Career path", start = 1, end = 9)
  qda_case_add("Anna's case", sources = 2); qda_case_set_var("Anna's case", "group", "A")
  qda_close()

  qda_open(p$lead, auto_snapshot = Inf)
  n_before <- nrow(qda_codings())
  dry <- qda_merge(p$copy, dry_run = TRUE)
  expect_true(attr(dry, "dry_run"))
  expect_equal(nrow(qda_codings()), n_before)            # dry run writes nothing
  expect_equal(nrow(qda_sources()), 2L)
  res <- qda_merge(p$copy)
  expect_equal(res, dry, ignore_attr = TRUE)            # the dry run told the truth
  get <- function(w, k) res[[k]][res$what == w]
  expect_equal(get("documents", "added"), 1L); expect_equal(get("documents", "already"), 2L)
  expect_equal(get("codes", "added"), 1L)                # Motivation
  expect_equal(get("codings", "added"), 3L); expect_equal(get("codings", "already"), 1L)
  expect_equal(get("memos", "added"), 2L)
  expect_equal(get("variables", "conflicts"), 1L)        # role: nurse vs doctor
  expect_equal(get("cases", "added"), 1L)
  expect_equal(qda_source_vars(1)[["role"]], "nurse")    # the open project keeps its value
  expect_equal(qda_source_vars(2)[["site"]], "North")
  expect_true("Team / Motivation" %in% qda_codes()$path)
  expect_equal(qda_codes()$description[qda_codes()$label == "Career path"], "How people got into the job")
  expect_equal(nrow(qda_codings()), n_before + 3L)
  expect_equal(qda_sources()$name[3], "extra.txt")
  expect_equal(qda_case_vars("Anna's case")[["group"]], "A")
  expect_equal(qda_case_members("Anna's case")$source_id, 2L)
  expect_true("merge" %in% qda_events()$action)
  expect_true(length(list.files(default_backup_dir(), pattern = "\\.zip$")) >= 1)   # backup first
  again <- qda_merge(p$copy)                             # merging twice adds nothing
  expect_equal(sum(again$added), 0L)
})

test_that("add_documents = FALSE leaves out documents (and their codings) that are not here", {
  p <- merge_setup(); on.exit(qda_close(), add = TRUE)
  qda_close()
  qda_open(p$copy, auto_snapshot = Inf)
  f <- file.path(p$dir, "extra.txt"); writeLines("Only in the copy.", f)
  qda_import(f); qda_code(3, "Team", start = 1, end = 4)
  qda_close()
  qda_open(p$lead, auto_snapshot = Inf)
  res <- qda_merge(p$copy, add_documents = FALSE, backup = FALSE)
  expect_equal(nrow(qda_sources()), 2L)
  expect_equal(attr(res, "skipped_documents"), 1L)
  expect_equal(res$added[res$what == "codings"], 0L)
  expect_error(qda_merge(p$lead), "open project itself")
  bad <- file.path(p$dir, "x.jellyqda"); con <- DBI::dbConnect(RSQLite::SQLite(), bad)
  DBI::dbExecute(con, "CREATE TABLE t (a INTEGER)"); DBI::dbDisconnect(con)
  expect_error(qda_merge(bad), "not a jellyqda project")
})
