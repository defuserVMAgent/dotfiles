return {
  {
    "docx-edit",
    dir = vim.fn.stdpath("config") .. "/lua/docx",
    name = "docx-edit",
    lazy = false,
    config = function()
      require("docx").setup()
    end,
  },
}
