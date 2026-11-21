# Synthetic interview transcript in the typical format
#   [hh:mm:ss] I: ...
#   [hh:mm:ss] P: ...
# (speaker turns on single lines, only one blank line after the header),
# with umlauts, sharp s and HTML-special characters (<, >, &, ") so that
# encoding and escaping are exercised as well.
make_transcript <- function(turns = 20, seed = 1) {
  set.seed(seed)
  words <- c("Marmeladenglas", "Fu\u00dfabdruck", "Nebelgl\u00f6ckchen", "Pr\u00fcfungsamt",
             "Zollstock", "Wetterhahn", "M\u00e4ngel", "<Tag>", "A & B", "\"Zitat\"")
  header <- c("DUMMY-TRANSCRIPT - nur fuer Tests",
              "Interview-Code:  TEST_001",
              "------------------------------------------------------------",
              "")
  t <- 0
  body <- character(turns)
  for (i in seq_len(turns)) {
    t <- t + sample(5:90, 1)
    who <- if (i %% 2 == 1) "I" else "P"
    txt <- paste(sample(words, sample(3:25, 1), replace = TRUE), collapse = " ")
    body[i] <- sprintf("[%02d:%02d:%02d] %s: %s.", t %/% 3600, (t %/% 60) %% 60, t %% 60, who, txt)
  }
  c(header, body, "(Unverst\u00e4ndliche Stelle)", "ENDE")
}

# write the transcript to a temp .txt file and return its path
transcript_file <- function(...) {
  f <- tempfile("transkript-", fileext = ".txt")
  writeLines(enc2utf8(make_transcript(...)), f, useBytes = TRUE)
  f
}

# visible text of the rendered document browser HTML (tags removed,
# entities decoded) -- must always equal the frozen text
rendered_text <- function(html) {
  x <- gsub("<[^>]+>", "", html)
  for (p in list(c("&lt;", "<"), c("&gt;", ">"), c("&quot;", "\""),
                 c("&#39;", "'"), c("&amp;", "&"))) {
    x <- gsub(p[1], p[2], x, fixed = TRUE)
  }
  x
}

# compact comparable state of the whole project (for undo/redo tests)
project_state <- function() {
  con <- qda_con()
  q <- function(sql) DBI::dbGetQuery(con, sql)
  list(codes = q("SELECT id, label, parent_id, color, description FROM codes ORDER BY id"),
       codings = q("SELECT id, source_id, code_id, start, end, memo FROM codings ORDER BY id"),
       memos = q("SELECT id, text_ FROM memos ORDER BY id"),
       summaries = q("SELECT id, code_id, source_id, text_ FROM summaries ORDER BY id"),
       meta = q("SELECT id, meta_json FROM sources ORDER BY id"))
}
