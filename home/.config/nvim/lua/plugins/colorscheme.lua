return {
  {
    'Shatur/neovim-ayu',
    lazy = false,
    priority = 1000,
    config = function()
      vim.o.background = 'dark'

      -- Transparent background on macOS, Windows, and WSL so the terminal's
      -- own ayu background shows through, matching Ghostty exactly.
      local transparent = vim.uv.os_uname().sysname == 'Darwin'
        or string.find(vim.uv.os_uname().sysname, 'Windows') ~= nil
        or string.find(vim.uv.os_uname().release, 'WSL') ~= nil

      local colors = require('ayu.colors')
      colors.generate()

      require('ayu').setup({
        overrides = transparent and {
          Normal = { bg = 'None' },
          NormalFloat = { bg = 'None' },
          ColorColumn = { bg = 'None' },
          SignColumn = { bg = 'None' },
          Folded = { bg = 'None' },
          FoldColumn = { bg = 'None' },
          CursorLine = { bg = 'None' },
          CursorColumn = { bg = 'None' },
          VertSplit = { bg = 'None' },
        } or {},
      })

      vim.cmd('colorscheme ayu-dark')

      -- Make the dimmed directory path in the Snacks picker readable
      vim.api.nvim_set_hl(0, 'SnacksPickerDir', { fg = colors.comment })
    end,
  },
}
