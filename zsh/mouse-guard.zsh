# Clear leftover mouse reporting after a remote session dies.
#
# tmux with `mouse on` asks the TERMINAL for mouse events by writing DECSET
# sequences — \e[?1000h (clicks), \e[?1003h (any motion), \e[?1006h (SGR
# coordinates). Over ssh those bytes flip the state of the terminal on THIS
# machine; the remote tmux only borrowed it. A clean detach writes the
# matching resets. A dropped connection ("Connection reset by peer", broken
# pipe) never does, and the terminal keeps reporting: every pointer movement
# then arrives as keystrokes, and ZLE eats the \e[< prefix and types the
# rest — the `35;90;24M` mess on your command line.
#
# So: remember what ran, and if it was something that could have enabled
# mouse reporting on a machine we no longer have a channel to, clear the
# modes when we get back to the prompt. Redundant resets cost 30 bytes and
# terminals ignore them.
#
# Caveat: this also fires if you Ctrl-Z an ssh session. A later `fg` comes
# back with mouse reporting off until the remote app redraws and re-enables
# it (tmux does, on the next refresh).

[[ -o interactive ]] || return 0

autoload -Uz add-zsh-hook

# 1000 clicks · 1002 button-drag · 1003 any-motion · 1005 utf8 coords
# 1006 SGR coords · 1015 urxvt coords. Disable the lot.
typeset -g _ZMG_RESET=$'\e[?1000l\e[?1002l\e[?1003l\e[?1005l\e[?1006l\e[?1015l'
typeset -g _ZMG_PENDING=0

# Commands that hand a remote or containerized program control of this
# terminal. Matched as whole words, not a regex: \b is a GNU extension the
# BSD regex engine on macOS does not implement, so `[[ =~ ^(ssh|...)\b ]]`
# silently matches nothing here.
typeset -ga _ZMG_CMDS=(ssh mosh et autossh tmux docker kubectl claude-attach)
# Wrappers to look past when deciding what actually ran.
typeset -ga _ZMG_SKIP=(sudo command env nohup time doas)

_zmg_preexec() {
    _ZMG_PENDING=0
    local -a words
    words=( ${(z)1} )          # shell-word split, drops leading whitespace
    local w
    for w in $words; do
        w=${w:t}               # /usr/bin/ssh -> ssh
        [[ -n ${_ZMG_SKIP[(r)$w]} ]] && continue
        [[ -n ${_ZMG_CMDS[(r)$w]} ]] && _ZMG_PENDING=1
        break
    done
}
_zmg_precmd() {
    (( _ZMG_PENDING )) || return 0
    _ZMG_PENDING=0
    print -n -- $_ZMG_RESET
}

add-zsh-hook preexec _zmg_preexec
add-zsh-hook precmd  _zmg_precmd

# Manual escape hatch for the cases the hook cannot see — a terminal left
# reporting by something that never went through the shell.
fixterm() {
    print -n -- $_ZMG_RESET
    print -n -- $'\e[?2004h'   # zsh wants bracketed paste back on
    print "mouse reporting cleared"
}
