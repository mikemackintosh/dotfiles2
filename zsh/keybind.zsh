# Key bindings (emacs mode)
bindkey -e
bindkey '^R' history-incremental-search-backward
bindkey "^X\x7f" backward-kill-line
bindkey "^U" backward-kill-line
bindkey "^X^_" redo
bindkey "^F" forward-word
bindkey "^B" backward-word
bindkey "^A" beginning-of-line
bindkey "^E" end-of-line

# ^X^E — pop the current command line into $EDITOR for real editing
# (multiline pipes, heredocs, ssh tunnels). Force vim because `code`
# returns immediately and won't block the widget.
autoload -Uz edit-command-line
_edit_command_line_blocking() {
    EDITOR=vim VISUAL=vim zle edit-command-line
}
zle -N _edit_command_line_blocking
bindkey '^X^E' _edit_command_line_blocking