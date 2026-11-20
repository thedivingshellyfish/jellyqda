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
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_codings_source ON codings(source_id)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_codings_code ON codings(code_id)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_events_action ON events(action)")
  invisible(NULL)
}
