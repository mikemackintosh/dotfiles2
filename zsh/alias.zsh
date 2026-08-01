# Global aliases for chaining commands: `command1 and command2`, `command1 or command2`
alias -g and='&&'
alias -g or='||'

# ls
if command -v eza &>/dev/null; then
  alias ls=eza
fi

# Always pass the environment
alias sudo='sudo -E'

alias gs='git status'
alias gl='git log --oneline --graph --decorate'
alias gp='git pull'
alias gm='git main'      # checkout main + pull (see [alias] main in .gitconfig)

function gb {
  if [[ ! -z "$1" ]]; then
    git switch "$*"
    return 0
  fi

  local branch=$(git rev-parse --abbrev-ref HEAD)
  echo -e "\033[38;5;39mCurrent branch: $branch\033[0m"
}

function gcm {
  local msg="$*"
  echo $msg | grep -qE '^\s*$' && {
    echo -e "\033[38;5;195mCommit message cannot be empty!\033[0m"
    return 1
  }

  git commit -m "$msg"
}