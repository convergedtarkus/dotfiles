" Enable syntax highlighting
syntax on

" Increase pattern memory limit
" This fixes syntax highlighting for git commits while rebasing
" See https://github.com/vim/vim/issues/2049 for discussion.
set mmp=5000

" Use the monokai colorscheme (https://github.com/crusoexia/vim-monokai)
colorscheme monokai

" Cause new vertical splits to open to the right and horizontal to open below
set splitright
set splitbelow

" Apply the indentation of the current line to the next line added
set autoindent

" Allow loading file based options and mappings for opened files based on filetype plugins.
filetype plugin on

" Use indent rules from filetype plugins.
filetype plugin indent on

" Always show line numbers (git files override line numbers to be off
" because it kills performance)
set number

" Show line numbers releative to current position
:set relativenumber

" Set dart and yaml files to have an indent of 2 spaces
autocmd FileType dart setlocal shiftwidth=2 tabstop=2
autocmd FileType yaml setlocal shiftwidth=2 tabstop=2

" Always show pending command while in normal mode (bottom right)
set showcmd

" Allows backspace to work over text that is not from the current sessions
" https://stackoverflow.com/questions/3534028/mac-terminal-vim-will-only-use-backspace-when-at-the-end-of-a-line 
set backspace=indent,eol,start

" Setup directories for backfiles and swap file
set backupdir=~/.vim/.backup// " put all backup files in the .vim folder
set directory=~/.vim/.swp// " put all swap files in the .vim folder

" Setting for vim-go
let g:go_highlight_functions = 1
let g:go_highlight_function_calls = 1
let g:go_mod_fmt_autosave = 0 " Do not auto-format go.mod files
