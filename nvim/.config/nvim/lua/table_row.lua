-- Show the markdown table row under the cursor in a float, one "Header / value"
-- pair per column with long cells wrapped. Mapped in lua/config/keymaps.lua.
local M = {}

local function is_row(line)
  return line:match("^%s*|") ~= nil
end

local function is_separator(line)
  return line:match("^%s*|?[%s:|%-]+$") ~= nil and line:find("%-") ~= nil
end

-- Split a pipe-table row into trimmed cells; `\|` stays inside its cell.
local function split_cells(line)
  local cells, cur, i = {}, {}, 1
  while i <= #line do
    local c = line:sub(i, i)
    if c == "\\" and line:sub(i + 1, i + 1) == "|" then
      table.insert(cur, "|")
      i = i + 2
    else
      if c == "|" then
        table.insert(cells, table.concat(cur))
        cur = {}
      else
        table.insert(cur, c)
      end
      i = i + 1
    end
  end
  table.insert(cells, table.concat(cur))
  -- The leading and trailing pipes leave empty edge cells.
  if cells[1]:match("^%s*$") then
    table.remove(cells, 1)
  end
  if #cells > 0 and cells[#cells]:match("^%s*$") then
    table.remove(cells)
  end
  for k, v in ipairs(cells) do
    cells[k] = vim.trim(v)
  end
  return cells
end

-- Open the float for the row under the cursor, or say why there is none.
function M.show()
  local buf = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if not is_row(lines[lnum] or "") then
    vim.notify("Not on a table row", vim.log.levels.WARN)
    return
  end
  local first = lnum
  while first > 1 and is_row(lines[first - 1]) do
    first = first - 1
  end
  if not is_separator(lines[first + 1] or "") then
    vim.notify("Table has no header separator", vim.log.levels.WARN)
    return
  end
  if lnum <= first + 1 then
    vim.notify("On the header; move to a data row", vim.log.levels.INFO)
    return
  end

  local headers = split_cells(lines[first])
  local cells = split_cells(lines[lnum])
  local out, header_lines = {}, {}
  for k = 1, math.max(#headers, #cells) do
    if k > 1 then
      table.insert(out, "")
    end
    table.insert(out, headers[k] ~= nil and headers[k] ~= "" and headers[k] or ("Column " .. k))
    table.insert(header_lines, #out - 1)
    table.insert(out, cells[k] or "")
  end

  local fbuf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, out)
  vim.bo[fbuf].filetype = "markdown"
  vim.bo[fbuf].modifiable = false
  vim.bo[fbuf].bufhidden = "wipe"
  local ns = vim.api.nvim_create_namespace("table_row")
  for _, l in ipairs(header_lines) do
    vim.api.nvim_buf_set_extmark(fbuf, ns, l, 0, { end_col = #out[l + 1], hl_group = "Title" })
  end

  local width = math.min(100, vim.o.columns - 6)
  local win = vim.api.nvim_open_win(fbuf, true, {
    relative = "editor",
    width = width,
    height = 1,
    row = 2,
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = (" Row %d "):format(lnum - first - 1),
    title_pos = "center",
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  local height = vim.api.nvim_win_text_height(win, {}).all
  vim.api.nvim_win_set_height(win, math.max(1, math.min(height, vim.o.lines - 6)))

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, "<cmd>close<cr>", { buffer = fbuf, nowait = true })
  end
  vim.api.nvim_create_autocmd("WinLeave", { buffer = fbuf, once = true, command = "close" })
end

return M
