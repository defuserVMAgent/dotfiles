return {
  { "folke/tokyonight.nvim", opts = { style = "night" } },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    -- LazyVim applies the colorscheme (priority 10000) before this plugin's
    -- config runs, and catppuccin's load() then falls back to an argless
    -- setup() — default palette, color_overrides silently dropped. So: run
    -- during startup (lazy=false), and re-apply after the real setup(opts)
    -- if catppuccin is already active. Both happen pre-render, no flash.
    lazy = false,
    priority = 1000,
    config = function(_, opts)
      require("catppuccin").setup(opts)
      if (vim.g.colors_name or ""):find("catppuccin") then
        vim.cmd.colorscheme(vim.g.colors_name)
      end
    end,
    opts = {
      flavour = "mocha",
      -- Darker background: shift base→mantle→crust one step down so the main
      -- bg is mocha "mantle" (#181825), matching ghostty's background override.
      color_overrides = {
        mocha = {
          base = "#181825",
          mantle = "#11111b",
          crust = "#0b0b12",
        },
      },
    },
  },
  -- Active theme — swap to "catppuccin" for Catppuccin Mocha (spec above is
  -- kept configured and ready)
  { "LazyVim/LazyVim", opts = { colorscheme = "tokyonight" } },
}
