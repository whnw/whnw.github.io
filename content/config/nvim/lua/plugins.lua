local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system(
        {
            "git",
            "clone",
            "--filter=blob:none",
            "https://github.com/folke/lazy.nvim.git",
            "--branch=stable", -- latest stable release
            lazypath
        }
    )
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = ";"
vim.cmd([[
let g:airline#extensions#whitespace#enabled = 0
]])

require("lazy").setup(
    {
        {
            "nvim-treesitter/nvim-treesitter",
            build = ":TSUpdate"
        },
        {
            "nvim-telescope/telescope.nvim",
            dependencies = {"nvim-lua/plenary.nvim"}
        },
        {"nvim-telescope/telescope-fzf-native.nvim", build = "make"},
        -- telescope extensions
        {"LinArcX/telescope-env.nvim"},
        {"nvim-telescope/telescope-ui-select.nvim"},
        -- gruvbox
        {"ellisonleao/gruvbox.nvim", priority = 1000, config = true, opts = ...},
        {"tjdevries/colorbuddy.nvim"},
        -- Comment
        {
            "numToStr/Comment.nvim",
            config = function()
                require("Comment").setup()
            end
        },
        -- nvim-autopairs
        {
            "windwp/nvim-autopairs",
            event = "InsertEnter",
            config = true
        },
        {"lewis6991/gitsigns.nvim"},
        {"williamboman/mason.nvim"},
        {"williamboman/mason-lspconfig.nvim"},
        {"neovim/nvim-lspconfig"},
        {"hrsh7th/nvim-cmp"},
        -- Snippet 引擎
        {"hrsh7th/vim-vsnip"},
        -- 补全源
        {"hrsh7th/cmp-vsnip"},
        {"hrsh7th/cmp-nvim-lsp"}, -- { name = nvim_lsp }
        {"hrsh7th/cmp-buffer"}, -- { name = 'buffer' }
        {"hrsh7th/cmp-path"}, -- { name = 'path' }
        {"hrsh7th/cmp-cmdline"}, -- { name = 'cmdline' }
        {"hrsh7th/cmp-nvim-lsp-signature-help"}, -- { name = 'nvim_lsp_signature_help' }
        -- {
        -- 	'nvim-lualine/lualine.nvim',
        -- 	dependencies = { 'nvim-tree/nvim-web-devicons'
        -- },
        {"vim-airline/vim-airline"},
        {"vim-airline/vim-airline-themes"},
        {
            "tummetott/unimpaired.nvim",
            event = "VeryLazy"
        },
        {
            "rmagatti/auto-session",
            config = function()
                require("auto-session").setup {
                    log_level = "error",
                    auto_session_suppress_dirs = {"~/", "~/Projects", "~/Downloads", "/"}
                }
            end
        },
        {
            "christoomey/vim-tmux-navigator",
            cmd = {
                "TmuxNavigateLeft",
                "TmuxNavigateDown",
                "TmuxNavigateUp",
                "TmuxNavigateRight",
                "TmuxNavigatePrevious"
            },
            keys = {
                {"<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>"},
                {"<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>"},
                {"<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>"},
                {"<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>"},
                {"<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>"}
            }
        },
        -- {'akinsho/bufferline.nvim', version = "*", dependencies = 'nvim-tree/nvim-web-devicons'},
        {
            "stevearc/oil.nvim",
            opts = {},
            -- Optional dependencies
            dependencies = {"nvim-tree/nvim-web-devicons"}
        },
        {"kevinhwang91/nvim-bqf", ft = "qf"},
        {
            "dhananjaylatkar/cscope_maps.nvim",
            dependencies = {
                -- "folke/which-key.nvim", -- optional [for whichkey hints]
                "nvim-telescope/telescope.nvim", -- optional [for picker="telescope"]
                "ibhagwan/fzf-lua", -- optional [for picker="fzf-lua"]
                "nvim-tree/nvim-web-devicons" -- optional [for devicons in telescope or fzf]
            },
            opts = {}
        },
        {"yegappan/mru"},
        -- {'ivechan/gtags.vim'},
        -- {'ivechan/telescope-gtags'}
        -- {
        -- 	'rebelot/terminal.nvim',
        -- 	config = function()
        -- 		require("terminal").setup()
        -- 	end
        -- }
        {"akinsho/toggleterm.nvim", version = "*", opts = {}},
        {"saadparwaiz1/cmp_luasnip"},
        {
            "L3MON4D3/LuaSnip",
            -- follow latest release.
            version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
            -- install jsregexp (optional!).
            build = "make install_jsregexp"
        },
        {"mhartington/formatter.nvim"},
        {
            "kiyoon/treesitter-indent-object.nvim",
            keys = {
                {
                    "ai",
                    function() require'treesitter_indent_object.textobj'.select_indent_outer() end,
                    mode = {"x", "o"},
                    desc = "Select context-aware indent (outer)",
                },
                {
                    "aI",
                    function() require'treesitter_indent_object.textobj'.select_indent_outer(true) end,
                    mode = {"x", "o"},
                    desc = "Select context-aware indent (outer, line-wise)",
                },
                {
                    "ii",
                    function() require'treesitter_indent_object.textobj'.select_indent_inner() end,
                    mode = {"x", "o"},
                    desc = "Select context-aware indent (inner, partial range)",
                },
                {
                    "iI",
                    function() require'treesitter_indent_object.textobj'.select_indent_inner(true, 'V') end,
                    mode = {"x", "o"},
                    desc = "Select context-aware indent (inner, entire range) in line-wise visual mode",
                },
            },
        },
        -- {
        --     "lukas-reineke/indent-blankline.nvim",
        --     tag = "v2.20.8",  -- Use v2
        --     event = "BufReadPost",
        --     config = function()
        --         vim.opt.list = true
        --         require("indent_blankline").setup {
        --             space_char_blankline = " ",
        --             show_current_context = true,
        --             show_current_context_start = true,
        --         }
        --     end,
        -- },
        {
            "nvim-tree/nvim-tree.lua",
            version = "*",
            lazy = false,
            dependencies = {
                "nvim-tree/nvim-web-devicons",
            },
            config = function()
                require("nvim-tree").setup {}
            end,
        },
    }
)

-- Utilities for creating configurations
local util = require "formatter.util"

-- Provides the Format, FormatWrite, FormatLock, and FormatWriteLock commands
require("formatter").setup {
    -- Enable or disable logging
    logging = true,
    -- Set the log level
    log_level = vim.log.levels.WARN,
    -- All formatter configurations are opt-in
    -- filetype = {
    -- Formatter configurations for filetype "lua" go here
    -- and will be executed in order
    -- },

    -- Use the special "*" filetype for defining formatter configurations on
    -- any filetype
    ["*"] = {
        -- "formatter.filetypes.any" defines default configurations for any
        -- filetype
        require("formatter.filetypes.any").remove_trailing_whitespace
        -- Remove trailing whitespace without 'sed'
        -- require("formatter.filetypes.any").substitute_trailing_whitespace,
    }
}
