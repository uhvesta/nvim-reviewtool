local Stack = {}
Stack.__index = Stack

function Stack.new()
  return setmetatable({ undo_stack = {}, redo_stack = {} }, Stack)
end

function Stack:push(action)
  table.insert(self.undo_stack, action)
  self.redo_stack = {}
end

function Stack:undo(apply)
  local action = table.remove(self.undo_stack)
  if not action then return false end
  apply(action, "undo")
  table.insert(self.redo_stack, action)
  return true
end

function Stack:redo(apply)
  local action = table.remove(self.redo_stack)
  if not action then return false end
  apply(action, "redo")
  table.insert(self.undo_stack, action)
  return true
end

function Stack:clear()
  self.undo_stack = {}
  self.redo_stack = {}
end

return Stack
