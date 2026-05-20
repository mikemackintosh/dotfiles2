# fzf widgets — ZLE bindings that pair fzf with git and zoxide.
# Requires fzf and zoxide on PATH; both are in the Brewfile.

[[ -o interactive ]] || return 0

# ctrl-g — pick a local git branch (most-recently-touched first) and switch.
# Preview shows the branch's last ten commits.
_fzf_git_branch_widget() {
    git rev-parse --git-dir >/dev/null 2>&1 || { zle reset-prompt; return }
    local branch
    branch=$(git for-each-ref --sort=-committerdate refs/heads/ \
                --format='%(refname:short)' 2>/dev/null \
             | fzf --height=50% --reverse \
                   --header='switch branch' \
                   --preview='git log --oneline --graph --color=always -10 {}' \
                   --preview-window=right:55%)
    if [[ -n $branch ]]; then
        BUFFER="git switch $branch"
        zle accept-line
    else
        zle reset-prompt
    fi
}
zle -N _fzf_git_branch_widget
bindkey '^G' _fzf_git_branch_widget

# ctrl-x ctrl-j — pick a zoxide-known dir by frecency and cd to it.
# Preview shows a 2-level eza tree (falls back to ls if eza is missing).
_fzf_zoxide_cd_widget() {
    command -v zoxide >/dev/null 2>&1 || { zle reset-prompt; return }
    local dir
    dir=$(zoxide query -l \
          | fzf --height=50% --reverse \
                --header='cd to frecent dir' \
                --preview='eza --tree --level=2 --color=always --icons=never {} 2>/dev/null || ls -p {}' \
                --preview-window=right:60%)
    if [[ -n $dir ]]; then
        BUFFER="cd ${(q)dir}"
        zle accept-line
    else
        zle reset-prompt
    fi
}
zle -N _fzf_zoxide_cd_widget
bindkey '^X^J' _fzf_zoxide_cd_widget
