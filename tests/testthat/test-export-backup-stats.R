# jellyqda :: test-export-backup-stats.R --------------------------------------
# Windows notes: never compare absolute path STRINGS (8.3 short names vs.
# long names, mixed slashes), and never rely on Sys.chmod() to make a
# directory unwritable on Windows (POSIX permission bits are not enforced
# for directory creation there). The fallback is triggered deterministically
# by blocking the default backup location with a regular file instead.

test_that("end-to-end: import, code, export, backup, stats, audit", {
  p <- new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(c(ext("interview_01.txt"), ext("interview_02.md"), ext("fieldnotes.pdf")))
  qda_code_add("Werdegang"); qda_code_add("KMU", parent = "Werdegang")
  qda_code_add("Motivation")
  qda_code(1, segment = 2, code = "KMU", memo = "5 Jahre KMU")
  qda_code(1, segment = 4, code = "Motivation")
  qda_code(2, segment = 2, code = "Motivation")
  qda_code(3, segment = 1, code = "Werdegang")

  # export
  ex <- qda_export("all")
  expect_true(all(file.exists(ex$file)))
  expect_true(any(grepl("segments_.*\\.csv$", ex$file)))
  expect_true(any(grepl("codebook_.*\\.docx$", ex$file)))
  expect_true(any(grepl("audit_.*\\.csv$", ex$file)))
  audit <- readr::read_csv(ex$file[grepl("audit_.*\\.csv$", ex$file)], show_col_types = FALSE)
  expect_true(all(c("import", "code_add", "coding_add") %in% audit$action))
  # the export action itself is logged after writing, check the events table
  ev <- DBI::dbGetQuery(qda_con(), "SELECT action FROM events")$action
  expect_true("export" %in% ev)
  seg_csv <- readr::read_csv(ex$file[grepl("segments_.*\\.csv$", ex$file)], show_col_types = FALSE)
  expect_equal(nrow(seg_csv), 4)
  expect_true("5 Jahre KMU" %in% seg_csv$memo)

  # stats
  st <- qda_stats()
  expect_equal(st$overall$n_sources, 3)
  expect_equal(st$overall$n_codes, 3)
  expect_equal(st$overall$n_codings, 4)
  expect_gt(st$overall$pct_coded, 0)
  expect_equal(sum(st$per_code$n_codings), 4)
  expect_equal(nrow(st$per_source), 3)
  m <- qda_matrix()
  expect_equal(nrow(m), 3)
  expect_equal(sum(as.matrix(m[, -1])), 4)

  # backup: zip lands OUTSIDE the project dir, contains the project file
  z <- qda_backup(quiet = TRUE)
  expect_true(file.exists(z))
  expect_false(basename(dirname(z)) == basename(dirname(p)))
  expect_true(basename(p) %in% zip::zip_list(z)$filename)
  expect_true("originals/interview_01.txt" %in% zip::zip_list(z)$filename)
})

test_that("backup falls back to a project-local dir when the parent is not writable", {
  outer <- tempfile("qda-outer-")
  inner <- file.path(outer, "projekt")
  dir.create(inner, recursive = TRUE)
  # deterministic on every OS (Windows ACLs and root included): block the
  # default backup location with a regular FILE so the directory cannot be
  # created there -> .writable_dir() is FALSE -> fallback must trigger
  lock <- file.path(outer, "jellyqda-backups")
  file.create(lock)
  on.exit(unlink(outer, recursive = TRUE), add = TRUE)
  p <- file.path(inner, "proj.jellyqda")
  qda_open(p)
  on.exit(qda_close(), add = TRUE)
  # form-independent checks: the fallback dir lives INSIDE the project dir
  fb <- default_backup_dir()
  expect_equal(basename(dirname(fb)), "projekt")
  z <- qda_backup(quiet = TRUE)
  expect_true(file.exists(z))
  expect_equal(basename(dirname(z)), "jellyqda-backups")
  expect_equal(basename(dirname(dirname(z))), "projekt")
  # explicit non-writable path also falls back with a warning
  expect_warning(
    z2 <- qda_backup(path = lock, quiet = TRUE),
    "nicht beschreibbar"
  )
  expect_true(file.exists(z2))
  expect_equal(basename(dirname(dirname(z2))), "projekt")
})

test_that("backup rotation keeps only the newest `keep` snapshots", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  bdir <- tempfile("qda-backups-")
  for (i in 1:3) {
    Sys.sleep(1.1)  # distinct timestamps
    qda_backup(path = bdir, keep = 2, quiet = TRUE)
  }
  zips <- list.files(bdir, pattern = "\\.zip$", full.names = TRUE)
  expect_equal(length(zips), 2)
})

test_that("auto-snapshot fires after n actions", {
  p <- new_project(auto_snapshot = 3)
  on.exit(qda_close(), add = TRUE)
  qda_code_add("A")   # event 2 (project_create is 1)
  qda_code_add("B")   # event 3 -> threshold reached on next logged action
  qda_code_add("C")   # triggers auto snapshot
  ev <- DBI::dbGetQuery(qda_con(), "SELECT action FROM events")$action
  expect_true("auto_snapshot" %in% ev)
  zips <- list.files(default_backup_dir(), pattern = "\\.zip$", full.names = TRUE)
  expect_gte(length(zips), 1)
})
