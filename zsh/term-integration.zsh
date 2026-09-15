# Terminal integration over OSC/DEC escapes: semantic command marks, cwd
# reporting, and atomic repaints. Everything here is non-printing; a terminal
# that doesn't implement a sequence ignores it.
#
#   OSC 133  A/B/C/D  marks where the prompt, the typed command and its output
#            begin and end, plus the exit code. Buys ⌘↑/⌘↓ prompt navigation,
#            "select output of last command", and per-command status marks in
#            iTerm2's scrollbar. Nothing renders these; they are structure.
#   OSC 7    tells the emulator the cwd, so a new tab or split opens here
#            instead of ~.
#   DEC 2026 brackets a repaint so the terminal presents it as one frame.
#
# zsh/zupershell.zsh emits its own 133/7 when TERM_PROGRAM=zupershell; bail
# rather than double-marking every command.

[[ -o interactive ]] || return 0
[[ $TERM_PROGRAM == zupershell ]] && return 0

autoload -Uz add-zsh-hook

# A = prompt start, B = end of prompt / start of what the user types. Both
# live INSIDE $PROMPT, so they must be wrapped in %{ %}: zsh counts every
# byte of the prompt toward the cursor column unless told the span is
# zero-width, and a miscount corrupts line editing as soon as a command
# wraps.
typeset -g _ZT_A=$'%{\e]133;A\a%}'
typeset -g _ZT_B=$'%{\e]133;B\a%}'

# C = the command's output starts here. Emitted after you hit enter, so it
# is NOT part of the prompt and needs no %{ %}.
_zt_preexec() { print -n -- $'\e]133;C\a' }

# D = the previous command ended, with its status. Called from the prompt's
# own precmd rather than registered as a hook of its own: zsh gives the first
# precmd hook the real $?, and every later one sees the status of the hook
# before it. Emitting D from a second hook would report 0 for everything.
_zt_mark_d() { print -n -- $'\e]133;D;'"${1:-0}"$'\a' }

# Percent-encode everything outside the unreserved set. file:// URLs with a
# raw space or '#' are parsed wrong by some emulators.
_zt_urlencode() {
    local s=$1 out='' i c
    for (( i = 1; i <= ${#s}; i++ )); do
        c=$s[i]
        case $c in
            ([A-Za-z0-9/._~-]) out+=$c ;;
            (*) out+=$(printf '%%%02X' "'$c") ;;
        esac
    done
    print -r -- $out
}

_zt_osc7() { print -n -- $'\e]7;file://'"${HOST}$(_zt_urlencode $PWD)"$'\a' }

# DEC 2026. Emitted blind on purpose: an unsupported private mode is ignored,
# and the alternative — DECRQM (\e[?2026$p) plus a read with a timeout — puts
# up to 100ms of latency into every shell start to learn something that costs
# 8 bytes to assume. Set ZT_SYNC=0 before sourcing to opt out.
typeset -g _ZT_SYNC=${ZT_SYNC:-1}
_zt_sync_begin() { (( _ZT_SYNC )) && print -n -- $'\e[?2026h' }
_zt_sync_end()   { (( _ZT_SYNC )) && print -n -- $'\e[?2026l' }

add-zsh-hook preexec _zt_preexec
add-zsh-hook chpwd   _zt_osc7
_zt_osc7        # report the directory this shell started in

# iTerm2 speaks OSC 133, but gates several menu items — Command History,
# Recent Directories, Select Output of Last Command — on having seen its own
# OSC 1337 announcement first. Without it the marks are drawn and the menu
# entries stay greyed out, which looks like the marks aren't working.
# This is what iTerm's own iterm2_shell_integration.zsh sends; we send the
# same handshake without installing that script (it would double-mark).
if [[ $TERM_PROGRAM == iTerm.app ]]; then
    export ITERM_SHELL_INTEGRATION_INSTALLED=Yes

    _zt_iterm_announce() {
        print -n -- $'\e]1337;ShellIntegrationVersion=5;shell=zsh\a'
    }

    # iTerm's own dialect for host and directory. RemoteHost is what lets it
    # tell a local path from one on the far side of an ssh session, so
    # "open in new split here" does the right thing after you disconnect.
    _zt_iterm_host_dir() {
        print -n -- $'\e]1337;RemoteHost='"${USER}@${HOST}"$'\a'
        print -n -- $'\e]1337;CurrentDir='"${PWD}"$'\a'
    }

    add-zsh-hook precmd _zt_iterm_host_dir
    _zt_iterm_announce
    _zt_iterm_host_dir
fi
