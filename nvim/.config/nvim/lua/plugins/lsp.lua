-- Disable LazyVim codelens keymaps to free <leader>cc for other uses.
return {
  {
    "stevearc/conform.nvim",
    -- In visual mode, format the selection via the LSP (html supports
    -- rangeFormatting); prettier can't range-format. Normal-mode/save
    -- formatting still uses prettier as usual.
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ lsp_format = "prefer", async = true })
        end,
        mode = "v",
        desc = "Format Selection (LSP)",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      codelens = {
        enabled = false,
      },
      servers = {
        html = {},
        ["*"] = {
          keys = {
            { "<leader>cc", false },
            { "<leader>cC", false },
          },
        },
      },
    },
  },
}
