augroup neoterm_test_tox
    autocmd!
    autocmd VimEnter,BufRead,BufNewFile test_*.py call neoterm#test#libs#add('tox')
aug END
