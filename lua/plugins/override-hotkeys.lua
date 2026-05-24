return {
  -- I'm not certain this are necessary as it was the <A-j> and <A-k>
  -- that were causing the problem when using tmux.
  {
    "nvim-mini/mini.move",
    opts = {
      mappings = {
        -- Move selection in visual mode
        left = "<M-h>",
        right = "<M-l>",
        up = "",
        down = "",

        -- Disabling move current line in normal mode.
        line_left = "",
        line_right = "",
        line_down = "",
        line_up = "",
      },
    },
  },
}
