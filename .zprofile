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
