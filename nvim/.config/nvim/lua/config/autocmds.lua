-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- When nvim is opened with a directory (e.g. from yazi), cd into it
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local arg = vim.fn.argv(0)
    if arg and arg ~= "" and vim.fn.isdirectory(arg) == 1 then
      vim.cmd.cd(arg)
    end
  end,
})

-- Diagnostics off by default for all files. Toggle per-buffer with <leader>ud.
vim.diagnostic.enable(false)

-- Markdown: keep backticks, link brackets, emphasis markers visible.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown" },
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

-- Markdown inline code: keep String's fg, drop tokyonight's filled background.
-- A plain `link = "String"` gets clobbered when tokyonight re-applies its own
-- definition on FileType, so we set fg+bg explicitly and re-run on both events.
local function tweak_markdown_hl()
  local str = vim.api.nvim_get_hl(0, { name = "String", link = false })
  vim.api.nvim_set_hl(0, "@markup.raw.markdown_inline", { fg = str.fg, bg = "NONE" })
end
vim.api.nvim_create_autocmd({ "ColorScheme", "FileType" }, { callback = tweak_markdown_hl })
tweak_markdown_hl()

-- :SwapNewlines — toggle between an escaped string literal and plain text.
-- Works on the whole file by default, or on a visual selection (linewise).
-- If the text contains any literal "\n", it is decoded: surrounding quotes are
-- stripped, every "\n" becomes a real newline, and every \" becomes a ". Otherwise
-- it is encoded: " becomes \", real newlines become "\n", and the whole thing is
-- wrapped in quotes.
--
--   "something\nsomething(\"here\")"  <->  something
--                                          something("here")
vim.api.nvim_create_user_command("SwapNewlines", function(opts)
  local first = opts.line1 - 1
  local last = opts.line2
  local lines = vim.api.nvim_buf_get_lines(0, first, last, false)
  local text = table.concat(lines, "\n")
  if text:find("\\n", 1, true) then
    -- decode: strip wrapping quotes, then unescape
    text = text:gsub("^%s*\"(.-)\"%s*$", "%1")
    text = text:gsub("\\n", "\n") -- expand literal \n
    text = text:gsub("\\\"", "\"") -- unescape \"
  else
    -- encode: escape, collapse newlines, then wrap in quotes
    text = text:gsub("\"", "\\\"") -- escape "
    text = text:gsub("\n", "\\n") -- collapse real newlines
    text = "\"" .. text .. "\""
  end
  vim.api.nvim_buf_set_lines(0, first, last, false, vim.split(text, "\n", { plain = true }))
end, { range = "%", desc = "Swap escaped string literal and plain text" })

-- :PrettyPrint — format the current buffer with conform/prettier, even for
-- huge/minified files. Snacks tags those as "bigfile", which drops the real
-- filetype and leaves conform with no formatter, so we recover the filetype
-- from the file name first.
vim.api.nvim_create_user_command("PrettyPrint", function()
  if vim.bo.filetype == "bigfile" or vim.bo.filetype == "" then
    local ft = vim.filetype.match({ filename = vim.api.nvim_buf_get_name(0) })
    if ft then
      vim.bo.filetype = ft
    end
  end
  require("conform").format({ bufnr = 0, timeout_ms = 30000, lsp_format = "fallback" })
end, { desc = "Pretty-print (format) the current buffer" })
