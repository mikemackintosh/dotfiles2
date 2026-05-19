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
setopt SH_WORD_SPLIT
setopt interactive_comments
setopt no_beep
setopt numeric_glob_sort
setopt notify
setopt long_list_jobs
setopt correct

# Changing directories
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus
setopt auto_param_keys
setopt auto_param_slash

# Completion
setopt auto_list
setopt auto_menu
setopt always_to_end
setopt complete_in_word
setopt flow_control
setopt menu_complete

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
command -v code &>/dev/null
if [[ $? -eq 0 ]]; then
  export EDITOR=code
fi

# Set brew env
if [[ -d /opt/homebrew/bin ]]; then
  eval $(/opt/homebrew/bin/brew shellenv)
fi

STD_PATH=$PATH
extra_sources=(
    $HOME/bin
    "${GOPATH}/bin"
    /opt/homebrew/bin/
)
export PATH="${(j.:.)extra_sources}:$STD_PATH"

export GOPATH=$HOME/go

dot_plugins=(
    "alias"
    "git"
    "go"
    "grep"
    "keybind"
    "private"

    "prompt"
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
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# Move cursor to bottom of screen
printf '\n%.0s' {1..$LINES}
# Set cursor to I-beam
# printf '\033[5 q\r'

alias clear="clear && printf '\n%.0s' {1..$LINES} && printf '\033[5 q\r'"

# External tool integrations
# fzf: fuzzy ctrl-R history, ctrl-T file picker, alt-C dir jump
source <(fzf --zsh)

# zoxide: smarter cd — `z <substring>` jumps to a frecent dir
eval "$(zoxide init zsh)"

# direnv: per-directory .envrc autoloading
eval "$(direnv hook zsh)"

# zsh-autosuggestions: fish-style greyed suggestion from history
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Tab: accept autosuggestion if one is shown, else do normal completion
_tab_accept_or_complete() {
    if [[ -n "$POSTDISPLAY" ]]; then
        zle autosuggest-accept
    else
        zle expand-or-complete
    fi
}
zle -N _tab_accept_or_complete
bindkey '^I' _tab_accept_or_complete

# zsh-syntax-highlighting: MUST be sourced last (hooks into ZLE)
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
