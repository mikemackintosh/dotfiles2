#!/usr/bin/env bash
# Re-fetch every vendored vim plugin from upstream into pack/vendor/start/.
# Updates vendor.lock with new SHAs. Diff is reviewable via:
#     cd ~/.dotfiles && git diff --stat vim/pack/vendor/start
# Then commit when satisfied.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$DIR/pack/vendor/start"
LOCK="$DIR/vendor.lock"

# url, then vendored-dir name. Add new plugins here.
PLUGINS=(
  "https://github.com/ghifarit53/tokyonight-vim.git           tokyonight-vim"
  "https://github.com/morhetz/gruvbox.git                     gruvbox"
  "https://github.com/vim-airline/vim-airline.git             vim-airline"
  "https://github.com/vim-airline/vim-airline-themes.git      vim-airline-themes"
  "https://github.com/preservim/nerdtree.git                  nerdtree"
  "https://github.com/Xuyuanp/nerdtree-git-plugin.git         nerdtree-git-plugin"
  "https://github.com/junegunn/fzf.vim.git                    fzf.vim"
  "https://github.com/fatih/vim-go.git                        vim-go"
  "https://github.com/prabirshrestha/vim-lsp.git              vim-lsp"
  "https://github.com/prabirshrestha/asyncomplete.vim.git     asyncomplete.vim"
  "https://github.com/prabirshrestha/asyncomplete-lsp.vim.git asyncomplete-lsp.vim"
  "https://github.com/mattn/vim-lsp-settings.git              vim-lsp-settings"
  "https://github.com/airblade/vim-gitgutter.git              vim-gitgutter"
  "https://github.com/tpope/vim-commentary.git                vim-commentary"
  "https://github.com/jiangmiao/auto-pairs.git                auto-pairs"
  "https://github.com/sheerun/vim-polyglot.git                vim-polyglot"
  "https://github.com/ryanoasis/vim-devicons.git              vim-devicons"
)

mkdir -p "$DEST"
NEW_LOCK="$(mktemp)"

echo "Re-fetching ${#PLUGINS[@]} plugins into $DEST"
echo
for entry in "${PLUGINS[@]}"; do
    read -r url name <<<"$entry"
    printf "%-22s " "$name"
    tmp="$(mktemp -d)"
    if git clone -q --depth 1 "$url" "$tmp/$name" 2>/dev/null; then
        rev=$(git -C "$tmp/$name" rev-parse HEAD)
        rm -rf "$tmp/$name/.git"
        rm -rf "$DEST/$name"
        mv "$tmp/$name" "$DEST/$name"
        printf "%s\n" "${rev:0:7}"
        printf "%-20s %s\n" "$name" "${rev:0:7}" >>"$NEW_LOCK"
    else
        echo "FAILED"
    fi
    rm -rf "$tmp"
done

mv "$NEW_LOCK" "$LOCK"

echo
echo "Done. Review changes:"
echo "  cd ~/.dotfiles && git diff --stat vim/pack/vendor/start vim/vendor.lock"
echo
echo "Commit when satisfied:"
echo "  git add vim && git commit -m 'vim: refresh vendored plugins'"
