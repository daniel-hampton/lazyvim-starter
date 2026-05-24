return {
  {
    "nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      servers = {
        tailwindcss = {
          filetypes_exclude = { "markdown", "php" },
        },
      },
    },
  },
}
