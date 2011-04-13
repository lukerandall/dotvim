set hidden       " allow buffers to be hidden when they have unsaved changes
set visualbell   " turn off beeps
set nobackup     " don't need backups with git
set showcmd      " show partial commands
set ttyfast      " speeds up drawing on fast terminals
set ruler        " show cursor position
set gdefault     " make searches global by default
set laststatus=2 " show status bar

call pathogen#runtime_append_all_bundles()

let mapleader = "," " map leader key
" Swap in \ for , as \ is unused since , is my leader
nnoremap \ ,
" E takes you to the end of a word and starts appending
nnoremap E ea

" Remap C-(e|y) so that they scroll by 3 lines
nnoremap <C-e> 3<C-e>
nnoremap <C-y> 3<C-y>

nnoremap <leader>n :execute 'NERDTreeToggle ' . getcwd()<CR>
nnoremap <leader>d :execute 'TlistToggle'<CR>
nnoremap <leader>c :execute 'TlistAddFilesRecursive' . getcwd()<CR>
nnoremap <leader>t :execute 'CommandT'<CR>
nnoremap <leader>f :execute 'CommandTFlush'<CR>
nnoremap <leader>gg :GundoToggle<CR>
nnoremap <leader>gr :GHCReload<CR>
nnoremap <leader>gm :make<CR>
nnoremap <leader>a :Ack<space>
nnoremap <leader>l :Tabularize<space>/
vnoremap <leader>l :Tabularize<space>/
nnoremap <leader>q :q<cr>
nnoremap <silent> <leader><space> :noh<cr>
nnoremap <silent> <leader>y :YRShow<cr>
inoremap <silent> <F3> <ESC>:YRShow<cr>

let Tlist_Ctags_Cmd = '/usr/local/bin/ctags'
let g:easytags_cmd = '/usr/local/bin/ctags'
let g:CommandTMaxHeight=15
let g:yankring_history_file = '.yankring_history'

" Map Ctrl + motion key to change windows
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Allow Cmd-Enter to work like in TextMate
inoremap <D-CR> <ESC>o

" Quickly jump between two most recent buffers
map <Space> <C-^>

" Enable syntastic
let g:syntastic_enable_signs=1
let g:syntastic_quiet_warnings=1

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
set wildignore+=public/images,vendor/rails,dist/build,tmp

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

" Omnicompletion
autocmd FileType ruby,eruby set omnifunc=rubycomplete#Complete
autocmd FileType ruby,eruby let g:rubycomplete_buffer_loading = 1
autocmd FileType ruby,eruby let g:rubycomplete_rails = 1
autocmd FileType ruby,eruby let g:rubycomplete_classes_in_global = 1

autocmd FileType python set omnifunc=pythoncomplete#Complete
autocmd FileType javascript set omnifunc=javascriptcomplete#CompleteJS
autocmd FileType html set omnifunc=htmlcomplete#CompleteTags
autocmd FileType css set omnifunc=csscomplete#CompleteCSS

" Erlang
autocmd FileType erlang set tabstop=4
autocmd FileType erlang set shiftwidth=4
autocmd FileType erlang set expandtab
autocmd FileType erlang set softtabstop=4
let g:erlangHighlightBif = 1

" Haskell
let g:haddock_browser = "open"
let g:haddock_browser_callformat = "%s '%s'"
autocmd FileType haskell set tabstop=4
autocmd FileType haskell set shiftwidth=4
autocmd FileType haskell set expandtab
autocmd FileType haskell set softtabstop=4
autocmd FileType haskell compiler ghc

" Cabal support
function! SetToCabalBuild()
  if glob("*.cabal") != ''
    set makeprg=cabal\ build
  endif
endfunction
autocmd BufEnter *.hs,*.lhs :call SetToCabalBuild()

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

