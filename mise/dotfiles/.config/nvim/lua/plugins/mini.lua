return {
  {
    "nvim-mini/mini.pairs",
    event = "InsertEnter",
    config = function()
      require("mini.pairs").setup()
      vim.keymap.set("i", "<CR>", function()
        return require("mini.pairs").cr()
      end, { expr = true, replace_keycodes = true })
    end,
  },
  {
    "nvim-mini/mini.surround",
    -- 既定キー sa/sd/sr は維持。ただし InsertEnter だと初回インサート前は未マップで
    -- flash の s が即発火してしまうため、VeryLazy へ変更（Finding 5#6）。
    event = "VeryLazy",
    opts = {},
  },
  {
    "nvim-mini/mini.icons",
    event = "VeryLazy",
    config = function()
      require("mini.icons").setup()
      MiniIcons.mock_nvim_web_devicons()
    end,
  },
  {
    -- treesj の置き換え。キーは <leader>ts を維持。
    "nvim-mini/mini.splitjoin",
    keys = {
      {
        "<leader>ts",
        function()
          require("mini.splitjoin").toggle()
        end,
        desc = "Toggle split/join",
      },
    },
    opts = {
      -- 既定の gS は無効化し、<leader>ts を上のキーマップで明示的に呼ぶ。
      mappings = { toggle = "" },
    },
  },
}
