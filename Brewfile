# Brew dependencies for these dotfiles.
# Install with: brew bundle --file=~/.dotfiles/Brewfile
# Check status: brew bundle check --file=~/.dotfiles/Brewfile

# Modern replacements for the ancient versions Apple ships
brew "bash"                      # macOS bash is 3.2 (2007) — brew is 5.x
brew "zsh"                       # newer than the macOS-bundled zsh
brew "git"                       # macOS git lags significantly behind upstream

# CLI tools consumed by the shell config
brew "fzf"                       # ctrl-r / ctrl-t / alt-c integration in .zshrc
brew "zoxide"                    # `z <substr>` frecent dir jumper in .zshrc
brew "direnv"                    # per-dir .envrc autoload in .zshrc
brew "eza"                       # modern ls; aliased in zsh/alias.zsh
brew "jq"                        # parses Claude statusline JSON in claude/statusline.sh
brew "tmux"                      # tmux/tmux.conf
brew "gitleaks"                  # scanned by githooks/pre-push
brew "dockutil"                  # used by bin/macos-defaults to rewrite the Dock

# zsh enhancements — .zshrc sources these from /opt/homebrew/share
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"

# Mac App Store CLI — needed for the `mas` lines below.
# Note: `mas signin` was removed in 10.14+; sign into the App Store
# manually before `brew bundle` if Xcode isn't installed yet.
brew "mas"

# GUI apps installed as Homebrew Casks — skipped if a copy is already
# present in /Applications (e.g. installed by hand from a direct DMG)
# to avoid clobbering the existing install.
cask "google-chrome" unless File.exist?("/Applications/Google Chrome.app")
cask "1password"     unless File.exist?("/Applications/1Password.app")

# Xcode comes from the Mac App Store (no Cask available — Apple-only).
# ~12GB download; after install run `sudo xcodebuild -license accept`
# and `sudo xcode-select --install` for the CLT.
mas "Xcode", id: 497799835
