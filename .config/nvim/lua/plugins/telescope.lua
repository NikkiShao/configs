return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        pickers = {
          find_files = {
            hidden = true,
            find_command = { "rg", "--files", "--hidden", "--glob", "!.git/" },
          },
          live_grep = {
            additional_args = { "--hidden", "--glob", "!.git/" },
          },
        },
      })

      local builtin = require("telescope.builtin")

      vim.keymap.set("n", "<leader>ff", builtin.find_files)
      vim.keymap.set("n", "<leader>fg", builtin.live_grep)
      vim.keymap.set("n", "<leader>gs", builtin.git_status)
      vim.keymap.set("n", "<leader>fb", builtin.buffers)
      vim.keymap.set("n", "<leader>gm", function()
        builtin.git_commits({ git_command = { "git", "log", "main..HEAD", "--oneline" } })
      end, { desc = "Commits vs main" })
      vim.keymap.set("n", "<leader>gd", function()
        local files = vim.fn.systemlist("git diff --name-only main")
        if #files == 0 then
          vim.notify("No changes compared to main", vim.log.levels.INFO)
          return
        end
        builtin.find_files({ prompt_title = "Changed files vs main", search_dirs = files })
      end, { desc = "Files changed vs main" })
    end,
  },
}
