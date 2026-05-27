#!/usr/bin/env bash
# Bootstrap dotfiles: symlink configs, install Homebrew + Brewfile
# packages, and chmod helper scripts. Idempotent; backs up any
# existing real files into ~/.dotfiles-backup-<timestamp>/ before
# linking.
#
# Usage:
#   install.sh             link, install brew, run brew bundle (default)
#   install.sh --check     verify symlinks and brew deps; no changes
#   install.sh macos       apply macOS system prefs (delegates to bin/macos-defaults)
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
BREWFILE="$DOTFILES/Brewfile"

# Pairs of: <source-in-dotfiles> <dest-in-home>
PAIRS=(
    ".zshrc                  $HOME/.zshrc"
    ".zprofile               $HOME/.zprofile"
    ".hushlogin              $HOME/.hushlogin"
    ".gitconfig              $HOME/.gitconfig"
    "tmux/tmux.conf          $HOME/.config/tmux/tmux.conf"
    "vim                     $HOME/.vim"
    "ghostty/config          $HOME/.config/ghostty/config"
    "ghostty/themes          $HOME/.config/ghostty/themes"
    "claude/statusline.sh    $HOME/.claude/statusline.sh"
    "claude/settings.json    $HOME/.claude/settings.json"
)

link() {
    local src="$DOTFILES/$1"
    local dst="$2"

    if [[ ! -e "$src" ]]; then
        echo "skip $dst — source missing: $src" >&2
        return
    fi

    if [[ -L "$dst" ]]; then
        local current
        current="$(readlink "$dst")"
        if [[ "$current" == "$src" ]]; then
            echo "ok   $dst (already linked)"
            return
        fi
        echo "swap $dst (was -> $current)"
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        mkdir -p "$BACKUP"
        local rel="${dst#$HOME/}"
        mkdir -p "$BACKUP/$(dirname "$rel")"
        mv "$dst" "$BACKUP/$rel"
        echo "back $dst -> $BACKUP/$rel"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "link $dst -> $src"
}

# Doctor: read-only audit of the install. Returns non-zero on any failure.
check() {
    local failed=0

    echo "Symlinks:"
    for pair in "${PAIRS[@]}"; do
        read -r src dst <<<"$pair"
        local expected="$DOTFILES/$src"
        if [[ ! -L "$dst" ]]; then
            if [[ -e "$dst" ]]; then
                echo "  FAIL  $dst exists but is not a symlink"
            else
                echo "  FAIL  $dst missing"
            fi
            failed=1
        elif [[ "$(readlink "$dst")" != "$expected" ]]; then
            echo "  FAIL  $dst -> $(readlink "$dst") (expected $expected)"
            failed=1
        else
            echo "  ok    $dst"
        fi
    done

    echo
    echo "Brew dependencies:"
    if ! command -v brew >/dev/null 2>&1; then
        echo "  FAIL  brew is not installed"
        failed=1
    elif [[ ! -f "$BREWFILE" ]]; then
        echo "  skip  no Brewfile at $BREWFILE"
    elif brew bundle check --file="$BREWFILE" >/dev/null 2>&1; then
        echo "  ok    all packages present"
    else
        echo "  FAIL  missing packages — run: brew bundle --file=$BREWFILE"
        brew bundle check --file="$BREWFILE" --verbose 2>&1 | sed 's/^/        /'
        failed=1
    fi

    echo
    if (( failed )); then
        echo "doctor: issues found"
        return 1
    fi
    echo "doctor: all good"
}

case "${1:-}" in
    --check|-c|doctor)
        check
        exit $?
        ;;
    macos)
        exec "$DOTFILES/bin/macos-defaults"
        ;;
    "")
        ;;
    *)
        echo "Usage: $0 [--check|macos]" >&2
        exit 2
        ;;
esac

for pair in "${PAIRS[@]}"; do
    read -r src dst <<<"$pair"
    link "$src" "$dst"
done

# GOPATH layout. Falls back to $HOME/go (Go's own default since 1.16)
# if $GOPATH is unset. Creates the standard bin/pkg/src triple plus
# the personal project root, then exposes that root at ~/Projects.
# CHASE_LINKS in .zshrc makes `cd ~/Projects` resolve to the real path.
GOPATH="${GOPATH:-$HOME/go}"
mkdir -p "$GOPATH"/{bin,pkg,src}
PROJ_TARGET="$GOPATH/src/github.com/mikemackintosh"
PROJ_LINK="$HOME/Projects"
mkdir -p "$PROJ_TARGET"
if [[ ! -e "$PROJ_LINK" && ! -L "$PROJ_LINK" ]]; then
    ln -s "$PROJ_TARGET" "$PROJ_LINK"
    echo "link $PROJ_LINK -> $PROJ_TARGET"
elif [[ -L "$PROJ_LINK" && "$(readlink "$PROJ_LINK")" != "$PROJ_TARGET" ]]; then
    echo "warn $PROJ_LINK already symlinked to $(readlink "$PROJ_LINK") — leaving as-is" >&2
fi

chmod +x "$DOTFILES/claude/statusline.sh" "$DOTFILES/install.sh" \
         "$DOTFILES/bin/memories" "$DOTFILES/bin/tmux-sessionizer" \
         "$DOTFILES/bin/notify" "$DOTFILES/bin/git-review" \
         "$DOTFILES/bin/pr-spin" "$DOTFILES/bin/gh" \
         "$DOTFILES/bin/macos-defaults" "$DOTFILES/bin/claude-on" \
         "$DOTFILES/bin/battery-info" "$DOTFILES/bin/weather" \
         "$DOTFILES/bin/now-playing" "$DOTFILES/bin/airpods-battery" \
         "$DOTFILES/bin/tmux-status-right" \
         "$DOTFILES/githooks/pre-push" "$DOTFILES/githooks/pre-commit"

# Install Homebrew if missing, then materialize the Brewfile.
if ! command -v brew >/dev/null 2>&1; then
    echo
    echo "Installing Homebrew..."
    /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Put brew on PATH for the brew bundle call below.
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

if [[ -f "$BREWFILE" ]] && command -v brew >/dev/null 2>&1; then
    echo
    echo "Running brew bundle..."
    brew bundle --file="$BREWFILE"
fi

# Promote brew zsh to login shell. macOS ships an older zsh at /bin/zsh;
# this points $SHELL at the brew version so .zshrc gets the modern build.
if command -v brew >/dev/null 2>&1; then
    brew_zsh="$(brew --prefix)/bin/zsh"
    if [[ -x "$brew_zsh" ]]; then
        if ! grep -qxF "$brew_zsh" /etc/shells; then
            echo
            echo "Registering $brew_zsh in /etc/shells (needs sudo)..."
            echo "$brew_zsh" | sudo tee -a /etc/shells >/dev/null
        fi
        current_shell=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')
        if [[ "$current_shell" != "$brew_zsh" ]]; then
            echo
            echo "Switching login shell from $current_shell to $brew_zsh..."
            chsh -s "$brew_zsh"
        fi
    fi
fi

if [[ -d "$BACKUP" ]]; then
    echo
    echo "Existing files backed up to: $BACKUP"
fi
echo "Done."
