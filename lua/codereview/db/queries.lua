local db = require("codereview.db")

local M = {}

local function now()
  return os.time()
end

local function q(v)
  if v == nil or v == vim.NIL then
    return "NULL"
  end
  if type(v) == "number" then
    return tostring(v)
  end
  return "'" .. tostring(v):gsub("'", "''") .. "'"
end

local function set_clause(fields, touch_updated_at)
  local parts = {}
  if touch_updated_at then
    fields.updated_at = fields.updated_at or now()
  end
  for k, v in pairs(fields) do
    table.insert(parts, k .. " = " .. q(v))
  end
  table.sort(parts)
  return table.concat(parts, ", ")
end

local function clone(row)
  return vim.deepcopy(row)
end

local function normalize(row)
  if not row then return nil end
  for k, v in pairs(row) do
    if v == vim.NIL then
      row[k] = nil
    end
  end
  return row
end

local function normalize_rows(rows)
  for _, row in ipairs(rows or {}) do
    normalize(row)
  end
  return rows
end

local function json_insert(tbl, data)
  local store = db.json()
  store.seq[tbl] = (store.seq[tbl] or 0) + 1
  data.id = store.seq[tbl]
  normalize(data)
  table.insert(store[tbl], data)
  db.save_json()
  return clone(data)
end

local function json_find(tbl, pred)
  for _, row in ipairs(db.json()[tbl]) do
    if pred(row) then
      return row
    end
  end
end

local function json_filter(tbl, pred)
  local rows = {}
  for _, row in ipairs(db.json()[tbl]) do
    if pred(row) then
      table.insert(rows, clone(row))
    end
  end
  return rows
end

function M.create_session(data)
  data.created_at = data.created_at or now()
  data.updated_at = data.updated_at or data.created_at
  data.status = data.status or "active"
  data.current_file_index = data.current_file_index or 1
  if db.driver() == "json" then
    return json_insert("sessions", data)
  end
  local sql = string.format(
    "INSERT INTO sessions(name,source_type,source_spec,repo_dir,base_ref,target_ref,status,current_file_index,created_at,updated_at) VALUES(%s,%s,%s,%s,%s,%s,%s,%d,%d,%d); SELECT * FROM sessions WHERE id = last_insert_rowid();",
    q(data.name), q(data.source_type), q(data.source_spec), q(data.repo_dir), q(data.base_ref), q(data.target_ref), q(data.status), data.current_file_index, data.created_at, data.updated_at
  )
  return normalize(db.query(sql)[1])
end

function M.get_session(id)
  if db.driver() == "json" then
    local row = json_find("sessions", function(s) return s.id == tonumber(id) end)
    return row and clone(row) or nil
  end
  return normalize(db.query("SELECT * FROM sessions WHERE id = " .. q(tonumber(id)))[1])
end

function M.list_sessions(filter)
  filter = filter or {}
  if db.driver() == "json" then
    local rows = json_filter("sessions", function(s)
      return not filter.status or s.status == filter.status
    end)
    table.sort(rows, function(a, b) return a.updated_at > b.updated_at end)
    return rows
  end
  local where = filter.status and (" WHERE status = " .. q(filter.status)) or ""
  return normalize_rows(db.query("SELECT * FROM sessions" .. where .. " ORDER BY updated_at DESC"))
end

function M.find_active_session(match)
  for _, session in ipairs(M.list_sessions({ status = "active" })) do
    local ok = true
    for k, v in pairs(match) do
      if session[k] ~= v then
        ok = false
        break
      end
    end
    if ok then
      return session
    end
  end
  return nil
end

function M.update_session(id, fields)
  if db.driver() == "json" then
    local row = json_find("sessions", function(s) return s.id == tonumber(id) end)
    if row then
      fields.updated_at = fields.updated_at or now()
      for k, v in pairs(fields) do row[k] = v == vim.NIL and nil or v end
      db.save_json()
    end
    return row and clone(row) or nil
  end
  db.query("UPDATE sessions SET " .. set_clause(fields, true) .. " WHERE id = " .. q(tonumber(id)))
  return M.get_session(id)
end

function M.close_session(id)
  return M.update_session(id, { status = "closed", closed_at = now() })
end

function M.add_file(session_id, file_data)
  file_data.session_id = session_id
  file_data.reviewed = file_data.reviewed or 0
  if db.driver() == "json" then
    return json_insert("files", file_data)
  end
  local sql = string.format(
    "INSERT OR REPLACE INTO files(session_id,path,old_path,status,reviewed,sort_order) VALUES(%d,%s,%s,%s,%d,%d); SELECT * FROM files WHERE session_id = %d AND path = %s;",
    session_id, q(file_data.path), q(file_data.old_path), q(file_data.status), file_data.reviewed, file_data.sort_order, session_id, q(file_data.path)
  )
  return normalize(db.query(sql)[1])
end

function M.get_files(session_id)
  if db.driver() == "json" then
    local rows = json_filter("files", function(f) return f.session_id == tonumber(session_id) end)
    table.sort(rows, function(a, b) return a.sort_order < b.sort_order end)
    return rows
  end
  return normalize_rows(db.query("SELECT * FROM files WHERE session_id = " .. q(tonumber(session_id)) .. " ORDER BY sort_order ASC"))
end

function M.update_file(id, fields)
  if db.driver() == "json" then
    local row = json_find("files", function(f) return f.id == tonumber(id) end)
    if row then
      for k, v in pairs(fields) do row[k] = v == vim.NIL and nil or v end
      db.save_json()
    end
    return row and clone(row) or nil
  end
  db.query("UPDATE files SET " .. set_clause(fields, false) .. " WHERE id = " .. q(tonumber(id)))
  return normalize(db.query("SELECT * FROM files WHERE id = " .. q(tonumber(id)))[1])
end

function M.mark_file_reviewed(id, reviewed)
  return M.update_file(id, { reviewed = reviewed and 1 or 0 })
end

function M.create_comment(data)
  data.created_at = data.created_at or now()
  data.updated_at = data.updated_at or data.created_at
  if db.driver() == "json" then
    return json_insert("comments", data)
  end
  local sql = string.format(
    "INSERT INTO comments(session_id,file_path,start_line,end_line,highlighted_text,comment_text,created_at,updated_at,deleted_at) VALUES(%d,%s,%d,%d,%s,%s,%d,%d,%s); SELECT * FROM comments WHERE id = last_insert_rowid();",
    data.session_id, q(data.file_path), data.start_line, data.end_line, q(data.highlighted_text), q(data.comment_text), data.created_at, data.updated_at, q(data.deleted_at)
  )
  return normalize(db.query(sql)[1])
end

function M.get_comment(id)
  if db.driver() == "json" then
    local row = json_find("comments", function(c) return c.id == tonumber(id) end)
    return row and clone(row) or nil
  end
  return normalize(db.query("SELECT * FROM comments WHERE id = " .. q(tonumber(id)))[1])
end

function M.get_comments(session_id, file_path)
  if db.driver() == "json" then
    local rows = json_filter("comments", function(c)
      return c.session_id == tonumber(session_id) and (not file_path or c.file_path == file_path) and c.deleted_at == nil
    end)
    table.sort(rows, function(a, b)
      if a.file_path == b.file_path then return a.start_line < b.start_line end
      return a.file_path < b.file_path
    end)
    return rows
  end
  local where = " WHERE session_id = " .. q(tonumber(session_id)) .. " AND deleted_at IS NULL"
  if file_path then
    where = where .. " AND file_path = " .. q(file_path)
  end
  return normalize_rows(db.query("SELECT * FROM comments" .. where .. " ORDER BY file_path ASC, start_line ASC"))
end

function M.update_comment(id, fields)
  if db.driver() == "json" then
    local row = json_find("comments", function(c) return c.id == tonumber(id) end)
    if row then
      fields.updated_at = fields.updated_at or now()
      for k, v in pairs(fields) do row[k] = v == vim.NIL and nil or v end
      db.save_json()
    end
    return row and clone(row) or nil
  end
  db.query("UPDATE comments SET " .. set_clause(fields, true) .. " WHERE id = " .. q(tonumber(id)))
  return M.get_comment(id)
end

function M.soft_delete_comment(id)
  return M.update_comment(id, { deleted_at = now() })
end

function M.restore_comment(id)
  return M.update_comment(id, { deleted_at = vim.NIL })
end

return M
