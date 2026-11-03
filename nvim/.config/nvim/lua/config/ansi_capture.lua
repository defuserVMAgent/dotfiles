local M = {}

function M.open(path)
  vim.cmd.edit(path)
  local buf = vim.api.nvim_get_current_buf()

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "ansi"

  if not vim.g.baleia then
    vim.g.baleia = require("baleia").setup({ async = false })
  end
  vim.g.baleia.once(buf)

  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  vim.cmd("normal! G")
end

return M
