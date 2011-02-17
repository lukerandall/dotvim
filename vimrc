set hidden       " allow buffers to be hidden when they have unsaved changes
set visualbell   " turn off beeps
set nobackup     " don't need backups with git
set showcmd      " show partial commands
set ttyfast      " speeds up drawing on fast terminals
set ruler        " show cursor position
set gdefault     " make searches global by default
set laststatus=2 " show status bar
set cursorline   " highlight line cursor is on

call pathogen#runtime_append_all_bundles()

let mapleader = "," " map leader key
"imap hh <Esc>

" Remap C-(e|y) so that they scroll by 3 lines
nnoremap <C-e> 3<C-e>
nnoremap <C-y> 3<C-y>

map <leader>n :execute 'NERDTreeToggle ' . getcwd()<CR>
map <leader>d :execute 'TlistToggle'<CR>
map <leader>c :execute 'TlistAddFilesRecursive' . getcwd()<CR>
map <leader>t :execute 'CommandT'<CR>
map <leader>f :execute 'CommandTFlush'<CR>
let Tlist_Ctags_Cmd = '/usr/local/bin/ctags'
let g:easytags_cmd = '/usr/local/bin/ctags'
let g:CommandTMaxHeight=15
let g:yankring_history_file = '.yankring_history'
nnoremap <leader>a :Ack<space>
nnoremap <leader>l :Tabularize<space>/
vnoremap <leader>l :Tabularize<space>/
nnoremap <silent> <leader><space> :noh<CR>
nnoremap <silent> <leader>y :YRShow<cr>
inoremap <silent> <F3> <ESC>:YRShow<cr>

" Map Ctrl + motion key to change windows
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
inoremap <D-CR> <ESC>o

" Map Shift + motion key to change tabs
set wildignore+=public/images,vendor/rails

" Quickly jump between two most recent buffers
map <Space> <C-^>

" Easier moving between wrapped lines
nmap <silent> j gj
nmap <silent> k gk

" leader + v to open new vertical split, leader + s to open a horizontal split, leader + o to close all other windows
map <leader>v <C-w>v<C-w>l
map <leader>h <C-w>s<C-w>j
map <leader>o <C-w>o

" leader + w to save buffer
map <leader>s :w<CR>

set directory=/tmp/ " save temp files in /tmp
set history=1000    " keep n items in history

set wildmenu                  " enable menu for commands
set wildmode=list:longest     " list options when hitting tab, and match longest common command
set wildignore=*.log,*.swp,*~ " ignore these files when completing
set wildignore+=public/images,vendor/rails

set backspace=indent,eol,start " allow backspacing over autoindent, eols and start of insert

colorscheme molokai

syntax on                 " enable syntax highlighting
filetype plugin on        " enable filetype detection and plugins
filetype plugin indent on " indent according to file type

set number     " line numbers
set hlsearch   " highlight matches
set incsearch  " incremental search
set ignorecase " ignore case when searching
set smartcase  " unless search terms are upper case

set expandtab     " replace tabs with spaces
set softtabstop=2 " use 2 spaces
set shiftwidth=2  " used by indentation commands
set autoindent    " copy previous line indentation

set grepprg=ack\ -a " use ack for grepping

nmap <silent> <leader>s :set nolist!<CR>
set listchars=trail:·,precedes:<,extends:>

set shortmess+=filmnrxoOtT " Shorten file messages

runtime macros/matchit.vim " Enable matching with %

" duplicate selection in visual mode
vmap D y'>p

set title       " display title
set scrolloff=3 " keep n lines of offset when scrolling

if has("gui_macvim")
    set fuoptions=maxvert,maxhorz " fullscreen options (MacVim only), resized window when changed to fullscreen
    set guifont=Monaco:h10        " use Monaco 10pt
    set guioptions-=T             " remove toolbar
    set guioptions=aAce           " remove scrollbars
    set noanti                    " turn off anti-aliasing
end

" F6 displays the syntax highlighting group of the item under the cursor
map <F6> :echo "hi<" . synIDattr(synID(line("."),col("."),1),"name") . '> trans<'
\ . synIDattr(synID(line("."),col("."),0),"name") . "> lo<"
\ . synIDattr(synIDtrans(synID(line("."),col("."),1)),"name") . ">"<CR>

" Erlang
autocmd FileType erlang set tabstop=4
autocmd FileType erlang set shiftwidth=4
autocmd FileType erlang set expandtab
autocmd FileType erlang set softtabstop=4
let g:erlangHighlightBif = 1

" Haskell
au BufEnter *.hs compiler ghc
let g:haddock_browser = "open"
let g:ghc = "/usr/bin/ghc"

" Strip trailing whitespace
function! <SID>StripTrailingWhitespaces()
    " Preparation: save last search, and cursor position.
    let _s=@/
    let l = line(".")
    let c = col(".")
    " Do the business:
    %s/\s\+$//e
    " Clean up: restore previous search history, and cursor position
    let @/=_s
    call cursor(l, c)
endfunction
autocmd BufWritePre * :call <SID>StripTrailingWhitespaces()

" f5 removes trailing whitespace
nnoremap <silent> <F5> :call <SID>StripTrailingWhitespaces()<CR>

function! Privatize()
    let priorMethod = PriorMethodDefinition()
    exec "normal iprivate :" . priorMethod  . "\<Esc>=="
endfunction

function! PriorMethodDefinition()
    let lineNumber = search('def', 'bn')
    let line       = getline(lineNumber)
    if line == 0
        echo "No prior method definition found"
    endif
    return matchlist(line, 'def \(\w\+\).*')[1]
endfunction

map <Leader>p :call Privatize()<CR>

