---@class CodeReviewSession
---@field id number
---@field name string
---@field source_type string
---@field source_spec string|nil
---@field repo_dir string
---@field base_ref string
---@field target_ref string
---@field status string
---@field current_file_index number
---@field created_at number
---@field updated_at number
---@field closed_at number|nil

---@class CodeReviewFile
---@field id number
---@field session_id number
---@field path string
---@field old_path string|nil
---@field status "added"|"modified"|"deleted"|"renamed"
---@field reviewed number
---@field sort_order number
---@field hunks table[]|nil
---@field binary boolean|nil

---@class CodeReviewComment
---@field id number
---@field session_id number
---@field file_path string
---@field start_line number
---@field end_line number
---@field highlighted_text string
---@field comment_text string
---@field created_at number
---@field updated_at number
---@field deleted_at number|nil

return {}
