# Cases independent of documents (R/cases.R, R/cases_vars.R,
# R/cases_build.R, R/cases_data.R) and where they show up: case matrix,
# query, export, report, REFI-QDA

test_that("a case collects whole documents and passages; every change is undoable", {
  new_project(); on.exit(qda_close(), add = TRUE)
  qda_import(ext(c("interview_01.txt", "interview_02.md")))
  qda_case_add("Person A", sources = 1, description = "first wave")
  cs <- qda_cases()
  expect_equal(cs$name, "Person A"); expect_equal(cs$documents, 1L); expect_equal(cs$passages, 0L)
  expect_error(qda_case_add("Person A"), "already exists")
  qda_case_assign("Person A", 2, segment = c(1, 2))
  qda_case_assign("Person A", 2, segment = 1)                     # twice: ignored
  m <- qda_case_members("Person A")
  expect_equal(nrow(m), 3L)
  expect_true(is.na(m$start[1])); expect_equal(m$chars[1], nchar(jellyqda:::.texts(1)))
  seg <- qda_source_segments(2)
  expect_equal(m$text[2], seg$text[1])
  expect_error(qda_case_assign("Person A", 2, start = 5, end = 2), "Invalid passage")
  qda_undo()                                                      # the two segments again out
  expect_equal(nrow(qda_case_members("Person A")), 1L)
  qda_redo(); expect_equal(nrow(qda_case_members("Person A")), 3L)
  qda_case_unassign("Person A", source = 2)
  expect_equal(nrow(qda_case_members("Person A")), 1L)
  qda_case_update("Person A", name = "P-A", description = "both waves")
  expect_equal(qda_cases()$description, "both waves")
  qda_case_delete("P-A"); expect_equal(nrow(qda_cases()), 0L)
  qda_undo()                                                      # back, with its member
  expect_equal(qda_cases()$name, "P-A"); expect_equal(nrow(qda_case_members("P-A")), 1L)
  expect_true(all(c("case_add", "case_assign", "case_delete") %in% qda_events()$action))
})

test_that("case variables are set, deleted, undone and listed as columns", {
  new_project(); on.exit(qda_close(), add = TRUE)
  qda_case_add("P1"); qda_case_add("P2")
  qda_case_set_var("P1", "role", "nurse"); qda_case_set_var("P2", "role", "doctor")
  qda_case_set_var("P1", "age", 34)
  expect_equal(qda_case_vars("P1"), c(role = "nurse", age = "34"))
  cs <- qda_cases()
  expect_equal(cs$role, c("nurse", "doctor")); expect_equal(cs$age, c("34", NA))
  qda_case_del_var("P1", "age"); expect_equal(names(qda_case_vars("P1")), "role")
  qda_undo(); expect_equal(unname(qda_case_vars("P1")["age"]), "34")
})

test_that("cases from the speakers of a group interview", {
  new_project(); on.exit(qda_close(), add = TRUE)
  f <- file.path(tempfile(), "group_1.txt"); dir.create(dirname(f))
  writeLines(c("I: How do you plan the shifts?", "B1: We plan them together.",
               "B2: Mostly the manager does it.", "[00:01:10] B1: But we can swap.", "I: Thanks."), f)
  qda_import(f, segments = "speaker")
  qda_cases_from_speakers(1)
  cs <- qda_cases()
  expect_equal(cs$name, c("group_1 - B1", "group_1 - B2"))
  expect_equal(cs$passages, c(2L, 1L)); expect_equal(cs$document, c("group_1.txt", "group_1.txt"))
  expect_match(qda_case_members("group_1 - B1")$text[2], "But we can swap")
  qda_undo(); expect_equal(nrow(qda_cases()), 0L)                 # one undo step for everything
  qda_cases_from_speakers(1, prefix = FALSE)
  expect_equal(qda_cases()$name, c("B1", "B2"))
  g <- file.path(dirname(f), "notes.txt"); writeLines(c("Only notes.", "", "No speakers here."), g)
  qda_import(g)
  expect_error(qda_cases_from_speakers(2), "No speaker labels")
})

test_that("cases from a document variable: several interviews per person", {
  new_project(); on.exit(qda_close(), add = TRUE)
  qda_import(ext(c("interview_01.txt", "interview_02.md", "interview_03.docx")))
  qda_source_set_var(1, "person", "P1"); qda_source_set_var(2, "person", "P1"); qda_source_set_var(3, "person", "P2")
  qda_cases_from_variable("person")
  cs <- qda_cases()
  expect_equal(cs$name, c("P1", "P2")); expect_equal(cs$documents, c(2L, 1L)); expect_equal(cs$person, c("P1", "P2"))
  qda_cases_from_variable("person")                                  # again: nothing new
  expect_equal(nrow(qda_case_members("P1")), 2L)
  expect_error(qda_cases_from_variable("nope"), "No document has")
})

test_that("case matrix and query by case; a coding in two cases of a group counts once", {
  viz_setup(); on.exit(qda_close(), add = TRUE)                   # helper-visuals.R: one transcript, codes A (A1), B, C
  viz_code("A", 2); viz_code("B", 2); viz_code("B", 3); viz_code("C", 5)
  qda_case_add("X"); qda_case_assign("X", 1, segment = 2:3)
  qda_case_add("Y"); qda_case_assign("Y", 1, segment = c(3, 5))
  qda_case_set_var("X", "group", "g"); qda_case_set_var("Y", "group", "g")
  m <- qda_case_matrix(unit = "case")
  expect_equal(names(m)[4:5], c("X", "Y"))
  expect_equal(m$X[m$code == "B"], 2L); expect_equal(m$Y[m$code == "B"], 1L); expect_equal(m$Y[m$code == "C"], 1L)
  g <- qda_case_matrix("group", unit = "case")
  expect_equal(g$g[g$code == "B"], 2L)                              # coding in segment 3 is in X and Y: once
  expect_equal(attr(g, "n_units")[["g"]], 2L)
  p <- qda_case_matrix(unit = "case", percent = TRUE)
  expect_equal(sum(p$X[p$depth == 1]), 100)
  expect_error(qda_case_matrix(), "Give `by`")
  q <- qda_query(any = "B", case = "Y")
  expect_equal(q$segment, 3L)
  expect_equal(attr(q, "info")$case, "Y")
})

test_that("cases go into the export, the report and the REFI-QDA file", {
  viz_setup(); on.exit(qda_close(), add = TRUE)
  viz_code("A", 2)
  qda_case_add("Whole", sources = 1); qda_case_add("Part"); qda_case_assign("Part", 1, segment = 2)
  qda_case_set_var("Part", "role", "nurse")
  out <- qda_export("all", path = file.path(tempfile(), "ex"))
  expect_true("cases" %in% out$what)
  csv <- readr::read_csv(out$file[out$what == "cases"], show_col_types = FALSE)
  expect_equal(nrow(csv), 2L); expect_equal(csv$role[csv$case == "Part"], "nurse")
  html <- paste(readLines(out$file[out$what == "report"], encoding = "UTF-8"), collapse = "\n")
  expect_match(html, "F\u00e4lle"); expect_match(html, "Codes je Fall")
  f <- qda_export_qdpx(file.path(tempfile(), "p.qdpx"))
  xml <- paste(readLines(unz(f, "project.qde"), encoding = "UTF-8"), collapse = "\n")
  expect_match(xml, '<Case guid="[^"]+" name="Part">')
  expect_match(xml, "<SelectionRef targetGUID=")
  expect_match(xml, '<Case guid="[^"]+" name="Whole"><SourceRef targetGUID=')
  expect_true(regexpr("<Cases>", xml) < regexpr("<Sources>", xml))   # order of the schema
})
