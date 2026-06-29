local M = {}

M.statements = {
  [[CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    source_type TEXT NOT NULL,
    source_spec TEXT,
    repo_dir TEXT NOT NULL,
    base_ref TEXT NOT NULL,
    target_ref TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    current_file_index INTEGER DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    closed_at INTEGER
  )]],
  [[CREATE TABLE IF NOT EXISTS files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    path TEXT NOT NULL,
    old_path TEXT,
    status TEXT NOT NULL,
    reviewed INTEGER DEFAULT 0,
    sort_order INTEGER NOT NULL,
    FOREIGN KEY(session_id) REFERENCES sessions(id)
  )]],
  [[CREATE UNIQUE INDEX IF NOT EXISTS files_session_path_idx ON files(session_id, path)]],
  [[CREATE TABLE IF NOT EXISTS comments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    start_line INTEGER NOT NULL,
    end_line INTEGER NOT NULL,
    highlighted_text TEXT,
    comment_text TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    FOREIGN KEY(session_id) REFERENCES sessions(id)
  )]],
  [[CREATE INDEX IF NOT EXISTS comments_session_file_idx ON comments(session_id, file_path)]],
  [[CREATE INDEX IF NOT EXISTS comments_deleted_idx ON comments(deleted_at)]],
}

return M
