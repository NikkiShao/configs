return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        filters = {
          dotfiles = false,
          git_ignored = false,
          custom = { "^.git$" },
        },
      })
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>")
    end,
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup({
        win = {
          border = "rounded",
          title = true,
          title_pos = "center",
        },
      })

      -- Match which-key colors to noice cmdline popup
      vim.api.nvim_set_hl(0, "WhichKeyFloat", { fg = "#89b4fa" })
      vim.api.nvim_set_hl(0, "WhichKeyBorder", { fg = "#89b4fa" })
      vim.api.nvim_set_hl(0, "WhichKey", { fg = "#89b4fa" })
      vim.api.nvim_set_hl(0, "WhichKeyDesc", { fg = "#89b4fa" })
      vim.api.nvim_set_hl(0, "WhichKeyGroup", { fg = "#89b4fa" })
      vim.api.nvim_set_hl(0, "WhichKeySeparator", { fg = "#89b4fa" })
      vim.api.nvim_set_hl(0, "WhichKeyValue", { fg = "#89b4fa" })
      vim.api.nvim_set_hl(0, "WhichKeyNormal", { fg = "#89b4fa" })
      vim.api.nvim_set_hl(0, "WhichKeyTitle", { fg = "#1e1e2e", bg = "#89b4fa", bold = true })
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        preview_config = {
          border = "rounded",
          style = "minimal",
          relative = "cursor",
          row = 1,
          col = 0,
        },
      })
      local normal_bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
      local normal_nc_bg = vim.api.nvim_get_hl(0, { name = "NormalNC" }).bg or normal_bg
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = normal_bg })
      vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#89b4fa", bg = normal_bg })

      vim.api.nvim_create_autocmd("WinLeave", {
        callback = function()
          if vim.api.nvim_win_get_config(0).relative ~= "" then
            vim.api.nvim_set_hl(0, "NormalFloat", { bg = normal_nc_bg })
            vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#89b4fa", bg = normal_nc_bg })
          end
        end,
      })

      vim.api.nvim_create_autocmd("WinEnter", {
        callback = function()
          if vim.api.nvim_win_get_config(0).relative ~= "" then
            vim.api.nvim_set_hl(0, "NormalFloat", { bg = normal_bg })
            vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#89b4fa", bg = normal_bg })
          end
        end,
      })
      vim.keymap.set("n", "<leader>gp", ":Gitsigns preview_hunk<CR>", { desc = "Preview hunk" })
      vim.keymap.set("n", "<leader>gn", ":Gitsigns next_hunk<CR>", { desc = "Next hunk" })
      vim.keymap.set("n", "<leader>gN", ":Gitsigns prev_hunk<CR>", { desc = "Previous hunk" })
      vim.keymap.set("n", "<leader>gb", ":Gitsigns toggle_current_line_blame<CR>", { desc = "Toggle inline blame" })
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        section_separators = { left = "", right = "" },
        component_separators = { left = "|", right = "|" },
      },
    },
  },

  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({
        options = {
          separator_style = "thick",
        },
        highlights = {
          buffer_selected = { fg = "#89b4fa", bold = true },
          separator_selected = { fg = "#89b4fa" },
          indicator_selected = { fg = "#89b4fa" },
        },
      })
      vim.keymap.set("n", "<leader>bn", ":bnext<CR>", { desc = "Next buffer" })
      vim.keymap.set("n", "<leader>bp", ":bprevious<CR>", { desc = "Previous buffer" })
      vim.keymap.set("n", "<leader>bd", ":bdelete<CR>", { desc = "Close buffer" })
    end,
  },

  {
    "sindrets/diffview.nvim",
    config = function()
      require("diffview").setup()
      vim.keymap.set("n", "<leader>dm", ":DiffviewOpen main<CR>", { desc = "Diff vs main" })
      vim.keymap.set("n", "<leader>dc", ":DiffviewClose<CR>", { desc = "Close diff view" })
    end,
  },

  {
    "numToStr/Comment.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },

  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    opts = {},
  },

  {
    "mg979/vim-visual-multi",
    event = "VeryLazy",
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    ft = { "markdown" },
    opts = {},
  },

  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function() vim.fn["mkdp#util#install"]() end,
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_auto_close = 0
    end,
    config = function()
      vim.keymap.set("n", "<leader>mp", "<cmd>MarkdownPreviewToggle<CR>", { desc = "Markdown preview toggle" })
    end,
  },

  {
    "ellisonleao/glow.nvim",
    cmd = "Glow",
    ft = { "markdown" },
    opts = {
      border = "rounded",
      style = "dark",
      pager = true,
      width_ratio = 0.95,
      height_ratio = 0.9,
    },
    config = function(_, opts)
      require("glow").setup(opts)
      vim.keymap.set("n", "<leader>mg", "<cmd>Glow<CR>", { desc = "Glow markdown preview" })

      vim.api.nvim_set_hl(0, "GlowNormal", { bg = "#1e1e2e" })
      vim.api.nvim_set_hl(0, "GlowBorder", { fg = "#89b4fa", bg = "#1e1e2e" })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "glowpreview",
        callback = function()
          vim.opt_local.winhighlight = "Normal:GlowNormal,FloatBorder:GlowBorder"
        end,
      })
    end,
  },

  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    config = function()
      require("noice").setup({
        cmdline = {
          view = "cmdline_popup",
        },
        views = {
          cmdline_popup = {
            position = {
              row = "90%",
              col = "50%",
            },
            size = {
              width = 60,
              height = "auto",
            },
            border = {
              style = "rounded",
            },
          },
        },
        messages = {
          view = "notify",
        },
        lsp = {
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
        },
        presets = {
          command_palette = true,
          long_message_to_split = true,
          lsp_doc_border = true,
        },
      })

      -- Blue text and border for the cmdline popup
      vim.api.nvim_set_hl(0, "NoiceCmdlinePopup", { fg = "#89b4fa" })
      vim.api.nvim_set_hl(0, "NoiceCmdlinePopupBorder", { fg = "#89b4fa" })
      vim.api.nvim_set_hl(0, "NoiceCmdlineIcon", { fg = "#89b4fa" })
    end,
  },

  {
    "folke/todo-comments.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("todo-comments").setup()
      vim.keymap.set("n", "<leader>ft", ":TodoTelescope<CR>", { desc = "Search TODOs" })
    end,
  },

  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("oil").setup({
        view_options = {
          show_hidden = true,
        },
      })
      vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
      vim.keymap.set("n", "<leader>o", function()
        vim.cmd("vsplit | vertical resize 40")
        require("oil").open()
      end, { desc = "Open Oil in side panel" })
    end,
  },

  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local harpoon = require("harpoon")
      harpoon:setup()
      vim.keymap.set("n", "<leader>ha", function() harpoon:list():add() end, { desc = "Harpoon add file" })
      vim.keymap.set("n", "<leader>hh", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon menu" })
      vim.keymap.set("n", "<leader>1", function() harpoon:list():select(1) end, { desc = "Harpoon file 1" })
      vim.keymap.set("n", "<leader>2", function() harpoon:list():select(2) end, { desc = "Harpoon file 2" })
      vim.keymap.set("n", "<leader>3", function() harpoon:list():select(3) end, { desc = "Harpoon file 3" })
      vim.keymap.set("n", "<leader>4", function() harpoon:list():select(4) end, { desc = "Harpoon file 4" })
    end,
  },
}
