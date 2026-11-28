# jellyqda :: schema.R -- CREATE TABLE IF NOT EXISTS for the whole project DB
# Tables: sources, codes, codings, memos, summaries, segments, cases,
# case_members, events. sources.frozen_text
# is the frozen import text all offsets refer to; meta_json holds import
# metadata + per-source variables (sources.R).

# Database schema ------------------------------------------------------------
# Mirrors the data model of the concept (section 4), plus created_at on
# events so every action carries a timestamp (concept section 8).

#' @noRd
create_schema <- function(con) {
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS sources (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      format TEXT NOT NULL,
      frozen_text TEXT NOT NULL,
      meta_json TEXT NOT NULL DEFAULT '{}'
    )")
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS codes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      label TEXT NOT NULL,
      parent_id INTEGER REFERENCES codes(id) ON DELETE CASCADE,
      color TEXT NOT NULL DEFAULT '#E69F00',
      description TEXT NOT NULL DEFAULT ''
    )")
  DBI::dbExecute(con, "
    CREATE UNIQUE INDEX IF NOT EXISTS idx_codes_label_parent
    ON codes(label, IFNULL(parent_id, 0))")
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS codings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source_id INTEGER NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
      code_id INTEGER NOT NULL REFERENCES codes(id) ON DELETE CASCADE,
      start INTEGER NOT NULL,
      end INTEGER NOT NULL,
      memo TEXT NOT NULL DEFAULT '',
      CHECK (start >= 1 AND end >= start)
    )")
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS memos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      text_ TEXT NOT NULL,
      created_at TEXT NOT NULL
    )")
  # V3: four kinds of memos (memos.R). Added with ALTER TABLE so that older
  # project files are upgraded in place; existing memos become 'project'.
  #   kind = 'passage'  -> source_id + start/end (a text passage)
  #          'document' -> source_id
  #          'code'     -> code_id
  #          'project'  -> no reference
  have <- DBI::dbGetQuery(con, "PRAGMA table_info(memos)")$name
  add_col <- function(name, def) {
    if (!name %in% have) DBI::dbExecute(con, sprintf("ALTER TABLE memos ADD COLUMN %s %s", name, def))
  }
  add_col("kind", "TEXT NOT NULL DEFAULT 'project'")
  add_col("title", "TEXT NOT NULL DEFAULT ''")
  add_col("source_id", "INTEGER REFERENCES sources(id) ON DELETE CASCADE")
  add_col("code_id", "INTEGER REFERENCES codes(id) ON DELETE CASCADE")
  add_col("start", "INTEGER")
  add_col("end", "INTEGER")
  add_col("updated_at", "TEXT")
  # V5 (0.6.0): coding guideline per code (anchor example, coding rule; the
  # definition is in description) and Mayring summary per coding
  # (paraphrase, generalisation). Without NOT NULL: older undo snapshots do
  # not know these columns and write NULL when restoring.
  add_col2 <- function(table, name, def) {
    cols <- DBI::dbGetQuery(con, sprintf("PRAGMA table_info(%s)", table))$name
    if (!name %in% cols) DBI::dbExecute(con, sprintf("ALTER TABLE %s ADD COLUMN %s %s", table, name, def))
  }
  add_col2("codes", "anchor", "TEXT DEFAULT ''")
  add_col2("codes", "coding_rule", "TEXT DEFAULT ''")
  add_col2("codings", "paraphrase", "TEXT DEFAULT ''")
  add_col2("codings", "generalization", "TEXT DEFAULT ''")
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      action TEXT NOT NULL,
      details TEXT NOT NULL DEFAULT '{}',
      created_at TEXT NOT NULL
    )")
  # V2: one summary text per (code, source) cell of the Summary Grid
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS summaries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      code_id INTEGER NOT NULL REFERENCES codes(id) ON DELETE CASCADE,
      source_id INTEGER NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
      text_ TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL,
      UNIQUE (code_id, source_id)
    )")
  # V3: stored segments per source (speaker turns, own segments). A source
  # without rows here uses the automatic blank-line segmentation (segments.R).
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS segments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source_id INTEGER NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
      start INTEGER NOT NULL,
      end INTEGER NOT NULL,
      CHECK (start >= 1 AND end >= start)
    )")
  # V6 (0.10.0): cases independent of documents (cases.R). A case is a
  # person, group, organisation ... with its own variables (meta_json). It
  # consists of whole documents (start/end NULL) and/or passages of documents
  # (start/end, e.g. the speaker turns of one person in a group interview).
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS cases (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      description TEXT DEFAULT '',
      meta_json TEXT DEFAULT '{}'
    )")
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS case_members (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      case_id INTEGER NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
      source_id INTEGER NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
      start INTEGER,
      end INTEGER,
      CHECK ((start IS NULL AND end IS NULL) OR (start >= 1 AND end >= start))
    )")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_case_members_case ON case_members(case_id)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_segments_source ON segments(source_id)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_memos_source ON memos(source_id)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_memos_code ON memos(code_id)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_codings_source ON codings(source_id)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_codings_code ON codings(code_id)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_events_action ON events(action)")
  invisible(NULL)
}
