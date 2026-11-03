return {
  {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
    keys = {
      {
        "<leader>cD",
        function()
          Snacks.picker.buffers({
            title = "CodeDiff: Tab-select 2 buffers",
            confirm = function(picker)
              local sel = picker:selected({ fallback = true })
              if #sel < 2 then
                Snacks.notify.warn("Select 2 buffers with <Tab> first", { title = "CodeDiff" })
                return
              end
              picker:close()
              local a = vim.fn.fnameescape(sel[1].file)
              local b = vim.fn.fnameescape(sel[2].file)
              vim.schedule(function()
                vim.cmd(("CodeDiff file %s %s"):format(a, b))
              end)
            end,
          })
        end,
        desc = "CodeDiff: diff 2 picked buffers",
      },
    },
    opts = {
      diff = {
        layout = "side-by-side",
        jump_to_first_change = true,
        cycle_next_hunk = true,
      },
    },
  },
}
