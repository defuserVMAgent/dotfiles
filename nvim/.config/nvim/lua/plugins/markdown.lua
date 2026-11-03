return {
  "MeanderingProgrammer/render-markdown.nvim",
  opts = {
    -- Keep the cursor line rendered in normal mode (tables no longer jump to
    -- raw pipes under the cursor); raw text still shows in insert mode.
    anti_conceal = { disabled_modes = { "n" } },
    -- Neovim's own conceal must also stay active on the cursor line in normal
    -- mode, or the raw pipes/padding still show through.
    win_options = { concealcursor = { rendered = "n" } },
    -- Rows too wide for the window still show raw under the cursor: cell
    -- wrapping replaces the whole source line with virtual lines, and Neovim
    -- never conceals the cursor line. Accepted; `pipe_table = { wrap = false }`
    -- avoids it at the cost of wide tables overflowing the window.
  },
}
