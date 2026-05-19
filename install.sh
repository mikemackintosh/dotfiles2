#!/usr/bin/env bash
# Symlinks dotfiles into $HOME. Idempotent; backs up any existing
# real files into ~/.dotfiles-backup-<timestamp>/ before linking.
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Pairs of: <source-in-dotfiles> <dest-in-home>
PAIRS=(
    ".zshrc                  $HOME/.zshrc"
    ".zprofile               $HOME/.zprofile"
    ".hushlogin              $HOME/.hushlogin"
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
