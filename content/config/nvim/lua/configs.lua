require("mason").setup()
require("unimpaired").setup()
-- require('lualine').setup()
require("oil").setup()



local nvim_lsp = require("lspconfig")

nvim_lsp.clangd.setup {
    cmd = {"clangd", "--background-index"},
    init_options = {
        clangdFileStatus = true,
        clangdSemanticHighlighting = true
    },
    filetypes = {"c", "cpp", "cxx", "cc"},
    root_dir = nvim_lsp.util.root_pattern(".git", "compile_commands.json")
}

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
-- vim.api.nvim_create_autocmd(
--     "LspAttach",
--     {
--         group = vim.api.nvim_create_augroup("UserLspConfig", {}),
--         callback = function(ev)
--             -- Enable completion triggered by <c-x><c-o>
--             -- vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
--             -- Buffer local mappings.
--             -- See `:help vim.lsp.*` for documentation on any of the below functions
--             local opts = {buffer = ev.buf}
--             vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
--             vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
--             vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
--             vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
--             -- vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
--             vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
--             -- vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
--             -- vim.keymap.set('n', '<space>wl', function()
--             --   print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
--             -- end, opts)
--             -- vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
--             -- vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
--             -- vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
--             vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
--             -- vim.keymap.set('n', '<space>f', function()
--             --   vim.lsp.buf.format { async = true }
--             -- end, opts)
--         end
--     }
-- )

-- Set up nvim-cmp.
local cmp = require "cmp"

cmp.setup(
    {
        snippet = {
            -- REQUIRED - you must specify a snippet engine
            expand = function(args)
                -- vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
                require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
                -- require('snippy').expand_snippet(args.body) -- For `snippy` users.
                -- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
                -- vim.snippet.expand(args.body) -- For native neovim snippets (Neovim v0.10+)
            end
        },
        window = {},
        mapping = cmp.mapping.preset.insert(
            {
                ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                ["<C-f>"] = cmp.mapping.scroll_docs(4),
                ["<C-Space>"] = cmp.mapping.complete(),
                ["<C-e>"] = cmp.mapping.abort(),
                -- ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
                ["<Tab>"] = cmp.mapping.confirm({select = true}) -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
            }
        ),
        sources = cmp.config.sources(
            {
                {name = "nvim_lsp"},
                -- { name = 'vsnip' }, -- For vsnip users.
                {name = "luasnip"}, -- For luasnip users.
                -- { name = 'ultisnips' }, -- For ultisnips users.
                -- { name = 'snippy' }, -- For snippy users.
                {name = "nvim_lsp_signature_help"}
            },
            {
                {name = "buffer"},
                {name = "path"}
                -- { name = 'cmdline' },
            }
        )
    }
)
 --

-- To use git you need to install the plugin petertriho/cmp-git and uncomment lines below
-- Set configuration for specific filetype.
--[[ cmp.setup.filetype('gitcommit', {
sources = cmp.config.sources({
{ name = 'git' },
}, {
{ name = 'buffer' },
})
})
require("cmp_git").setup() ]] -- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(
    {"/", "?"},
    {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
            {name = "buffer"}
        }
    }
)

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(
    ":",
    {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources(
            {
                {name = "path"}
            },
            {
                {name = "cmdline"}
            }
        ),
        matching = {disallow_symbol_nonprefix_matching = false}
    }
)

-- Set up lspconfig.
-- local capabilities = require('cmp_nvim_lsp').default_capabilities()
-- Replace <YOUR_LSP_SERVER> with each lsp server you've enabled.
-- require('lspconfig')['<YOUR_LSP_SERVER>'].setup {
-- 	capabilities = capabilities
-- }

require("gitsigns").setup {
    signs = {
        add = {text = "┃"},
        change = {text = "┃"},
        delete = {text = "_"},
        topdelete = {text = "‾"},
        changedelete = {text = "~"},
        untracked = {text = "┆"}
    },
    signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
    numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
    linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
    word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
    watch_gitdir = {
        follow_files = true
    },
    auto_attach = true,
    attach_to_untracked = false,
    current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
    current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
        delay = 1000,
        ignore_whitespace = false,
        virt_text_priority = 100
    },
    current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
    -- current_line_blame_formatter_opts = {
    -- relative_time = false,
    -- },
    sign_priority = 6,
    update_debounce = 100,
    status_formatter = nil, -- Use default
    max_file_length = 40000, -- Disable if file is longer than this (in lines)
    preview_config = {
        -- Options passed to nvim_open_win
        border = "single",
        style = "minimal",
        relative = "cursor",
        row = 0,
        col = 1
    },
    on_attach = function(bufnr)
        local gitsigns = require("gitsigns")

        local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map(
            "n",
            "]c",
            function()
                if vim.wo.diff then
                    vim.cmd.normal({"]c", bang = true})
                else
                    gitsigns.nav_hunk("next")
                end
            end
        )

        map(
            "n",
            "[c",
            function()
                if vim.wo.diff then
                    vim.cmd.normal({"[c", bang = true})
                else
                    gitsigns.nav_hunk("prev")
                end
            end
        )

        -- Actions
        map("n", "<leader>hs", gitsigns.stage_hunk)
        map("n", "<leader>hr", gitsigns.reset_hunk)
        map(
            "v",
            "<leader>hs",
            function()
                gitsigns.stage_hunk {vim.fn.line("."), vim.fn.line("v")}
            end
        )
        map(
            "v",
            "<leader>hr",
            function()
                gitsigns.reset_hunk {vim.fn.line("."), vim.fn.line("v")}
            end
        )
        map("n", "<leader>hS", gitsigns.stage_buffer)
        map("n", "<leader>hu", gitsigns.undo_stage_hunk)
        map("n", "<leader>hR", gitsigns.reset_buffer)
        map("n", "<leader>hp", gitsigns.preview_hunk)
        map(
            "n",
            "<leader>hb",
            function()
                gitsigns.blame_line {full = true}
            end
        )
        map("n", "<leader>tb", gitsigns.toggle_current_line_blame)
        map("n", "<leader>hd", gitsigns.diffthis)
        map(
            "n",
            "<leader>hD",
            function()
                gitsigns.diffthis("~")
            end
        )
        map("n", "<leader>td", gitsigns.toggle_deleted)

        -- Text object
        map({"o", "x"}, "ih", ":<C-U>Gitsigns select_hunk<CR>")
    end
}

require("cscope_maps").setup(
    {
        -- maps related defaults
        disable_maps = false, -- "true" disables default keymaps
        skip_input_prompt = true, -- "true" doesn't ask for input
        prefix = "<leader>c", -- prefix to trigger maps
        disable_maps = true,
        -- cscope related defaults
        cscope = {
            -- location of cscope db file
            db_file = "./cscope.out", -- DB or table of DBs
            -- NOTE:
            --   when table of DBs is provided -
            --   first DB is "primary" and others are "secondary"
            --   primary DB is used for build and project_rooter
            --   secondary DBs must be built with absolute paths
            --   or paths relative to cwd. Otherwise JUMP will not work.
            -- cscope executable
            exec = "gtags-cscope", -- "cscope" or "gtags-cscope"
            -- choose your fav picker
            picker = "quickfix", -- "telescope", "fzf-lua" or "quickfix"
            -- size of quickfix window
            qf_window_size = 5, -- any positive integer
            -- position of quickfix window
            qf_window_pos = "bottom", -- "bottom", "right", "left" or "top"
            -- "true" does not open picker for single result, just JUMP
            skip_picker_for_single_result = false, -- "false" or "true"
            -- these args are directly passed to "cscope -f <db_file> <args>"
            db_build_cmd_args = {"-bqkv"},
            -- statusline indicator, default is cscope executable
            statusline_indicator = nil,
            -- try to locate db_file in parent dir(s)
            project_rooter = {
                enable = false, -- "true" or "false"
                -- change cwd to where db_file is located
                change_cwd = false -- "true" or "false"
            }
        }
    }
)

require("luasnip.loaders.from_snipmate").lazy_load()

require "nvim-treesitter.configs".setup {
    -- A list of parser names, or "all" (the listed parsers MUST always be installed)
    ensure_installed = {"c", "lua", "vim", "vimdoc", "markdown", "html", "javascript", "markdown_inline"},
    -- Install parsers synchronously (only applied to `ensure_installed`)
    sync_install = false,
    -- Automatically install missing parsers when entering buffer
    -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
    -- auto_install = true,
    -- List of parsers to ignore installing (or "all")
    ignore_install = {"javascript"},
    ---- If you need to change the installation directory of the parsers (see -> Advanced Setup)
    -- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!
    indent = {
        enable = true;
    },
    -- incremental_selection = {
    --     enable = true,
    --     keymaps = {
    --         init_selection = "sn", -- set to `false` to disable one of the mappings
    --         node_incremental = "sn",
    --         scope_incremental = "ss",
    --         node_decremental = "sd",
    --     },
    -- },

    highlight = {
        enable = true,
        -- NOTE: these are the names of the parsers and not the filetype. (for example if you want to
        -- disable highlighting for the `tex` filetype, you need to include `latex` in this list as this is
        -- the name of the parser)
        -- list of language that will be disabled
        -- disable = {"c", "rust"},
        -- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
        disable = function(lang, buf)
            local max_filesize = 100 * 1024 -- 100 KB
            local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
            if ok and stats and stats.size > max_filesize then
                return true
            end
        end,
        -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
        -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
        -- Using this option may slow down your editor, and you may see some duplicate highlights.
        -- Instead of true it can also be a list of languages
        additional_vim_regex_highlighting = false
    }
}
