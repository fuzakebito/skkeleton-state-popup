let s:config = #{labels: {}, opts:{}, popupTimeMs:0}
let s:timer = -1
let s:previous_state = []

function! skkeleton_state_popup#config(config) abort
  let s:config.labels = a:config ->get('labels', s:config.labels)
  let s:config.opts   = a:config ->get('opts', s:config.opts)
  let s:config.popupTimeMs = a:config ->get('popupTimeMs', s:config.popupTimeMs)
endfunction

function! skkeleton_state_popup#run() abort
  let suffix = has('nvim') ? 'nvim' : 'vim'
  let s:create_or_update_popup = function('s:create_or_update_popup_in_' .. suffix)
  let s:close_popup = function('s:close_popup_in_' .. suffix)

  augroup skkeleton-state-popup
    autocmd!
    if has_key(s:config.labels, 'latin')
      autocmd InsertEnter,CursorMovedI <buffer> call s:create_or_update_popup()
    else
      autocmd InsertEnter <buffer> call s:create_or_update_popup()
    endif
    autocmd User skkeleton-handled if mode() =~# '^i' | call s:create_or_update_popup() | endif
    autocmd InsertLeave <buffer> if has_key(s:, 'popup_id') | call s:close_popup() | endif
  augroup END
endfunction

function! s:create_or_update_popup_in_vim() abort
  let label = s:current_label()
  if empty(label)
    if has_key(s:, 'popup_id')
      call s:close_popup_in_vim()
    endif
    return
  endif

  if has_key(s:, 'popup_id')
    call popup_move(s:popup_id, s:config.opts)
    call popup_settext(s:popup_id, label)
  else
    if s:state_changed()
      let s:popup_id = popup_create(label, s:config.opts)
      if s:config.popupTimeMs > 0
        let s:timer = timer_start(s:config.popupTimeMs, {-> s:close_popup_in_vim()})
      endif
    endif
  endif
endfunction

function! s:close_popup_in_vim() abort
  call timer_stop(s:timer)
  call popup_close(remove(s:, 'popup_id'))
endfunction

function! s:create_or_update_popup_in_nvim() abort
  let label = s:current_label()
  if empty(label)
    if has_key(s:, 'popup_id')
      call s:close_popup_in_nvim()
    endif
    return
  endif

  let s:config.opts.height = 1
  let s:config.opts.width = strwidth(label)

  if !has_key(s:, 'buf')
    let s:buf = nvim_create_buf(v:false, v:true)
  endif
  call nvim_buf_set_lines(s:buf, 0, -1, v:true, [label])
  if has_key(s:, 'popup_id')
    call nvim_win_set_config(s:popup_id, s:config.opts)
  else
    if s:state_changed()
      let s:popup_id = nvim_open_win(s:buf, 0, s:config.opts)
      if s:config.popupTimeMs > 0
        let s:timer = timer_start(s:config.popupTimeMs, {-> s:close_popup_in_nvim()})
      endif
    endif
  endif
endfunction

function! s:close_popup_in_nvim() abort
  call timer_stop(s:timer)
  call nvim_win_close(remove(s:, 'popup_id'), v:true)
  if has_key(s:, 'buf')
    execute 'bwipeout! ' .. s:buf
    call remove(s:, 'buf')
  endif
endfunction

function! s:current_label() abort
  let mode = empty(g:skkeleton#mode) ? '' : g:skkeleton#mode
  let phase = g:skkeleton#state ->get('phase', '')

  if phase ==# 'escape' && g:skkeleton#get_config() ->get('keepState', v:false)
      return s:config.labels ->get('input', {}) ->get('hira', '')
  endif
  if empty(mode)
    return s:config.labels ->get('latin', '')
  endif
  return s:config ->get('labels', {}) ->get(phase, {}) ->get(mode, '')
endfunction

function! s:state_changed() abort
  let state = [g:skkeleton#mode, g:skkeleton#state ->get('phase', '')]
  if state != s:previous_state
    let s:previous_state = state
    return v:true
  else
    return v:false
  endif
endfunction
