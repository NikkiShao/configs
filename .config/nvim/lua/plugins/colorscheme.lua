return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("catppuccin")
      -- Clear code block fg so injected language highlights show through
      vim.api.nvim_set_hl(0, "@markup.raw.block.markdown", {})
      -- Brighter visual selection (catppuccin default surface1 is too subtle)
      vim.api.nvim_set_hl(0, "Visual", { bg = "#3b4261" })
    end,
  },
}
