" Vim syntax file
" Language:	go
" Filenames:	*.go

" Highlight columns 80 and 120
 let &colorcolumn="80,".join(range(120,999),",")
 highlight ColorColumn ctermbg=235 guibg=#2c2d27
