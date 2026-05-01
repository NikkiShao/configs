return {
  {"neovim/nvim-lspconfig"},

  {"hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "L3MON4D3/LuaSnip"
    },
    config = function()
      local cmp = require("cmp")

      cmp.setup({
        sources = {
          { name = "nvim_lsp" }
        },
        mapping = cmp.mapping.preset.insert({
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
      })
    end
  }
}
