" Asciidoc compiler settings for Vim

if exists("b:current_compiler")
  finish
endif
let b:current_compiler = "asciidoc"

if exists(":CompilerSet") != 2
  command! -nargs=* CompilerSet setlocal <args>
endif

" errorformat stolen from syntastic

let &l:errorformat = ''
      \. '%Easciidoc: %tRROR: %f: line %l: %m,'
      \. '%Easciidoc: %tRROR: %f: %m,'
      \. '%Easciidoc: FAILED: %f: line %l: %m,'
      \. '%Easciidoc: FAILED: %f: %m,'
      \. '%Wasciidoc: %tARNING: %f: line %l: %m,'
      \. '%Wasciidoc: %tARNING: %f: %m,'
      \. '%Wasciidoc: DEPRECATED: %f: line %l: %m,'
      \. '%Wasciidoc: DEPRECATED: %f: %m'

function! s:set_makeprg()
  let &l:makeprg = ''
        \. 'asciidoctor'
        \. ' ' . get(b:, 'asciidoctor_arguments', '')
        \. ' %'
endfunction

call s:set_makeprg()
