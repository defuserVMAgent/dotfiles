return {
  "m00qek/baleia.nvim",
  lazy = true,
  config = function()
    -- async = false so once() finishes before callers lock the buffer (ansi_capture)
    vim.g.baleia = require("baleia").setup({ async = false })
  end,
}
