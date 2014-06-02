" Asciidoc
" Barry Arthur, 2012 05 25

setlocal foldmethod=marker
if &spelllang == ''
  setlocal spelllang=en
endif
setlocal spell
setlocal autoindent expandtab softtabstop=2 shiftwidth=2 textwidth=70 wrap
setlocal comments=://
setlocal commentstring=//\ %s

setlocal formatoptions+=tcroqln2
setlocal indentkeys=!^F,o,O
setlocal nosmartindent nocindent

let &l:makeprg="asciidoc"
      \. ' -a urldata'
      \. ' -a icons'
      \. ' ' . get(b:, 'asciidoc_icons_dir', '-a iconsdir=./images/icons/')
      \. ' ' . get(b:, 'asciidoc_backend', '')
      \. ' %'


" headings
nnoremap <leader>1 YpVr=o<ESC>
nnoremap <leader>2 YpVr-o<ESC>
nnoremap <leader>3 YpVr~o<ESC>
nnoremap <leader>4 YpVr^o<ESC>
nnoremap <leader>5 YpVr+o<ESC>

" allow multi-depth list chars (--, ---, ----, .., ..., ...., etc)
syn match asciidocListBullet /^\s*[-*+]\+\s/
setlocal formatlistpat=^\\s*\\d\\+\\.\\s\\+\\\|^\\s*<\\d\\+>\\s\\+\\\|^\\s*[a-zA-Z.]\\.\\s\\+\\\|^\\s*[ivxIVX]\\+\\.\\s\\+\\\|^\\s*[*.+-]\\+\\s\\+

"Typing "" inserts a pair of quotes (``'') and places the cursor between
"them. Works in both insert and command mode (switching to insert mode):
imap "" ``''<ESC>hi
map "" i""

" Easily reflow text
nnoremap Q gqip

" indent
" ------
setlocal indentexpr=GetAsciidocIndent()

let s:itemization_pattern = '^\s*[-*+]\s'
let s:enumeration_pattern = '^\s*\%(\d\+\|#\)\.\s\+'

" stolen from the RST equivalent
function! GetAsciidocIndent()
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
    return 0
  endif

  let ind = indent(lnum)
  let line = getline(lnum)

  if line =~ s:itemization_pattern
    let ind += 2
  elseif line =~ s:enumeration_pattern
    let ind += matchend(line, s:enumeration_pattern)
  endif

  let line = getline(v:lnum - 1)

  " Indent :FIELD: lines.  Don’t match if there is no text after the field or
  " if the text ends with a sent-ender.
   if line =~ '^:.\+:\s\{-1,\}\S.\+[^.!?:]$'
     return matchend(line, '^:.\{-1,}:\s\+')
   endif

  if line =~ '^\s*$'
    execute lnum
    call search('^\s*\%([-*+]\s\|\%(\d\+\|#\)\.\s\|\.\.\|$\)', 'bW')
    let line = getline('.')
    if line =~ s:itemization_pattern
      let ind -= 2
    elseif line =~ s:enumeration_pattern
      let ind -= matchend(line, s:enumeration_pattern)
    elseif line =~ '^\s*\.\.'
      let ind -= 3
    endif
  endif

  return ind
endfunction


" The following object and its functions is modified from Yukihiro Nakadaira's
" autofmt example.

setlocal formatexpr=AsciidocFormatexpr()

function! AsciidocFormatexpr()
  return s:asciidoc.formatexpr()
endfunction

let s:asciidoc = {}
let s:asciidoc.delimited_block_pattern = '^[-.~_+^=*\/]\{4,}\s*$'
let s:asciidoc.heading_pattern = '^[-=~^+]\{4,}\s*$'
let s:asciidoc.list_pattern = "^\\s*\\d\\+\\.\\s\\+\\\|^\\s*<\\d\\+>\\s\\+\\\|^\\s*[a-zA-Z.]\\.\\s\\+\\\|^\\s*[ivxIVX]\\+\\.\\s\\+\\\|^\\s*[*.+-]\\+\\s\\+"

" TODO: DRY the above line with the formatlistpat option above.

function s:asciidoc.formatexpr()
  if mode() =~# '[iR]' && &formatoptions =~# 'a'
    return 1
  elseif mode() !~# '[niR]' || (mode() =~# '[iR]' && v:count != 1) || v:char =~# '\s'
    echohl ErrorMsg
    echomsg "Assert(formatexpr): Unknown State: " mode() v:lnum v:count string(v:char)
    echohl None
    return 1
  endif
  if mode() == 'n'
    return self.format_normal_mode(v:lnum, v:count - 1)
  else
    return self.format_insert_mode(v:char)
  endif
endfunction

function s:asciidoc.format_normal_mode(lnum, count)
  " echom "normal formatexpr(lnum,count): " . a:lnum . ", " . a:count
  let lnum = a:lnum
  let last_line = lnum + a:count
  let real_last_line = last_line
  if lnum < last_line
    let lnum = self.skip_white_lines(lnum)
    let [lnum, line] = self.skip_fixed_lines(lnum)
    let last_line = self.find_last_line(last_line)
    " echom "normal formatexpr(first,last): " . lnum . ", " . last_line
    if last_line < lnum
      call setpos('.', [0, real_last_line, 0, 0])
      return 0
    endif
  endif

  call self.reformat_text(lnum, last_line)

  call setpos('.', [0, lnum, 0, 0])
  normal! }
  return 0
endfunction

function! s:asciidoc.split_list(list, token)
  let list = a:list
  let lists = []
  let tlist = []
  for l in list
    if l =~ a:token
      call add(lists, tlist)
      let tlist = []
    else
      call add(tlist, l)
    endif
  endfor
  call add(lists, tlist)
  return lists
endfunction

function s:asciidoc.reformat_chunk(chunk, lnum)
  let chunk_len = len(a:chunk)
  " echom 'reformat_chunk: ' . a:lnum . ', ' . chunk_len
  let rtext = Asif(a:chunk, 'asciidoc', ['setlocal indentexpr=', 'setlocal formatexpr=', 'normal! gqap'])
  let rtext_len = len(rtext)
  if rtext_len != chunk_len
    " echom rtext_len . ' != ' . chunk_len
    " echom string(rtext)
    " echom a:lnum . (chunk_len == 1 ? '' : ',+' . (chunk_len - 1)) . 'd'
    exe a:lnum . ',' . (a:lnum + chunk_len - 1) . 'd'
    call append(a:lnum-1, rtext)
  endif
  return rtext_len
endfunction

function s:asciidoc.reformat_text(lnum, last_line)
  " echom 'reformat_text: ' . a:lnum . ', ' . a:last_line
  let lnum = a:lnum
  let lines = getline(lnum, a:last_line)
  " call s:asciidoc.identify_block(lines[0])
  " split block on list joiner ('+') and format
  " each piece separately, rejoining them again afterwards
  for chunk in s:asciidoc.split_list(lines, '^+$')
    let lnum += s:asciidoc.reformat_chunk(chunk, lnum) + 1
  endfor
endfunction

function s:asciidoc.identify_block(line)
  let line = a:line
  if line =~ self.list_pattern
    echom "we have a list"
  elseif line =~ '^\a'
    echom "we have a paragraph"
  elseif line =~ '^\s\+'
    echom "we have a literal paragraph"
  else
    echom "what are you, my pretty?"
  endif
endfunction

function s:asciidoc.get_line(lnum)
  return [a:lnum, getline(a:lnum)]
endfunction

function s:asciidoc.get_next_line(lnum)
  return s:asciidoc.get_line(a:lnum + 1)
endfunction

function s:asciidoc.get_prev_line(lnum)
  return s:asciidoc.get_line(a:lnum - 1)
endfunction

function s:asciidoc.skip_fixed_lines(lnum)
  let [lnum, line] = s:asciidoc.get_line(a:lnum)
  let done = 0

  while done == 0
    let done = 1
    " skip optional block title
    if line =~ '^\.\a'
      let [lnum, line] = self.get_next_line(lnum)
      let done = 0
    endif
    " " skip list joiner
    " if line =~ '^+$'
    "   let [lnum, line] = self.get_next_line(lnum)
    "   let done = 0
    " endif
    " skip optional attribute or blockid
    if line =~ '^\['
      let [lnum, line] = self.get_next_line(lnum)
      let done = 0
    endif
    " skip possible one-line heading
    if line =~ '^=\+'
      let [lnum, line] = self.get_next_line(lnum)
      let done = 0
    endif
    " skip possible table
    if line =~ '^|'
      let [lnum, line] = self.get_next_line(lnum)
      let done = 0
    endif
    " skip possible start of delimited block
    if line =~ self.delimited_block_pattern
      let [lnum, line] = self.get_next_line(lnum)
      let done = 0
    endif
    " skip possible two-line heading
    let [next_lnum, next_line] = self.get_next_line(lnum)
    if (line =~ '^\a') && (next_line =~ self.heading_pattern)
      let [lnum, line] = self.get_next_line(next_lnum)
      let done = 0
    endif

  endwhile
  return [lnum, line]
endfunction

function s:asciidoc.find_last_line(lnum)
  let [lnum, line] = s:asciidoc.get_line(a:lnum)
  let done = 0

  while done == 0
    let done = 1
    " skip possible blank lines
    if line =~ '^\s*$'
      let [lnum, line] = self.get_prev_line(lnum)
      let done = 0
    endif
    " skip possible one-line heading
    if line =~ self.delimited_block_pattern
      let [lnum, line] = self.get_prev_line(lnum)
      let done = 0
    endif
  endwhile
  return lnum
endfunction

function s:asciidoc.format_insert_mode(char)
endfunction

function s:asciidoc.skip_white_lines(lnum)
  let [lnum, line] = s:asciidoc.get_line(a:lnum)
  while line =~ '^\s*$'
    let [lnum, line] = self.get_next_line(lnum)
  endwhile
  return lnum
endfunction

