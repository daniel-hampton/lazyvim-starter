-- Enable LazyVim extras for typescript, eslint, and prettier.
return {
  -- LSPs
  -- { import = "lazyvim.plugins.extras.lang.php" },
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.vue" },
  { import = "lazyvim.plugins.extras.lang.astro" },

  -- Formatting
  { import = "lazyvim.plugins.extras.formatting.prettier" },
  -- Linting
  { import = "lazyvim.plugins.extras.linting.eslint" },

  -- Coding
  { import = "lazyvim.plugins.extras.coding.mini-surround" },

  -- Editor
  { import = "lazyvim.plugins.extras.editor.harpoon2" },
}
