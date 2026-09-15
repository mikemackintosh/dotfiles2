
# Put Homebrew on PATH for login shells. Arch-agnostic: Apple Silicon
# installs to /opt/homebrew, Intel to /usr/local. Guarded so a machine
# without brew yet still gets a working login shell.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$_brew" ]; then
        eval "$("$_brew" shellenv zsh)"
        break
    fi
done
unset _brew

# Docker Desktop keeps its CLI here and nowhere else — no /usr/local/bin
# symlink — so without this, docker and every docker-shim alias exit 127.
# Added by Docker Desktop's installer with a hardcoded /Users/<you> path;
# rewritten to $HOME so the file still works on another machine.
[ -d "$HOME/.docker/bin" ] && export PATH="$PATH:$HOME/.docker/bin"
