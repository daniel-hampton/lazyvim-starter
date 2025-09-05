-- Just enables gruvbox theme.
return {
  -- add gruvbox
  {
    "ellisonleao/gruvbox.nvim",
    ---@module 'gruvbox'
    ---@type GruvboxConfig
    opts = {
      italic = {
        strings = false,
        emphasis = true,
        comments = true,
        operators = false,
        folds = true,
      },
      contrast = "hard",
      -- transparent_mode = true,
      overrides = {
        -- ["@comment"] = { fg = "#387258" },
        -- ["@string"] = { fg = "#6A8759" },
        -- ["@string"] = { fg = "#b8bb26" },
      },
      palette_overrides = {
        -- bright_green = "#6aaa59",
        -- bright_yellow = "#6aaa59",
        -- bright_green = "#6aaa59",
        -- bright_green = "#fabd2f",
        -- bright_yellow = "#b8bb26",
      },
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

      -- Changing the color for Comments
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
      colorscheme = "gruvbox",
    },
  },
}
