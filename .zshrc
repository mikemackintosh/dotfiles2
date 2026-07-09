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

# Auto-load completion and tab menu. Must run before the plugin loop below —
# `compdef` (used by go.zsh to register `_goto`) doesn't exist until compinit
# defines it, so any plugin calling compdef before this point silently no-ops.
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

dot_plugins=(
    "alias"
    "git"
    "go"
    "grep"
    "keybind"
    "kube"
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

# Move cursor to bottom of screen
printf '\n%.0s' {1..$LINES}

# External tool integrations
# fzf: fuzzy ctrl-R history, ctrl-T file picker, alt-C dir jump
source <(fzf --zsh)

# zoxide: smarter cd — `z <substring>` jumps to a frecent dir
# eval "$(zoxide init zsh)"

# direnv: per-directory .envrc autoloading
# eval "$(direnv hook zsh)"

# zsh-autosuggestions: fish-style greyed suggestion from history
# Strategy: try a history match first; if none exists, fall back to the
# completion engine instead of showing nothing. Plain "history" alone will
# happily resurface a stale/mistyped past command (wrong case, renamed dir,
# etc.) with no check that it still resolves to anything real.
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
# Italicize the ghost text so it reads unmistakably as "not yet typed",
# distinct from the dim-but-upright real text already on the line.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244,italic'
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Tab → completion (filesystem / commands / args). Always real menu
# completion; no autosuggestion path here.
bindkey '^I' expand-or-complete

# Space → the first space behaves like a normal space. A second
# consecutive space (i.e. pressed when the buffer already ends in
# one) accepts the autosuggestion, then inserts that trailing space.
# This way `cd ` won't snap-grab a history guess on the first space.
#
# Explicit autosuggestion-accept keys still work:
#   Right-arrow / Ctrl-E   accept the whole guess (no trailing space)
#   Ctrl-F                 accept one word
_space_accept_or_self() {
    if [[ $LBUFFER == *' ' && -n $POSTDISPLAY ]]; then
        zle autosuggest-accept
    fi
    zle self-insert
}
zle -N _space_accept_or_self
bindkey ' ' _space_accept_or_self

# zsh-syntax-highlighting: MUST be sourced last (hooks into ZLE)
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# eval "$(mise activate zsh)"

# Global aliases for chaining commands: `command1 and command2`, `command1 or command2`
alias -g and='&&'
alias -g or='||'
