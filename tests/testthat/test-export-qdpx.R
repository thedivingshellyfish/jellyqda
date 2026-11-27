# REFI-QDA export (R/export_qdpx.R)

qdpx_project <- function() {
  new_project()
  qda_import(c(ext("interview_01.txt"), ext("interview_02.md")))
  qda_code_add("Career path", color = "#0072B2"); qda_code_add("Small company", parent = "Career path")
  qda_code_add("Team & <trust>")
  qda_code_guide("Small company", definition = "Def", anchor = "Anchor", rule = "Rule")
  qda_code(1, "Small company", segment = 3, memo = "first \"job\"")
  qda_code(1, "Career path", start = 1L, end = 4L)               # very start of the text
  qda_code(2, "Team & <trust>", segment = 5)
  qda_coding_set_summary(1, paraphrase = "P", generalization = "G")
  qda_source_set_var(1, "role", "project lead")
  qda_memo_add("project memo"); qda_memo_add("doc memo", source = 1)
  qda_memo_add("code memo", code = "Career path")
  qda_memo_add("passage memo", source = 2, start = 10, end = 30)
}

read_qdpx <- function(f) {
  d <- tempfile(); utils::unzip(f, exdir = d)
  list(dir = d, xml = xml2::read_xml(file.path(d, "project.qde")))
}

test_that("qdpx: zip layout, valid structure, positions hit the coded text", {
  skip_if_not_installed("xml2")
  qdpx_project(); on.exit(qda_close(), add = TRUE)
  f <- qda_export_qdpx(file.path(tempdir(), "t.qdpx"))
  expect_true(file.exists(f))
  files <- zip::zip_list(f)$filename
  expect_true("project.qde" %in% files)
  expect_equal(sum(grepl("^sources/.+\\.txt$", files)), 2)
  q <- read_qdpx(f); x <- q$xml
  ns <- c(q = "urn:QDA-XML:project:1.0")
  expect_equal(xml2::xml_name(x), "Project")
  # element order of the schema: Users, CodeBook, Variables, Sources, Notes, Description, NoteRef
  kids <- xml2::xml_name(xml2::xml_children(x))
  expect_equal(unique(kids), c("Users", "CodeBook", "Variables", "Sources", "Notes", "Description", "NoteRef"))
  # GUIDs in the required format, all unique
  guids <- xml2::xml_attr(xml2::xml_find_all(x, "//q:*[@guid]", ns), "guid")
  expect_true(all(grepl("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", guids)))
  expect_equal(anyDuplicated(guids), 0L)
  # codes: nested, colour, guideline in the description, escaped names
  cb <- xml2::xml_find_all(x, "//q:CodeBook//q:Code", ns)
  expect_setequal(xml2::xml_attr(cb, "name"), c("Career path", "Small company", "Team & <trust>"))
  sub <- xml2::xml_find_first(x, "//q:Code[@name='Career path']/q:Code", ns)
  expect_equal(xml2::xml_attr(sub, "name"), "Small company")
  expect_match(xml2::xml_text(xml2::xml_find_first(sub, "q:Description", ns)), "Anchor")
  # every coding: text file [start, end) == coded passage (REFI counts from 0, end exclusive)
  cd <- qda_codings()
  for (ts in xml2::xml_find_all(x, "//q:TextSource", ns)) {
    path <- sub("^internal://", "", xml2::xml_attr(ts, "plainTextPath"))
    txt <- paste(readLines(file.path(q$dir, "sources", path), encoding = "UTF-8", warn = FALSE), collapse = "\n")
    chars <- strsplit(txt, "")[[1]]
    for (s in xml2::xml_find_all(ts, "q:PlainTextSelection[q:Coding]", ns)) {
      a <- as.integer(xml2::xml_attr(s, "startPosition")); b <- as.integer(xml2::xml_attr(s, "endPosition"))
      expect_true(paste(chars[(a + 1):b], collapse = "") %in% cd$text)
    }
  }
  expect_equal(length(xml2::xml_find_all(x, "//q:Coding", ns)), nrow(cd))
  expect_equal(xml2::xml_attr(xml2::xml_find_first(x, "//q:PlainTextSelection", ns), "startPosition"), "0")
  # comments + Mayring in the description, passage memo as annotation, notes, variables
  desc <- xml2::xml_text(xml2::xml_find_all(x, "//q:PlainTextSelection/q:Description", ns))
  expect_true(any(grepl("first \"job\"", desc, fixed = TRUE)))
  expect_true(any(grepl("Paraphrase: P", desc, fixed = TRUE)))
  expect_true(any(grepl("passage memo", desc, fixed = TRUE)))
  expect_equal(length(xml2::xml_find_all(x, "//q:Notes/q:Note", ns)), 4)
  expect_equal(xml2::xml_text(xml2::xml_find_first(x, "//q:VariableValue/q:TextValue", ns)), "project lead")
  expect_equal(length(xml2::xml_find_all(x, "/q:Project/q:NoteRef", ns)), 1)
  # same GUIDs when exporting again
  f2 <- qda_export_qdpx(file.path(tempdir(), "t2.qdpx"))
  expect_equal(xml2::xml_attr(xml2::xml_find_all(read_qdpx(f2)$xml, "//q:*[@guid]", ns), "guid"), guids)
})

test_that("qdpx validates against the REFI-QDA schema (if a copy is available)", {
  skip_if_not_installed("xml2")
  xsd <- Sys.getenv("JELLYQDA_REFI_XSD")
  skip_if(!nzchar(xsd) || !file.exists(xsd), "set JELLYQDA_REFI_XSD to the REFI-QDA Project.xsd")
  qdpx_project(); on.exit(qda_close(), add = TRUE)
  q <- read_qdpx(qda_export_qdpx(file.path(tempdir(), "v.qdpx")))
  expect_true(xml2::xml_validate(q$xml, xml2::read_xml(xsd)))
})

test_that("qda_export('qdpx') and empty projects", {
  new_project(); on.exit(qda_close(), add = TRUE)
  f <- qda_export_qdpx(file.path(tempdir(), "empty.qdpx"))
  expect_true("project.qde" %in% zip::zip_list(f)$filename)
  qda_import(ext("interview_01.txt"))
  ex <- qda_export("qdpx")
  expect_equal(ex$what, "qdpx")
  expect_true(grepl("\\.qdpx$", ex$file))
  expect_false("qdpx" %in% qda_export("all")$what)
})
