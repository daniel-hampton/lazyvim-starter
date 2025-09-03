return {
  {
    "saghen/blink.cmp",
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      sources = {
        default = {
          "lsp",
          "path",
          "snippets",
          -- "buffer",
        },
      },
      completion = {
        trigger = {
          show_on_insert = false,
          -- Don't automatically show completions on every character when typing.
          show_on_keyword = false,
        },
      },
    },
  },
}
