-- LazyVim uses snacks.picker as the default file picker, not telescope.
-- Show dotfiles (e.g. ~/.claude, ~/.config) in <leader>ff and friends.
return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          files = { hidden = true },
          explorer = { hidden = true },
        },
      },
    },
  },
}
