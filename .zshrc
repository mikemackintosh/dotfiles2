# Set default lang
export LANGUAGE="en_US.UTF-8"
export LC_ALL=en_US.UTF-8

# Set PATH
export PATH="$HOME/.local/bin:$PATH"

# Set zsh options
setopt HIST_SAVE_BY_COPY
setopt CHASE_LINKS

#
# Setopts
#
# General options
setopt globdots
setopt mark_dirs
setopt list_packed
setopt extended_glob
setopt nullglob
setopt interactive_comments
setopt no_beep
setopt numeric_glob_sort
setopt notify
setopt long_list_jobs

# Changing directories
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus
setopt auto_param_keys
setopt auto_param_slash

# Completion
# auto_menu: second Tab brings up the menu and cycles.
# menu_complete is intentionally NOT set — it would replace the typed
# text with the first match immediately, which clobbers ambiguous
# inputs like `ssh <Tab>` (huge user list as first match).
setopt auto_list
setopt auto_menu
setopt always_to_end
setopt complete_in_word
setopt flow_control

# History
export HISTSIZE=50000
export SAVEHIST=10000
setopt extended_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_ignore_space
setopt inc_append_history
setopt share_history
setopt hist_reduce_blanks
setopt hist_verify
setopt hist_find_no_dups

# Set the editor, default to VIM
# Upgrade to VS Code if it's installed
export EDITOR=vim
if command -v code &>/dev/null; then
  export EDITOR=code
fi

# Set brew env
if [[ -d /opt/homebrew/bin ]]; then
  eval $(/opt/homebrew/bin/brew shellenv)
fi

export GOPATH=$HOME/go

STD_PATH=$PATH
extra_sources=(
    $HOME/bin
    $HOME/.dotfiles/bin
    "${GOPATH}/bin"
    /opt/homebrew/bin/
)
export PATH="${(j.:.)extra_sources}:$STD_PATH"

dot_plugins=(
    "alias"
    "git"
    "go"
    "grep"
    "keybind"
    "private"

    "prompt"
    "fzf-widgets"
)

DOT_ZSH_PLUGIN_DIR="${HOME}/.dotfiles/zsh"
for f in $dot_plugins; do
    # echo "Loading: $i"
    source ${DOT_ZSH_PLUGIN_DIR}/${f}.zsh
done

alias clear="clear && printf '\n%.0s' {1..$LINES} && printf '\033[5 q\r'"

#
# source ~/.zshrc
reload() {
    clear
    source ~/.zshrc
    echo -e "\033[38;5;208mReloaded!\033[0m"
}

# Auto-load completion and tab menu
# Skip the slow security check unless the dump is older than 24h.
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# Move cursor to bottom of screen
printf '\n%.0s' {1..$LINES}

# External tool integrations
# fzf: fuzzy ctrl-R history, ctrl-T file picker, alt-C dir jump
source <(fzf --zsh)

# zoxide: smarter cd — `z <substring>` jumps to a frecent dir
eval "$(zoxide init zsh)"

# direnv: per-directory .envrc autoloading
eval "$(direnv hook zsh)"

# zsh-autosuggestions: fish-style greyed suggestion from history
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Tab: context-sensitive completion.
#
#   1. Mid-word (`cat a<Tab>`, `src/m<Tab>`): always real menu
#      completion. User is refining a specific string.
#   2. Word boundary (trailing space): inspect the buffer. If it
#      mentions any known file-arg command (cat, rm, vim, cd, git
#      add, grep, cp, …), do real filesystem completion. Otherwise
#      (ssh, docker, kubectl, …) accept the zsh-autosuggestions guess
#      if one is shown; fall back to completion if not.
#
# Customise by appending to $_TAB_FILE_CMDS before this widget runs
# (e.g. from a private zsh file).
#
# Explicit autosuggestion-accept keys still work regardless:
#   Right-arrow / Ctrl-E   accept the whole guess
#   Ctrl-F                 accept one word
typeset -ga _TAB_FILE_CMDS=(
    # File ops
    cat less more head tail tac
    rm rmdir cp mv ln mkdir touch
    chmod chown chgrp
    ls ll l la file stat du wc
    # Editors / viewers
    vim nvim vi nano emacs code subl
    bat glow jq yq
    # Archives
    gzip gunzip zip unzip tar
    # Text tools that take files
    diff patch grep rg ag sed awk
    # Navigation / sourcing
    cd pushd popd source .
    # Common subcommands (git, etc.) that take files
    add checkout restore co
)
_tab_smart() {
    # Mid-word — always real completion.
    if [[ ! "$LBUFFER" =~ [[:space:]]$ ]]; then
        zle expand-or-complete
        return
    fi
    # Word boundary — if any token in the buffer is a file-arg
    # command, prefer real filesystem completion over the
    # history-based autosuggestion.
    local w
    for w in ${(z)LBUFFER}; do
        if (( ${_TAB_FILE_CMDS[(Ie)$w]} )); then
            zle expand-or-complete
            return
        fi
    done
    # No file-arg context — accept the autosuggestion if there is one.
    if [[ -n "$POSTDISPLAY" ]]; then
        zle autosuggest-accept
    else
        zle expand-or-complete
    fi
}
zle -N _tab_smart
bindkey '^I' _tab_smart

# zsh-syntax-highlighting: MUST be sourced last (hooks into ZLE)
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
