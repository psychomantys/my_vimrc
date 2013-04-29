runtime bundle/vim-pathogen/autoload/pathogen.vim

execute pathogen#infect()

" Ativa a cor
syntax on

" Desativa o mouse
set mouse=

" Ideal para netbook
set ts=3

" Configurações que somente vão ser executadas no gvim
if has("gui_running")
	" ativa o mouse
	set mouse=a
	" Le focus suit la souris
	set mousef
	" Le bouton droit affiche une popup
	set mousemodel=popup_setpos
	" seta background para dark
	hi	Normal	guifg=White guibg=Black
	set background=dark
else
	" Coisas que s? s?o ativadas em modo texto
	" Spell check
	au! BufNewFile,BufRead * let b:spell_language="br"
	" Set spell check to 'br'
	let spell_language_list="br"
	" Set spell check to key <F7>
	map <F7> :SpellCheck<CR>
	" Set spell check sugesst to key <F8>
	map <F8> :SpellProposeAlternatives<CR>
	" Auto spellcheck for txt doc mail and tmp files
	let spell_auto_type="txt,doc,mail,tmp"
endif

" Diz que o backspace apaga eol e come?os de linha.
set backspace=indent,eol,start

" Seta o tipo de encode do arquivo
set fileencodings=utf-8
set fileencoding=utf-8

" Cofigurações do backup
" Estou usando backup diferencial com um plugin
" Descomente para não ter backup.
"set nobackup
" Seta o diretorio de backup. Isso é para o plugin de backup.
set backupdir=~/.vim/backup//
" ativa o backup
set backup
" Sufixo para o backup do plugin.
set patchmode=.backup
" seta diretorio de backup diferencial para o mesmo
" do backup normal
let savevers_dirs=&backupdir

" A tecla F6 gera um codigo html colorido do arquivo atual.
map <F6> :runtime! syntax/2html.vim<CR>

" Personalização do plugin vcscommand
" Set <F5> to commit
"imap <F5> <LEADER>cc<CR>
"map <F5> <LEADER>cc<CR>

" Cria documenta??o de uma fun??o para o doxygen
imap <F12> <ESC>:Dox<CR>
map  <F12> :Dox<CR>

" Tecla que posta num site o arquivo atual e retorna a url do site
map  <F11> :Gist<CR>

autocmd CursorMovedI * if pumvisible() == 0|pclose|endif
autocmd InsertLeave * if pumvisible() == 0|pclose|endif
set completeopt=longest,menuone 
filetype on
filetype plugin on
filetype indent on
filetype detect

" Configuração de cores dos menu de auto completar.
highlight   Pmenu               ctermfg=White    ctermbg=Black         gui=NONE guifg=White guibg=Gray
highlight   PmenuSel            ctermfg=Black    ctermbg=Gray          gui=NONE guifg=Black guibg=White
highlight   PmenuSbar           ctermfg=Darkred  ctermbg=Darkmagenta   gui=NONE guifg=White guibg=Black
highlight   PmenuThumb          ctermfg=Cyan   	 ctermbg=yellow        gui=NONE guifg=Black guibg=White

let g:gccsenseUseOmniFunc = 1

" GIST plugin: if you want to detect filetype from filename...
let g:gist_detect_filetype = 1

" Autocomplete with tab
let g:SuperTabDefaultCompletionType = "<C-X><C-O>"

" Meu Ommin. Uso o omni apenas para completar :, . e ->
" Deu trabalho, mas copiei tudo para um arquivo.
let g:OmniCpp_MayCompleteDot = 1
let g:OmniCpp_MayCompleteArrow = 1
let g:OmniCpp_MayCompleteScope = 1

"if !exists("local_autocommands_loaded")
"	let local_autocommands_loaded = 1
autocmd FileType c,C,c++,cpp setlocal nu
autocmd FileType c,C,c++,cpp setlocal ts=8
"endif


autocmd CursorMovedI * if pumvisible() == 0|pclose|endif
autocmd InsertLeave * if pumvisible() == 0|pclose|endif
