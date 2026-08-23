vim.o.background = "dark" -- or "light" for light mode
vim.cmd([[colorscheme gruvbox]])

local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})
vim.keymap.set("n", "<leader>fr", builtin.resume, {})
vim.keymap.set("n", "<leader>fm", builtin.oldfiles, {})
vim.keymap.set("n", "<leader>fk", builtin.grep_string, {})

vim.o.fileencodings = "ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,gbk"
vim.o.encoding = "utf-8"
vim.o.linespace = 0

vim.keymap.set("i", "<leader>t", '""<esc>i', {noremap = true})
vim.keymap.set("i", "<leader>g", "<cr>{}<esc>i<cr><esc>O", {noremap = true})
vim.keymap.set("i", "<leader>e", "<esc>la", {noremap = true})
vim.keymap.set("i", "<leader>d", ":", {noremap = true})
vim.keymap.set("i", "<leader>v", "<", {noremap = true})
vim.keymap.set("i", "<leader>f", "()<esc>i", {noremap = true})
vim.keymap.set("i", "<leader>a", "+", {noremap = true})
vim.keymap.set("i", "<leader>s", "_", {noremap = true})
vim.keymap.set("i", "<leader>S", "_", {noremap = true})
vim.keymap.set("i", "<leader>b", "->", {noremap = true})
vim.keymap.set("i", "<leader>w", "*", {noremap = true})
vim.keymap.set("i", "<leader>r", "&", {noremap = true})
vim.keymap.set("i", "<leader>q", "!", {noremap = true})
vim.keymap.set("i", "<leader>w", ":w<cr>", {noremap = true})
vim.keymap.set("n", "<leader>w", ":w<cr>", {noremap = true})
vim.keymap.set("n", "<leader>q", ":q<cr>", {noremap = true})
-- vim.keymap.set('n', '<leader>p', ':"+p<cr>', { noremap = true })

-- General Configuration
vim.cmd(
    [[
syntax on
set hls
set number 
set incsearch
set ignorecase smartcase
set enc=utf-8
set mouse=a
set autowriteall
set autoread
set hidden
set scrolloff=3
" set clipboard=unnamedplus
" set clipboard=unnamed
]]
)

vim.api.nvim_create_augroup("CppFormatting", {clear = true})
vim.api.nvim_create_autocmd(
    {"BufNewFile", "BufRead"},
    {
        group = "CppFormatting",
        pattern = "*.c,*.cpp,*.h",
        command = "setlocal formatprg=astyle\\ --indent=tab=4\\ -A1KSM50fpHk3W3j\\ --max-code-length=50"
    }
)
vim.api.nvim_set_keymap("v", "<Leader>fo", '<Cmd>execute "normal! gq"<CR>', {noremap = true, silent = true})
vim.opt.list = true
vim.opt.listchars = {
    tab = "→ ",
    trail = "·",
    lead = "."
}

vim.cmd(
    [[
augroup numbertoggle
autocmd!
autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu && mode() != "i" | set rnu   | endif
autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu                  | set nornu | endif
augroup END
]]
)

vim.cmd(
    [[
if has("autocmd")
    au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif
]]
)

vim.o.backspace = "indent,eol,start"
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4

vim.cmd(
    [[
set nobackup
set noswapfile
set nowritebackup
set noexpandtab

" autocmd InsertLeave * write
autocmd FocusLost * if &mod | write | endif
]]
)

vim.cmd(
    [[
" copy to attached terminal using the yank(1) script:
" https://github.com/sunaku/home/blob/master/bin/yank
function! Yank(text) abort
    let escape = system('yank', a:text)
    if v:shell_error
        echoerr escape
    else
        call writefile([escape], '/proc/self/fd/2', 'b')
    endif
endfunction

noremap <silent> <Leader>y y:<C-U>call Yank(@0)<CR>

" automatically run yank(1) whenever yanking in Vim
" (this snippet was contributed by Larry Sanderson)
function! CopyYank() abort
call Yank(join(v:event.regcontents, "\n"))
endfunction
autocmd TextYankPost * call CopyYank()
]]
)

vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

vim.cmd(
    [[
noremap <leader><space> :cclose<cr>
noremap <F6> :bd<cr>
inoremap <leader>w *
nnoremap <leader>se :SessionSave<cr>
nnoremap <leader>fs :lua require('telescope.builtin').lsp_document_symbols({ symbols='function' })
nnoremap <leader>sf :Cs f g 
nnoremap <space>m :MRU<cr>
nnoremap <S-Left> :bp<cr>
nnoremap <S-Right> :bn<cr>
" nnoremap <C-]> <cmd>lua require('telescope-gtags').showDefinition()<cr>
" nnoremap <leader>cg <cmd>lua require('telescope-gtags').showDefinition()<cr>
" nnoremap <leader>cc <cmd>lua require('telescope-gtags').showReference()<cr>
" nnoremap <leader>n <cmd>lua require('telescope-gtags').showCurrentFileTags()<cr>
tnoremap <esc> <c-\><c-n>
tnoremap <c-[> <c-\><c-n>
nmap gv :vsplit<cr>gd
]]
)

require("toggleterm").setup {}
vim.cmd(
    [[
" set
autocmd TermEnter term://*toggleterm#*
\ tnoremap <silent><c-t> <Cmd>exe v:count1 . "ToggleTerm"<CR>

" By applying the mappings this way you can pass a count to your
" mapping to open a specific window.
" For example: 2<C-t> will open terminal 2
nnoremap <silent><A-j> <Cmd>exe v:count1 . "ToggleTerm"<CR>
tnoremap <silent><A-j> <Cmd>exe v:count1 . "ToggleTerm"<CR>
inoremap <silent><A-j> <Esc><Cmd>exe v:count1 . "ToggleTerm"<CR>
]]
)
function _G.set_terminal_keymaps()
    local opts = {buffer = 0}
    vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
    vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
    vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
    vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
    vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
    vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
end
-- if you only want these mappings for toggle term use term://*toggleterm#* instead
vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")
local Terminal = require("toggleterm.terminal").Terminal
local lazygit =
    Terminal:new(
    {
        cmd = "lazygit",
        dir = "git_dir",
        direction = "float",
        float_opts = {
            border = "double"
        },
        -- function to run on opening the terminal
        on_open = function(term)
            vim.cmd("startinsert!")
            vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", {noremap = true, silent = true})
        end,
        -- function to run on closing the terminal
        on_close = function(term)
            vim.cmd("startinsert!")
        end
    }
)

function _lazygit_toggle()
    lazygit:toggle()
end
vim.api.nvim_set_keymap("n", "<leader>l", "<cmd>lua _lazygit_toggle()<CR>", {noremap = true, silent = true})

vim.opt.termguicolors = true
-- require("bufferline").setup{}

vim.keymap.set("n", "-", "<CMD>Oil<CR>", {desc = "Open parent directory"})

vim.cmd [[
augroup html_settings
autocmd!
autocmd FileType html,lua setlocal expandtab shiftwidth=4 softtabstop=4
augroup END

" nnoremap <silent> <leader>F :Format<CR>

" press <Tab> to expand or jump in a snippet. These can also be mapped separately
" via <Plug>luasnip-expand-snippet and <Plug>luasnip-jump-next.
imap <silent><expr> <Tab> luasnip#expand_or_jumpable() ? '<Plug>luasnip-expand-or-jump' : '<Tab>'
" -1 for jumping backwards.
inoremap <silent> <S-Tab> <cmd>lua require'luasnip'.jump(-1)<Cr>

snoremap <silent> <Tab> <cmd>lua require('luasnip').jump(1)<Cr>
snoremap <silent> <S-Tab> <cmd>lua require('luasnip').jump(-1)<Cr>

" For changing choices in choiceNodes (not strictly necessary for a basic setup).
imap <silent><expr> <C-E> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-E>'
smap <silent><expr> <C-E> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-E>'
]]
