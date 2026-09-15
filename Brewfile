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
brew "go"                        # githooks/pre-commit runs gofmt + go vet on staged .go

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
cask "iterm2"        unless File.exist?("/Applications/iTerm.app")
cask "google-chrome" unless File.exist?("/Applications/Google Chrome.app")
cask "1password"     unless File.exist?("/Applications/1Password.app")
# Cask artifact is version-numbered, so the guard names Alfred 5.app.
cask "alfred"        unless File.exist?("/Applications/Alfred 5.app")
cask "docker-desktop" unless File.exist?("/Applications/Docker.app")

# Nerd Fonts — patched with the powerline/devicon glyphs zsh/prompt.zsh draws.
# Without one of these the prompt renders as tofu boxes. Picked for the
# Menlo/Monaco/Ubuntu lineage: Meslo is Menlo with a fixed line gap, Hack and
# DejaVu share Menlo's Bitstream Vera ancestry, Anonymice descends from Monaco.
# Full catalogue: brew search '/nerd-font$/'
cask "font-hack-nerd-font"
cask "font-meslo-lg-nerd-font"
cask "font-dejavu-sans-mono-nerd-font"
cask "font-anonymice-nerd-font"
cask "font-ubuntu-mono-nerd-font"
cask "font-ubuntu-sans-nerd-font"

# Xcode comes from the Mac App Store (no Cask available — Apple-only).
# ~12GB; install.sh accepts the license for you afterwards. This line
# fails if the App Store is not signed in — install.sh reports that as a
# TODO rather than aborting the whole bundle.
mas "Xcode", id: 497799835
