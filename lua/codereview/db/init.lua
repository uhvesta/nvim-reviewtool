local schema = require("codereview.db.schema")

local M = {}
local state = { driver = nil, path = nil, json = nil }

local function db_path()
  return vim.fn.stdpath("data") .. "/codereview.db"
end

local function sqlite_available()
  return vim.fn.executable("sqlite3") == 1
end

local function run_sql(sql)
  local out = vim.fn.systemlist({ "sqlite3", "-json", state.path, sql })
  if vim.v.shell_error ~= 0 then
    error(table.concat(out, "\n"))
  end
  if #out == 0 or table.concat(out, "") == "" then
    return {}
  end
  local ok, decoded = pcall(vim.json.decode, table.concat(out, "\n"))
  if not ok or decoded == vim.NIL then
    return {}
  end
  return decoded
end

local function json_path()
  return vim.fn.stdpath("data") .. "/codereview.json"
end

local function load_json()
  local path = json_path()
  if vim.fn.filereadable(path) == 0 then
    return { sessions = {}, files = {}, comments = {}, seq = { sessions = 0, files = 0, comments = 0 } }
  end
  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if not ok or type(decoded) ~= "table" then
    return { sessions = {}, files = {}, comments = {}, seq = { sessions = 0, files = 0, comments = 0 } }
  end
  decoded.seq = decoded.seq or { sessions = 0, files = 0, comments = 0 }
  return decoded
end

local function save_json()
  vim.fn.mkdir(vim.fn.fnamemodify(json_path(), ":h"), "p")
  vim.fn.writefile({ vim.json.encode(state.json) }, json_path())
end

function M.open()
  if state.driver then
    return M
  end
  vim.fn.mkdir(vim.fn.stdpath("data"), "p")
  state.path = db_path()
  if sqlite_available() then
    state.driver = "sqlite"
    for _, stmt in ipairs(schema.statements) do
      run_sql(stmt)
    end
    run_sql("PRAGMA busy_timeout = 5000")
  else
    state.driver = "json"
    state.json = load_json()
  end
  return M
end

function M.driver()
  M.open()
  return state.driver
end

function M.path()
  M.open()
  return state.path
end

function M.query(sql)
  M.open()
  if state.driver ~= "sqlite" then
    error("SQL query requested while sqlite3 is unavailable")
  end
  return run_sql(sql)
end

function M.json()
  M.open()
  return state.json
end

function M.save_json()
  if state.driver == "json" then
    save_json()
  end
end

return M
