return {
  "lewis6991/gitsigns.nvim",
  opts = function(_, opts)
    local orig = opts.on_attach
    opts.on_attach = function(buffer)
      if orig then
        orig(buffer)
      end
      vim.keymap.set("n", "<leader>ghd", "<cmd>CodeDiff file HEAD<cr>",
        { buffer = buffer, desc = "CodeDiff vs HEAD" })
      vim.keymap.set("n", "<leader>ghD", "<cmd>CodeDiff file HEAD~1<cr>",
        { buffer = buffer, desc = "CodeDiff vs HEAD~1" })
    end
  end,
}
