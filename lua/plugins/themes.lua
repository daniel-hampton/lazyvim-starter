-- Just enables gruvbox theme.
return {
  -- add gruvbox
  { "ellisonleao/gruvbox.nvim" },

  -- add darcula
  {
    "xiantang/darcula-dark.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
  },

  -- Fix for catppuccin integration
  -- [GitHub Issue](https://github.com/LazyVim/LazyVim/issues/6355#issuecomment-3212986215)
  {
    "catppuccin/nvim",
    opts = function(_, opts)
      local module = require("catppuccin.groups.integrations.bufferline")
      if module then
        module.get = module.get_theme
      end

      opts.flavour = "mocha"

      -- Extend previous custom highlights if they exist
      local prev = opts.custom_highlights or function()
        return {}
      end

      opts.custom_highlights = function(colors)
        local hl = prev(colors) or {}
        hl.Comment = { fg = colors.teal }
        return hl
      end

      return opts
    end,
  },

  -- Configure LazyVim to load a default theme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
