" Vim script
" Author: Peter Odding <peter@peterodding.com>
" Last Change: July 9, 2011
" URL: http://peterodding.com/code/vim/easytags/

" Public interface through (automatic) commands. {{{1

function! xolox#easytags#register(global) " {{{2
  " Parse the &tags option and get a list of all tags files *including
  " non-existing files* (this is why we can't just call tagfiles()).
  let tagfiles = xolox#misc#option#split_tags(&tags)
  let expanded = map(copy(tagfiles), 'resolve(expand(v:val))')
  " Add the filename to the &tags option when the user hasn't done so already.
  let tagsfile = a:global ? g:easytags_file : xolox#easytags#get_tagsfile()
  if index(expanded, xolox#misc#path#absolute(tagsfile)) == -1
    " This is a real mess because of bugs in Vim?! :let &tags = '...' doesn't
    " work on UNIX and Windows, :set tags=... doesn't work on Windows. What I
    " mean with "doesn't work" is that tagfiles() == [] after the :let/:set
    " command even though the tags file exists! One easy way to confirm that
    " this is a bug in Vim is to type :set tags= then press <Tab> followed by
    " <CR>. Now you entered the exact same value that the code below also did
    " but suddenly Vim sees the tags file and tagfiles() != [] :-S
    call add(tagfiles, tagsfile)
    let value = xolox#misc#option#join_tags(tagfiles)
    let cmd = (a:global ? 'set' : 'setl') . ' tags=' . escape(value, '\ ')
    if xolox#misc#os#is_win() && v:version < 703
      " TODO How to clear the expression from Vim's status line?
      call feedkeys(":" . cmd . "|let &ro=&ro\<CR>", 'n')
    else
      execute cmd
    endif
  endif
endfunction

function! xolox#easytags#autoload() " {{{2
  try
    let do_update = xolox#misc#option#get('easytags_auto_update', 1)
    let do_highlight = xolox#misc#option#get('easytags_auto_highlight', 1) && &eventignore !~? '\<syntax\>'
    " Don't execute this function for unsupported file types (doesn't load
    " the list of file types if updates and highlighting are both disabled).
    if (do_update || do_highlight) && index(xolox#easytags#supported_filetypes(), &ft) >= 0
      " Update entries for current file in tags file?
      if do_update
        let pathname = s:resolve(expand('%:p'))
        if pathname != ''
          let tags_outdated = getftime(pathname) > getftime(xolox#easytags#get_tagsfile())
          if tags_outdated || !xolox#easytags#file_has_tags(pathname)
            call xolox#easytags#update(1, 0, [])
          endif
        endif
      endif
      " Apply highlighting of tags to current buffer?
      if do_highlight
        if !exists('b:easytags_last_highlighted')
          call xolox#easytags#highlight()
        else
          for tagfile in tagfiles()
            if getftime(tagfile) > b:easytags_last_highlighted
              call xolox#easytags#highlight()
              break
            endif
          endfor
        endif
        let b:easytags_last_highlighted = localtime()
      endif
    endif
  catch
    call xolox#misc#msg#warn("easytags.vim %s: %s (at %s)", g:easytags_version, v:exception, v:throwpoint)
  endtry
endfunction

function! xolox#easytags#update(silent, filter_tags, filenames) " {{{2
  try
    let s:cached_filenames = {}
    let have_args = !empty(a:filenames)
    let starttime = xolox#misc#timer#start()
    let cfile = s:check_cfile(a:silent, a:filter_tags, have_args)
    let tagsfile = xolox#easytags#get_tagsfile()
    let firstrun = !filereadable(tagsfile)
    let cmdline = s:prep_cmdline(cfile, tagsfile, firstrun, a:filenames)
    let output = s:run_ctags(starttime, cfile, tagsfile, firstrun, cmdline)
    if !firstrun
      if have_args && !empty(g:easytags_by_filetype)
        " TODO Get the headers from somewhere?!
        call s:save_by_filetype(a:filter_tags, [], output)
      else
        let num_filtered = s:filter_merge_tags(a:filter_tags, tagsfile, output)
      endif
      if cfile != ''
        let msg = "easytags.vim %s: Updated tags for %s in %s."
        call xolox#misc#timer#stop(msg, g:easytags_version, expand('%:p:~'), starttime)
      elseif have_args
        let msg = "easytags.vim %s: Updated tags in %s."
        call xolox#misc#timer#stop(msg, g:easytags_version, starttime)
      else
        let msg = "easytags.vim %s: Filtered %i invalid tags in %s."
        call xolox#misc#timer#stop(msg, g:easytags_version, num_filtered, starttime)
      endif
    endif
    " When :UpdateTags was executed manually we'll refresh the dynamic
    " syntax highlighting so that new tags are immediately visible.
    if !a:silent
      HighlightTags
    endif
    return 1
  catch
    call xolox#misc#msg#warn("easytags.vim %s: %s (at %s)", g:easytags_version, v:exception, v:throwpoint)
  endtry
endfunction

function! s:check_cfile(silent, filter_tags, have_args) " {{{3
  if a:have_args
    return ''
  endif
  let silent = a:silent || a:filter_tags
  if xolox#misc#option#get('easytags_autorecurse', 0)
    let cdir = s:resolve(expand('%:p:h'))
    if !isdirectory(cdir)
      if silent | return '' | endif
      throw "The directory of the current file doesn't exist yet!"
    endif
    return cdir
  endif
  let cfile = s:resolve(expand('%:p'))
  if cfile == '' || !filereadable(cfile)
    if silent | return '' | endif
    throw "You'll need to save your file before using :UpdateTags!"
  elseif g:easytags_ignored_filetypes != '' && &ft =~ g:easytags_ignored_filetypes
    if silent | return '' | endif
    throw "The " . string(&ft) . " file type is explicitly ignored."
  elseif index(xolox#easytags#supported_filetypes(), &ft) == -1
    if silent | return '' | endif
    throw "Exuberant Ctags doesn't support the " . string(&ft) . " file type!"
  endif
  return cfile
endfunction

function! s:prep_cmdline(cfile, tagsfile, firstrun, arguments) " {{{3
  let program = xolox#misc#option#get('easytags_cmd')
  let cmdline = [program, '--fields=+l', '--c-kinds=+p', '--c++-kinds=+p']
  if a:firstrun
    call add(cmdline, shellescape('-f' . a:tagsfile))
    call add(cmdline, '--sort=' . (&ic ? 'foldcase' : 'yes'))
  else
    call add(cmdline, '--sort=no')
    call add(cmdline, '-f-')
  endif
  if xolox#misc#option#get('easytags_include_members', 0)
    call add(cmdline, '--extra=+q')
  endif
  let have_args = 0
  if a:cfile != ''
    if xolox#misc#option#get('easytags_autorecurse', 0)
      call add(cmdline, '-R')
      call add(cmdline, shellescape(a:cfile))
    else
      " TODO Should --language-force distinguish between C and C++?
      " TODO --language-force doesn't make sense for JavaScript tags in HTML files?
      let filetype = xolox#easytags#to_ctags_ft(&filetype)
      call add(cmdline, shellescape('--language-force=' . filetype))
      call add(cmdline, shellescape(a:cfile))
    endif
    let have_args = 1
  else
    for arg in a:arguments
      if arg =~ '^-'
        call add(cmdline, arg)
        let have_args = 1
      else
        let matches = split(expand(arg), "\n")
        if !empty(matches)
          call map(matches, 'shellescape(s:canonicalize(v:val))')
          call extend(cmdline, matches)
          let have_args = 1
        endif
      endif
    endfor
  endif
  " No need to run Exuberant Ctags without any filename arguments!
  return have_args ? join(cmdline) : ''
endfunction

function! s:run_ctags(starttime, cfile, tagsfile, firstrun, cmdline) " {{{3
  let lines = []
  if a:cmdline != ''
    call xolox#misc#msg#debug("easytags.vim %s: Executing %s.", g:easytags_version, a:cmdline)
    try
      let lines = xolox#shell#execute(a:cmdline, 1)
    catch /^Vim\%((\a\+)\)\=:E117/
      " Ignore missing shell.vim plug-in.
      let output = system(a:cmdline)
      if v:shell_error
        let msg = "Failed to update tags file %s: %s!"
        throw printf(msg, fnamemodify(a:tagsfile, ':~'), strtrans(output))
      endif
      let lines = split(output, "\n")
    endtry
    if a:firstrun
      if a:cfile != ''
        call xolox#misc#timer#stop("easytags.vim %s: Created tags for %s in %s.", g:easytags_version, expand('%:p:~'), a:starttime)
      else
        call xolox#misc#timer#stop("easytags.vim %s: Created tags in %s.", g:easytags_version, a:starttime)
      endif
      return []
    endif
  endif
  return xolox#easytags#parse_entries(lines)
endfunction

function! s:filter_merge_tags(filter_tags, tagsfile, output) " {{{3
  let [headers, entries] = xolox#easytags#read_tagsfile(a:tagsfile)
  let filters = []
  " Filter old tags that are to be replaced with the tags in {output}.
  let tagged_files = s:find_tagged_files(a:output)
  if !empty(tagged_files)
    call add(filters, '!has_key(tagged_files, s:canonicalize(v:val[1]))')
  endif
  " Filter tags for non-existing files?
  if a:filter_tags
    call add(filters, 'filereadable(v:val[1])')
  endif
  let num_old_entries = len(entries)
  if !empty(filters)
    " Apply the filters.
    call filter(entries, join(filters, ' && '))
  endif
  let num_filtered = num_old_entries - len(entries)
  " Merge old/new tags and write tags file.
  call extend(entries, a:output)
  if !xolox#easytags#write_tagsfile(a:tagsfile, headers, entries)
    let msg = "Failed to write filtered tags file %s!"
    throw printf(msg, fnamemodify(a:tagsfile, ':~'))
  endif
  " We've already read the tags file, might as well cache the tagged files :-)
  let fname = s:canonicalize(a:tagsfile)
  call s:cache_tagged_files_in(fname, getftime(fname), entries)
  return num_filtered
endfunction

function! s:find_tagged_files(entries) " {{{3
  let tagged_files = {}
  for entry in a:entries
    let filename = s:canonicalize(entry[1])
    if !has_key(tagged_files, filename)
      let tagged_files[filename] = 1
    endif
  endfor
  return tagged_files
endfunction

function! xolox#easytags#highlight() " {{{2
  try
    " Treat C++ and Objective-C as plain C.
    let filetype = get(s:canonical_aliases, &ft, &ft)
    let tagkinds = get(s:tagkinds, filetype, [])
    if exists('g:syntax_on') && !empty(tagkinds) && !exists('b:easytags_nohl')
      let starttime = xolox#misc#timer#start()
      let used_python = 0
      for tagkind in tagkinds
        let hlgroup_tagged = tagkind.hlgroup . 'Tag'
        " Define style on first run, clear highlighting on later runs.
        if !hlexists(hlgroup_tagged)
          execute 'highlight def link' hlgroup_tagged tagkind.hlgroup
        else
          execute 'syntax clear' hlgroup_tagged
        endif
        " Try to perform the highlighting using the fast Python script.
        " TODO The tags files are read multiple times by the Python script
        "      within one run of xolox#easytags#highlight()
        if s:highlight_with_python(hlgroup_tagged, tagkind)
          let used_python = 1
        else
          " Fall back to the slow and naive Vim script implementation.
          if !exists('taglist')
            " Get the list of tags when we need it and remember the results.
            if !has_key(s:aliases, filetype)
              let ctags_filetype = xolox#easytags#to_ctags_ft(filetype)
              let taglist = filter(taglist('.'), "get(v:val, 'language', '') ==? ctags_filetype")
            else
              let aliases = s:aliases[&ft]
              let taglist = filter(taglist('.'), "has_key(aliases, tolower(get(v:val, 'language', '')))")
            endif
          endif
          " Filter a copy of the list of tags to the relevant kinds.
          if has_key(tagkind, 'tagkinds')
            let filter = 'v:val.kind =~ tagkind.tagkinds'
          else
            let filter = tagkind.vim_filter
          endif
          let matches = filter(copy(taglist), filter)
          if matches != []
            " Convert matched tags to :syntax command and execute it.
            call map(matches, 'xolox#misc#escape#pattern(get(v:val, "name"))')
            let pattern = tagkind.pattern_prefix . '\%(' . join(xolox#misc#list#unique(matches), '\|') . '\)' . tagkind.pattern_suffix
            let template = 'syntax match %s /%s/ containedin=ALLBUT,.*String.*,.*Comment.*,cIncluded'
            let command = printf(template, hlgroup_tagged, escape(pattern, '/'))
            try
              execute command
            catch /^Vim\%((\a\+)\)\=:E339/
              let msg = "easytags.vim %s: Failed to highlight %i %s tags because pattern is too big! (%i KB)"
              call xolox#misc#msg#warn(msg, g:easytags_version, len(matches), tagkind.hlgroup, len(pattern) / 1024)
            endtry
          endif
        endif
      endfor
      redraw
      let bufname = expand('%:p:~')
      if bufname == ''
        let bufname = 'unnamed buffer #' . bufnr('%')
      endif
      let msg = "easytags.vim %s: Highlighted tags in %s in %s%s."
      call xolox#misc#timer#stop(msg, g:easytags_version, bufname, starttime, used_python ? " (using Python)" : "")
      return 1
    endif
  catch
    call xolox#misc#msg#warn("easytags.vim %s: %s (at %s)", g:easytags_version, v:exception, v:throwpoint)
  endtry
endfunction

function! xolox#easytags#by_filetype(undo) " {{{2
  try
    if empty(g:easytags_by_filetype)
      throw "Please set g:easytags_by_filetype before running :TagsByFileType!"
    endif
    let s:cached_filenames = {}
    let global_tagsfile = expand(g:easytags_file)
    let disabled_tagsfile = global_tagsfile . '.disabled'
    if !a:undo
      let [headers, entries] = xolox#easytags#read_tagsfile(global_tagsfile)
      call s:save_by_filetype(0, headers, entries)
      call rename(global_tagsfile, disabled_tagsfile)
      let msg = "easytags.vim %s: Finished copying tags from %s to %s! Note that your old tags file has been renamed to %s instead of deleting it, should you want to restore it."
      call xolox#misc#msg#info(msg, g:easytags_version, g:easytags_file, g:easytags_by_filetype, disabled_tagsfile)
    else
      let headers = []
      let all_entries = []
      for tagsfile in split(glob(g:easytags_by_filetype . '/*'), '\n')
        let [headers, entries] = xolox#easytags#read_tagsfile(tagsfile)
        call extend(all_entries, entries)
      endfor
      call xolox#easytags#write_tagsfile(global_tagsfile, headers, all_entries)
      call xolox#misc#msg#info("easytags.vim %s: Finished copying tags from %s to %s!", g:easytags_version, g:easytags_by_filetype, g:easytags_file)
    endif
  catch
    call xolox#misc#msg#warn("easytags.vim %s: %s (at %s)", g:easytags_version, v:exception, v:throwpoint)
  endtry
endfunction

function! s:save_by_filetype(filter_tags, headers, entries)
  let filetypes = {}
  for entry in a:entries
    let ctags_ft = matchstr(entry[2], '\tlanguage:\zs\S\+')
    if !empty(ctags_ft)
      let vim_ft = xolox#easytags#to_vim_ft(ctags_ft)
      if !has_key(filetypes, vim_ft)
        let filetypes[vim_ft] = []
      endif
      call add(filetypes[vim_ft], entry)
    endif
  endfor
  let directory = xolox#misc#path#absolute(g:easytags_by_filetype)
  for vim_ft in keys(filetypes)
    let tagsfile = xolox#misc#path#merge(directory, vim_ft)
    if !filereadable(tagsfile)
      call xolox#easytags#write_tagsfile(tagsfile, a:headers, filetypes[vim_ft])
    else
      call s:filter_merge_tags(a:filter_tags, tagsfile, filetypes[vim_ft])
    endif
  endfor
endfunction

" Public supporting functions (might be useful to others). {{{1

function! xolox#easytags#supported_filetypes() " {{{2
  if !exists('s:supported_filetypes')
    let starttime = xolox#misc#timer#start()
    let command = g:easytags_cmd . ' --list-languages'
    try
      let listing = xolox#shell#execute(command, 1)
    catch /^Vim\%((\a\+)\)\=:E117/
      " Ignore missing shell.vim plug-in.
      let listing = split(system(command), "\n")
      if v:shell_error
        let msg = "Failed to get supported languages! (output: %s)"
        throw printf(msg, strtrans(join(listing, "\n")))
      endif
    endtry
    let s:supported_filetypes = map(copy(listing), 's:check_filetype(listing, v:val)')
    let msg = "easytags.vim %s: Retrieved %i supported languages in %s."
    call xolox#misc#timer#stop(msg, g:easytags_version, len(s:supported_filetypes), starttime)
  endif
  return s:supported_filetypes
endfunction

function! s:check_filetype(listing, cline)
  if a:cline !~ '^\w\S*$'
    let msg = "Failed to get supported languages! (output: %s)"
    throw printf(msg, strtrans(join(a:listing, "\n")))
  endif
  return xolox#easytags#to_vim_ft(a:cline)
endfunction

function! xolox#easytags#read_tagsfile(tagsfile) " {{{2
  " I'm not sure whether this is by design or an implementation detail but
  " it's possible for the "!_TAG_FILE_SORTED" header to appear after one or
  " more tags and Vim will apparently still use the header! For this reason
  " the xolox#easytags#write_tagsfile() function should also recognize it,
  " otherwise Vim might complain with "E432: Tags file not sorted".
  let headers = []
  let entries = []
  let num_invalid = 0
  for line in readfile(a:tagsfile)
    if line =~# '^!_TAG_'
      call add(headers, line)
    else
      let entry = xolox#easytags#parse_entry(line)
      if !empty(entry)
        call add(entries, entry)
      else
        let num_invalid += 1
      endif
    endif
  endfor
  if num_invalid > 0
    call xolox#misc#msg#warn("easytags.vim %s: Ignored %i invalid line(s) in %s!", g:easytags_version, num_invalid, a:tagsfile)
  endif
  return [headers, entries]
endfunction

function! xolox#easytags#parse_entry(line) " {{{2
  let fields = split(a:line, '\t')
  return len(fields) >= 3 ? fields : []
endfunction

function! xolox#easytags#parse_entries(lines) " {{{2
  call map(a:lines, 'xolox#easytags#parse_entry(v:val)')
  return filter(a:lines, '!empty(v:val)')
endfunction

function! xolox#easytags#write_tagsfile(tagsfile, headers, entries) " {{{2
  " This function always sorts the tags file but understands "foldcase".
  let sort_order = 1
  for line in a:headers
    if match(line, '^!_TAG_FILE_SORTED\t2') == 0
      let sort_order = 2
    endif
  endfor
  call map(a:entries, 's:join_entry(v:val)')
  if sort_order == 1
    call sort(a:entries)
  else
    call sort(a:entries, 1)
  endif
  let lines = []
  if xolox#misc#os#is_win()
    " Exuberant Ctags on Windows requires \r\n but Vim's writefile() doesn't add them!
    for line in a:headers
      call add(lines, line . "\r")
    endfor
    for line in a:entries
      call add(lines, line . "\r")
    endfor
  else
    call extend(lines, a:headers)
    call extend(lines, a:entries)
  endif
  return writefile(lines, a:tagsfile) == 0
endfunction

function! s:join_entry(value)
  return type(a:value) == type([]) ? join(a:value, "\t") : a:value
endfunction

function! xolox#easytags#file_has_tags(filename) " {{{2
  " Check whether the given source file occurs in one of the tags files known
  " to Vim. This function might not always give the right answer because of
  " caching, but for the intended purpose that's no problem: When editing an
  " existing file which has no tags defined the plug-in will run Exuberant
  " Ctags to update the tags, *unless the file has already been tagged*.
  call s:cache_tagged_files()
  return has_key(s:tagged_files, s:resolve(a:filename))
endfunction

if !exists('s:tagged_files')
  let s:tagged_files = {}
  let s:known_tagfiles = {}
endif

function! s:cache_tagged_files() " {{{3
  if empty(s:tagged_files)
    " Initialize the cache of tagged files on first use. After initialization
    " we'll only update the cache when we're reading a tags file from disk for
    " other purposes anyway (so the cache doesn't introduce too much overhead).
    let starttime = xolox#misc#timer#start()
    for tagsfile in tagfiles()
      if !filereadable(tagsfile)
        call xolox#misc#msg#warn("easytags.vim %s: Skipping unreadable tags file %s!", fname)
      else
        let fname = s:canonicalize(tagsfile)
        let ftime = getftime(fname)
        if get(s:known_tagfiles, fname, 0) != ftime
          let [headers, entries] = xolox#easytags#read_tagsfile(fname)
          call s:cache_tagged_files_in(fname, ftime, entries)
        endif
      endif
    endfor
    call xolox#misc#timer#stop("easytags.vim %s: Initialized cache of tagged files in %s.", g:easytags_version, starttime)
  endif
endfunction

function! s:cache_tagged_files_in(fname, ftime, entries) " {{{3
  for entry in a:entries
    let s:tagged_files[s:canonicalize(entry[1])] = 1
  endfor
  let s:known_tagfiles[a:fname] = a:ftime
endfunction

function! xolox#easytags#get_tagsfile() " {{{2
  " Look for a writable project specific tags file?
  if xolox#misc#option#get('easytags_dynamic_files', 0)
    let files = tagfiles()
    if len(files) > 0 && filewritable(files[0]) == 1
      return files[0]
    endif
  endif
  " Default to the global tags file.
  let tagsfile = expand(xolox#misc#option#get('easytags_file'))
  " Check if a file type specific tags file is useful?
  if !empty(g:easytags_by_filetype) && index(xolox#easytags#supported_filetypes(), &ft) >= 0
    let directory = xolox#misc#path#absolute(g:easytags_by_filetype)
    let tagsfile = xolox#misc#path#merge(directory, &filetype)
  endif
  " If the tags file exists, make sure it is writable!
  if filereadable(tagsfile) && filewritable(tagsfile) != 1
    let message = "The tags file %s isn't writable!"
    throw printf(message, fnamemodify(tagsfile, ':~'))
  endif
  return tagsfile
endfunction

" Public API for definition of file type specific dynamic syntax highlighting. {{{1

function! xolox#easytags#define_tagkind(object) " {{{2
  if !has_key(a:object, 'pattern_prefix')
    let a:object.pattern_prefix = '\C\<'
  endif
  if !has_key(a:object, 'pattern_suffix')
    let a:object.pattern_suffix = '\>'
  endif
  if !has_key(s:tagkinds, a:object.filetype)
    let s:tagkinds[a:object.filetype] = []
  endif
  call add(s:tagkinds[a:object.filetype], a:object)
endfunction

function! xolox#easytags#map_filetypes(vim_ft, ctags_ft) " {{{2
  call add(s:vim_filetypes, a:vim_ft)
  call add(s:ctags_filetypes, a:ctags_ft)
endfunction

function! xolox#easytags#alias_filetypes(...) " {{{2
  " TODO Simplify alias handling, this much complexity really isn't needed!
  for type in a:000
    let s:canonical_aliases[type] = a:1
    if !has_key(s:aliases, type)
      let s:aliases[type] = {}
    endif
  endfor
  for i in range(a:0)
    for j in range(a:0)
      let vimft1 = a:000[i]
      let ctagsft1 = xolox#easytags#to_ctags_ft(vimft1)
      let vimft2 = a:000[j]
      let ctagsft2 = xolox#easytags#to_ctags_ft(vimft2)
      if !has_key(s:aliases[vimft1], ctagsft2)
        let s:aliases[vimft1][ctagsft2] = 1
      endif
      if !has_key(s:aliases[vimft2], ctagsft1)
        let s:aliases[vimft2][ctagsft1] = 1
      endif
    endfor
  endfor
endfunction

function! xolox#easytags#to_vim_ft(ctags_ft) " {{{2
  let type = tolower(a:ctags_ft)
  let index = index(s:ctags_filetypes, type)
  return index >= 0 ? s:vim_filetypes[index] : type
endfunction

function! xolox#easytags#to_ctags_ft(vim_ft) " {{{2
  let type = tolower(a:vim_ft)
  let index = index(s:vim_filetypes, type)
  return index >= 0 ? s:ctags_filetypes[index] : type
endfunction

" Miscellaneous script-local functions. {{{1

function! s:resolve(filename) " {{{2
  if xolox#misc#option#get('easytags_resolve_links', 0)
    return resolve(a:filename)
  else
    return a:filename
  endif
endfunction

function! s:canonicalize(filename) " {{{2
  if has_key(s:cached_filenames, a:filename)
    return s:cached_filenames[a:filename]
  endif
    let canonical = s:resolve(fnamemodify(a:filename, ':p'))
    let s:cached_filenames[a:filename] = canonical
    return canonical
  endif
endfunction

let s:cached_filenames = {}

function! s:python_available() " {{{2
  if !exists('s:is_python_available')
    try
      execute 'pyfile' fnameescape(g:easytags_python_script)
      redir => output
        silent python easytags_ping()
      redir END
      let s:is_python_available = (output =~ 'it works!')
    catch
      let s:is_python_available = 0
    endtry
  endif
  return s:is_python_available
endfunction

function! s:highlight_with_python(syntax_group, tagkind) " {{{2
  if xolox#misc#option#get('easytags_python_enabled', 1) && s:python_available()
    " Gather arguments for Python function.
    let context = {}
    let context['tagsfiles'] = tagfiles()
    let context['syntaxgroup'] = a:syntax_group
    let context['filetype'] = xolox#easytags#to_ctags_ft(&ft)
    let context['tagkinds'] = get(a:tagkind, 'tagkinds', '')
    let context['prefix'] = get(a:tagkind, 'pattern_prefix', '')
    let context['suffix'] = get(a:tagkind, 'pattern_suffix', '')
    let context['filters'] = get(a:tagkind, 'python_filter', {})
    " Call the Python function and intercept the output.
    try
      redir => commands
      python import vim
      silent python print easytags_gensyncmd(**vim.eval('context'))
      redir END
      execute commands
      return 1
    catch
      redir END
      " If the Python script raised an error, don't run it again.
      let g:easytags_python_enabled = 0
    endtry
  endif
  return 0
endfunction

" Built-in file type & tag kind definitions. {{{1

" Don't bother redefining everything below when this script is sourced again.
if exists('s:tagkinds')
  finish
endif

let s:tagkinds = {}

" Define the built-in Vim <=> Ctags file-type mappings.
let s:vim_filetypes = []
let s:ctags_filetypes = []
call xolox#easytags#map_filetypes('cpp', 'c++')
call xolox#easytags#map_filetypes('cs', 'c#')
call xolox#easytags#map_filetypes(exists('g:filetype_asp') ? g:filetype_asp : 'aspvbs', 'asp')

" Define the Vim file-types that are aliased by default.
let s:aliases = {}
let s:canonical_aliases = {}
call xolox#easytags#alias_filetypes('c', 'cpp', 'objc', 'objcpp')

" Enable line continuation.
let s:cpo_save = &cpo
set cpo&vim

" Lua. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'lua',
      \ 'hlgroup': 'luaFunc',
      \ 'tagkinds': 'f'})

" C. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'c',
      \ 'hlgroup': 'cType',
      \ 'tagkinds': '[cgstu]'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'c',
      \ 'hlgroup': 'cEnum',
      \ 'tagkinds': 'e'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'c',
      \ 'hlgroup': 'cPreProc',
      \ 'tagkinds': 'd'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'c',
      \ 'hlgroup': 'cFunction',
      \ 'tagkinds': '[fp]'})

highlight def link cEnum Identifier
highlight def link cFunction Function

if xolox#misc#option#get('easytags_include_members', 0)
  call xolox#easytags#define_tagkind({
        \ 'filetype': 'c',
        \ 'hlgroup': 'cMember',
        \ 'tagkinds': 'm'})
 highlight def link cMember Identifier
endif

" PHP. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'php',
      \ 'hlgroup': 'phpFunctions',
      \ 'tagkinds': 'f',
      \ 'pattern_suffix': '(\@='})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'php',
      \ 'hlgroup': 'phpClasses',
      \ 'tagkinds': 'c'})

" Vim script. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'vim',
      \ 'hlgroup': 'vimAutoGroup',
      \ 'tagkinds': 'a'})

highlight def link vimAutoGroup vimAutoEvent

call xolox#easytags#define_tagkind({
      \ 'filetype': 'vim',
      \ 'hlgroup': 'vimCommand',
      \ 'tagkinds': 'c',
      \ 'pattern_prefix': '\(\(^\|\s\):\?\)\@<=',
      \ 'pattern_suffix': '\(!\?\(\s\|$\)\)\@='})

" Exuberant Ctags doesn't mark script local functions in Vim scripts as
" "static". When your tags file contains search patterns this plug-in can use
" those search patterns to check which Vim script functions are defined
" globally and which script local.

call xolox#easytags#define_tagkind({
      \ 'filetype': 'vim',
      \ 'hlgroup': 'vimFuncName',
      \ 'vim_filter': 'v:val.kind ==# "f" && get(v:val, "cmd", "") !~? ''<sid>\w\|\<s:\w''',
      \ 'python_filter': { 'kind': 'f', 'nomatch': '(?i)(<sid>\w|\bs:\w)' },
      \ 'pattern_prefix': '\C\%(\<s:\|<[sS][iI][dD]>\)\@<!\<'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'vim',
      \ 'hlgroup': 'vimScriptFuncName',
      \ 'vim_filter': 'v:val.kind ==# "f" && get(v:val, "cmd", "") =~? ''<sid>\w\|\<s:\w''',
      \ 'python_filter': { 'kind': 'f', 'match': '(?i)(<sid>\w|\bs:\w)' },
      \ 'pattern_prefix': '\C\%(\<s:\|<[sS][iI][dD]>\)'})

highlight def link vimScriptFuncName vimFuncName

" Python. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'python',
      \ 'hlgroup': 'pythonFunction',
      \ 'tagkinds': 'f',
      \ 'pattern_prefix': '\%(\<def\s\+\)\@<!\<'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'python',
      \ 'hlgroup': 'pythonMethod',
      \ 'tagkinds': 'm',
      \ 'pattern_prefix': '\.\@<='})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'python',
      \ 'hlgroup': 'pythonClass',
      \ 'tagkinds': 'c'})

highlight def link pythonMethodTag pythonFunction
highlight def link pythonClassTag pythonFunction

" Java. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'java',
      \ 'hlgroup': 'javaClass',
      \ 'tagkinds': 'c'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'java',
      \ 'hlgroup': 'javaMethod',
      \ 'tagkinds': 'm'})

highlight def link javaClass Identifier
highlight def link javaMethod Function

" C#. {{{2

" TODO C# name spaces, interface names, enumeration member names, structure names?

call xolox#easytags#define_tagkind({
      \ 'filetype': 'cs',
      \ 'hlgroup': 'csClassOrStruct',
      \ 'tagkinds': 'c'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'cs',
      \ 'hlgroup': 'csMethod',
      \ 'tagkinds': '[ms]'})

highlight def link csClassOrStruct Identifier
highlight def link csMethod Function

" Ruby. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'ruby',
      \ 'hlgroup': 'rubyModuleName',
      \ 'tagkinds': 'm'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'ruby',
      \ 'hlgroup': 'rubyClassName',
      \ 'tagkinds': 'c'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'ruby',
      \ 'hlgroup': 'rubyMethodName',
      \ 'tagkinds': '[fF]'})

highlight def link rubyModuleName Type
highlight def link rubyClassName Type
highlight def link rubyMethodName Function

" }}}

" Restore "cpoptions".
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=2 sw=2 et
