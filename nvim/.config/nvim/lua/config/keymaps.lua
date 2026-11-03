-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- YY: yank entire file to system clipboard without moving cursor
vim.keymap.set("n", "YY", function()
  local pos = vim.api.nvim_win_get_cursor(0)
  vim.cmd('%y+')
  vim.api.nvim_win_set_cursor(0, pos)
end, { desc = "Yank entire file to system clipboard" })

-- RR: replace entire file contents with clipboard
vim.keymap.set("n", "RR", function()
  vim.cmd('%d _')
  vim.cmd('put +')
  vim.cmd('1d _')
end, { desc = "Replace entire file with clipboard" })

-- Reload current file treating CR (\r) as the line ending — classic-Mac
-- files that otherwise open as one long line full of ^M (like test.txt).
vim.keymap.set("n", "<leader>fm", "<cmd>edit ++ff=mac<cr>", { desc = "Reload file as mac (CR) line endings" })

-- Claude Code context yanks: paste into a separate Ghostty split running `claude`.
-- The leading `@` makes Claude Code read the reference as file context.
-- Lowercase (yp/yl) = relative to the directory nvim was launched from;
-- uppercase (yP/yL) = absolute path.
local launch_cwd = vim.fn.getcwd()

local function rel_path()
  local abs = vim.fn.expand("%:p")
  if abs:sub(1, #launch_cwd + 1) == launch_cwd .. "/" then
    return abs:sub(#launch_cwd + 2)
  end
  return abs
end

vim.keymap.set("n", "<leader>yp", function()
  vim.fn.setreg("+", "@" .. rel_path())
end, { desc = "Yank @path (relative to launch cwd)" })

vim.keymap.set("n", "<leader>yl", function()
  vim.fn.setreg("+", ("@%s:%d"):format(rel_path(), vim.fn.line(".")))
end, { desc = "Yank @path:line (relative)" })

vim.keymap.set("x", "<leader>yl", function()
  local s, e = vim.fn.line("v"), vim.fn.line(".")
  if s > e then
    s, e = e, s
  end
  vim.fn.setreg("+", ("@%s:%d-%d"):format(rel_path(), s, e))
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end, { desc = "Yank @path:range (relative)" })

vim.keymap.set("n", "<leader>yP", function()
  vim.fn.setreg("+", "@" .. vim.fn.expand("%:p"))
end, { desc = "Yank @path (absolute)" })

vim.keymap.set("n", "<leader>yL", function()
  vim.fn.setreg("+", ("@%s:%d"):format(vim.fn.expand("%:p"), vim.fn.line(".")))
end, { desc = "Yank @path:line (absolute)" })

vim.keymap.set("x", "<leader>yL", function()
  local s, e = vim.fn.line("v"), vim.fn.line(".")
  if s > e then
    s, e = e, s
  end
  vim.fn.setreg("+", ("@%s:%d-%d"):format(vim.fn.expand("%:p"), s, e))
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end, { desc = "Yank @path:range (absolute)" })


-- Markdown: read the table row under the cursor in a wrapped float (lua/table_row.lua).
vim.keymap.set("n", "<leader>mr", function()
  require("table_row").show()
end, { desc = "Show markdown table row" })
