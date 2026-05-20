#!/usr/bin/env bash
# Symlinks dotfiles into $HOME. Idempotent; backs up any existing
# real files into ~/.dotfiles-backup-<timestamp>/ before linking.
#
# Usage:
#   install.sh             link everything (default)
#   install.sh --check     verify symlinks and brew deps; no changes
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
BREWFILE="$DOTFILES/Brewfile"

# Pairs of: <source-in-dotfiles> <dest-in-home>
PAIRS=(
    ".zshrc                  $HOME/.zshrc"
    ".zprofile               $HOME/.zprofile"
    ".hushlogin              $HOME/.hushlogin"
    "tmux/tmux.conf          $HOME/.config/tmux/tmux.conf"
    "vim                     $HOME/.vim"
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
    "")
        ;;
    *)
        echo "Usage: $0 [--check]" >&2
        exit 2
        ;;
esac

for pair in "${PAIRS[@]}"; do
    read -r src dst <<<"$pair"
    link "$src" "$dst"
done

chmod +x "$DOTFILES/claude/statusline.sh" "$DOTFILES/install.sh"

if [[ -d "$BACKUP" ]]; then
    echo
    echo "Existing files backed up to: $BACKUP"
fi
echo "Done."
