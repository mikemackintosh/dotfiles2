#!/usr/bin/env bash
# Bootstrap these dotfiles on a Mac, from a box that has nothing but
# macOS on it. One command, in dependency order, and it never aborts
# half-way: anything that can't be done is collected and reprinted as
# a numbered TODO list at the end.
#
# Usage:
#   install.sh                  full bootstrap (default)
#   install.sh --check          audit only; no changes (alias: doctor)
#   install.sh --no-macos       bootstrap, but skip the system prefs
#   install.sh links            symlinks only
#   install.sh brew             Homebrew + Brewfile only
#   install.sh macos            system prefs only (bin/macos-defaults)
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
BREWFILE="$DOTFILES/Brewfile"

# Deferred failures. Nothing in this script exits on a recoverable
# problem; it appends the fix to this list and keeps going, so one
# missing permission can't cost you the other twenty steps.
TODO=()

bold=$'\033[1m'; blue=$'\033[1;34m'; green=$'\033[32m'
yellow=$'\033[33m'; red=$'\033[31m'; reset=$'\033[0m'
[[ -t 1 ]] || { bold=; blue=; green=; yellow=; red=; reset=; }

step() { printf '\n%s==>%s %s%s%s\n' "$blue" "$reset" "$bold" "$*" "$reset"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '    %sok%s   %s\n' "$green" "$reset" "$*"; }
warn() { printf '    %swarn%s %s\n' "$yellow" "$reset" "$*" >&2; }
die()  { printf '\n%serror%s %s\n' "$red" "$reset" "$*" >&2; exit 1; }
todo() { TODO+=("$1"); warn "$1"; }

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
    "claude/CLAUDE.md        $HOME/.claude/CLAUDE.md"
    "claude/bash-guard.sh    $HOME/.claude/bash-guard.sh"
)

# ---------------------------------------------------------------- utils

macos_major() { sw_vers -productVersion 2>/dev/null | cut -d. -f1 || echo 0; }

brew_shellenv() {
    command -v brew >/dev/null 2>&1 && return 0
    local b
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [[ -x "$b" ]] && { eval "$("$b" shellenv)"; return 0; }
    done
    return 1
}

# Ask for sudo once, up front, and hold the ticket for the whole run.
# Without this the password prompt lands 4 minutes in, behind a wall of
# brew output, and the install silently stalls waiting on it.
SUDO_PID=""
sudo_prime() {
    [[ -n "$SUDO_PID" ]] && return 0
    info "Some steps need sudo (/etc/shells, Xcode license). Priming now."
    sudo -v || die "sudo required"
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_PID=$!
    trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT
}

# ------------------------------------------------------------ preflight

preflight() {
    step "Preflight"

    [[ "$(uname -s)" == "Darwin" ]] || die "these dotfiles are macOS-only"

    # sudo makes $HOME /var/root, which silently sends dockutil and every
    # `defaults write` to root's preferences instead of yours. Screenshot
    # evidence that this is not theoretical: it wrote a Dock for /var/root.
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        die "do not run this with sudo — run it as $(logname 2>/dev/null || echo yourself).
      It prompts for sudo only where it genuinely needs root."
    fi

    local ver major
    ver="$(sw_vers -productVersion)"; major="$(macos_major)"
    ok "macOS $ver"
    if (( major < 12 )); then
        todo "macOS $ver is older than this repo targets (12+). Some prefs will be skipped."
    fi

    # Command Line Tools. Everything downstream (git, brew, compilers)
    # depends on these, and the installer is a GUI dialog we have to wait on.
    if xcode-select -p >/dev/null 2>&1; then
        ok "Command Line Tools present"
    else
        info "Installing Command Line Tools (a GUI dialog will appear)..."
        xcode-select --install >/dev/null 2>&1 || true
        local waited=0
        while ! xcode-select -p >/dev/null 2>&1; do
            (( waited >= 1800 )) && break
            sleep 10; waited=$(( waited + 10 ))
            (( waited % 60 == 0 )) && info "  waiting on Command Line Tools... (${waited}s)"
        done
        if xcode-select -p >/dev/null 2>&1; then
            ok "Command Line Tools installed"
        else
            todo "Command Line Tools did not finish. Run: xcode-select --install"
        fi
    fi

    # Xcode's license blocks git and every other xcrun shim until accepted.
    if [[ -d /Applications/Xcode.app ]]; then
        if defaults read /Library/Preferences/com.apple.dt.Xcode \
               IDEXcodeVersionForAgreedToGMLicense >/dev/null 2>&1; then
            ok "Xcode license accepted"
        else
            sudo_prime
            info "Accepting the Xcode license..."
            if sudo xcodebuild -license accept >/dev/null 2>&1; then
                ok "Xcode license accepted"
            else
                todo "Xcode license not accepted. Run: sudo xcodebuild -license accept"
            fi
        fi
    fi

    # Full Disk Access is the one thing no script can grant itself. Probing
    # a TCC-protected directory is the standard non-destructive test.
    if ls "$HOME/Library/Application Support/com.apple.TCC" >/dev/null 2>&1; then
        ok "Terminal has Full Disk Access"
    else
        warn "This terminal lacks Full Disk Access — cursor colors will be skipped."
        info "Opening System Settings → Privacy & Security → Full Disk Access."
        info "Add ${TERM_PROGRAM:-your terminal}, quit it, reopen, and re-run this script."
        open 'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles' \
            >/dev/null 2>&1 || true
        todo "Grant Full Disk Access to ${TERM_PROGRAM:-your terminal}, restart it, then: macos-defaults"
    fi
}

# ----------------------------------------------------------- homebrew

do_brew() {
    step "Homebrew"

    if brew_shellenv; then
        ok "brew at $(command -v brew)"
    else
        info "Installing Homebrew..."
        sudo_prime
        # GIT_CONFIG_GLOBAL=/dev/null: the installer is a git clone of a
        # public https URL. Any url.insteadOf rewrite in ~/.gitconfig turns
        # that into ssh, which fails with "Permission denied (publickey)" on
        # a machine that has no key yet. Ignoring the global config makes
        # the bootstrap immune to whatever git config is already linked.
        NONINTERACTIVE=1 GIT_CONFIG_GLOBAL=/dev/null /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
            || todo "Homebrew install failed. Re-run: $DOTFILES/install.sh brew"
        brew_shellenv || { todo "brew still not on PATH — skipping Brewfile"; return 0; }
        ok "brew at $(command -v brew)"
    fi

    [[ -f "$BREWFILE" ]] || { warn "no Brewfile at $BREWFILE"; return 0; }

    step "Brewfile packages"
    # brew bundle exits non-zero if ANY entry fails (commonly the mas/Xcode
    # line when the App Store isn't signed in). That must not kill the run,
    # and the exit status has to be captured directly — not through a pipe.
    if brew bundle --file="$BREWFILE" --no-upgrade; then
        ok "all Brewfile entries installed"
    else
        todo "Some Brewfile entries failed (often 'mas'/Xcode — sign into the App Store first).
      Re-run: brew bundle --file=$BREWFILE"
    fi
}

# -------------------------------------------------------------- links

link() {
    local src="$DOTFILES/$1" dst="$2"

    if [[ ! -e "$src" ]]; then
        warn "skip $dst — source missing: $src"
        return
    fi

    if [[ -L "$dst" ]]; then
        local current; current="$(readlink "$dst")"
        if [[ "$current" == "$src" ]]; then
            ok "$dst"
            return
        fi
        info "swap $dst (was -> $current)"
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        mkdir -p "$BACKUP/$(dirname "${dst#"$HOME"/}")"
        mv "$dst" "$BACKUP/${dst#"$HOME"/}"
        info "back $dst -> $BACKUP/${dst#"$HOME"/}"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    ok "$dst -> $src"
}

do_links() {
    step "Symlinks"
    local pair src dst
    for pair in "${PAIRS[@]}"; do
        read -r src dst <<<"$pair"
        link "$src" "$dst"
    done

    step "Directories and executables"

    # GOPATH layout. Falls back to $HOME/go (Go's own default since 1.16).
    # Creates the standard bin/pkg/src triple plus the personal project
    # root, then exposes that root at ~/Projects. CHASE_LINKS in .zshrc
    # makes `cd ~/Projects` resolve to the real path.
    local gopath="${GOPATH:-$HOME/go}"
    mkdir -p "$gopath"/{bin,pkg,src}
    local proj_target="$gopath/src/github.com/mikemackintosh"
    local proj_link="$HOME/Projects"
    mkdir -p "$proj_target"
    if [[ ! -e "$proj_link" && ! -L "$proj_link" ]]; then
        ln -s "$proj_target" "$proj_link"
        ok "$proj_link -> $proj_target"
    elif [[ -L "$proj_link" && "$(readlink "$proj_link")" != "$proj_target" ]]; then
        warn "$proj_link already points at $(readlink "$proj_link") — leaving as-is"
    else
        ok "$proj_link"
    fi

    # Every real script in bin/ plus the hooks. Globbed rather than listed,
    # so a new tool is executable the moment it lands (the old hand-kept
    # list silently went stale every time one was added).
    local f count=0
    for f in "$DOTFILES"/bin/*; do
        [[ -L "$f" ]] && continue          # docker-shim aliases
        [[ -f "$f" ]] || continue
        chmod +x "$f"; count=$(( count + 1 ))
    done
    chmod +x "$DOTFILES/install.sh" "$DOTFILES/claude/statusline.sh" \
             "$DOTFILES/claude/bash-guard.sh" \
             "$DOTFILES/docker/claude-review/cc-status-stub" \
             "$DOTFILES"/githooks/* 2>/dev/null || true
    ok "chmod +x on $count scripts in bin/ plus hooks"

    # Containerized toolchain shims: each name is a symlink to bin/docker-shim,
    # which dispatches by $0 to a Docker image. These languages/CLIs are kept
    # OFF the host on purpose. Self-heal in case any went missing.
    local t
    for t in node npm npx yarn pnpm corepack bun deno \
             python3 python pip3 pip uv uvx poetry \
             ruby gem bundle bundler irb \
             kotlinc kotlin kotlinc-jvm kotlinc-js kotlinc-wasm kotlinr kapt; do
        ln -sf docker-shim "$DOTFILES/bin/$t"
    done
    ok "docker-shim aliases"

    # Browser MCP for Claude Code. Because node is a shim, the stock
    # `npx chrome-devtools-mcp@latest` runs in a container with no Chrome and
    # no route to the Mac's loopback; bin/chrome-devtools-mcp runs it in the
    # Playwright image instead. Declarative: drop whatever definition exists,
    # then add this one, so re-running converges.
    if command -v claude >/dev/null 2>&1; then
        claude mcp get chrome-devtools >/dev/null 2>&1 && \
            claude mcp remove chrome-devtools >/dev/null 2>&1 || true
        if claude mcp add --scope user chrome-devtools -- \
               "$DOTFILES/bin/chrome-devtools-mcp" >/dev/null 2>&1; then
            ok "chrome-devtools MCP registered"
        else
            todo "Could not register the chrome-devtools MCP. Run: claude mcp add --scope user chrome-devtools -- $DOTFILES/bin/chrome-devtools-mcp"
        fi
    else
        info "claude not installed — skipping MCP registration"
    fi
}

# --------------------------------------------------------- git identity

# user.name, user.email and the signing key live in ~/.private/gitconfig,
# deliberately outside this repo. .gitconfig [include]s that path
# unconditionally, so when the file is absent git has no identity at all
# and the first commit dies on "empty ident name" with nothing pointing
# at the cause. Check for it, and derive allowed_signers from it.
do_gitidentity() {
    step "Git identity"

    local priv="$HOME/.private/gitconfig"
    if [[ ! -f "$priv" ]]; then
        todo "No $priv — copy gitconfig.private.example there and fill it in, or git has no identity and every commit fails."
        return 0
    fi
    ok "$priv"

    local email key fmt
    email="$(git config --get user.email || true)"
    key="$(git config --get user.signingkey || true)"
    fmt="$(git config --get gpg.format || true)"

    if [[ -n "$email" ]]; then ok "user.email $email"
    else todo "user.email is unset — add it to $priv"; fi

    if [[ "$fmt" != "ssh" || -z "$key" || -z "$email" ]]; then
        info "not SSH-signing (gpg.format=${fmt:-unset}) — skipping allowed_signers"
        return 0
    fi

    # user.signingkey is either literal key material or a path to a .pub.
    local material="$key"
    if [[ "$key" != ssh-* ]]; then
        local path="${key/#\~/$HOME}"
        if [[ -r "$path" ]]; then material="$(head -1 "$path")"; else
            todo "user.signingkey is neither key material nor a readable file: $key"
            return 0
        fi
    fi

    # .gitconfig points [gpg "ssh"] allowedSignersFile here unconditionally,
    # so a missing file makes every `git log --show-signature` fail with
    # "Unable to open allowed keys file" even when the signature is good.
    local signers="$HOME/.config/git/allowed_signers"
    local line; line="$(echo "$material" | cut -d' ' -f1,2)"
    line="$email $line"
    mkdir -p "$(dirname "$signers")"
    if [[ -f "$signers" ]] && grep -qxF "$line" "$signers"; then
        ok "allowed_signers"
    else
        printf '%s\n' "$line" >>"$signers"
        ok "allowed_signers <- user.email + user.signingkey"
    fi
}

# --------------------------------------------------------- login shell

do_shell() {
    step "Login shell"
    brew_shellenv || { warn "no brew — keeping the system zsh"; return 0; }

    local brew_zsh; brew_zsh="$(brew --prefix)/bin/zsh"
    if [[ ! -x "$brew_zsh" ]]; then
        warn "brew zsh not installed — keeping the system zsh"
        return 0
    fi

    if ! grep -qxF "$brew_zsh" /etc/shells; then
        sudo_prime
        info "Registering $brew_zsh in /etc/shells..."
        echo "$brew_zsh" | sudo tee -a /etc/shells >/dev/null \
            || todo "Add $brew_zsh to /etc/shells by hand"
    fi

    local current
    current=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}') || true
    if [[ "$current" == "$brew_zsh" ]]; then
        ok "login shell is $brew_zsh"
    else
        info "Switching login shell from $current to $brew_zsh..."
        if chsh -s "$brew_zsh"; then
            ok "login shell is $brew_zsh (takes effect in a new terminal)"
        else
            todo "Set your login shell by hand: chsh -s $brew_zsh"
        fi
    fi
}

# --------------------------------------------------------- macos prefs

do_macos() {
    step "macOS system preferences"
    if [[ ! -x "$DOTFILES/bin/macos-defaults" ]]; then
        todo "bin/macos-defaults missing or not executable"
        return 0
    fi
    # --no-logout: the bootstrap owns the "log out now?" question, once,
    # at the very end — not in the middle of a multi-step install.
    if "$DOTFILES/bin/macos-defaults" --no-logout; then
        ok "system preferences applied"
    else
        todo "Some system preferences were skipped. Re-run: macos-defaults"
    fi
}

# ------------------------------------------------------------- doctor

check() {
    local failed=0
    step "Symlinks"
    local pair src dst expected
    for pair in "${PAIRS[@]}"; do
        read -r src dst <<<"$pair"
        expected="$DOTFILES/$src"
        if [[ ! -L "$dst" ]]; then
            [[ -e "$dst" ]] && warn "$dst exists but is not a symlink" \
                            || warn "$dst missing"
            failed=1
        elif [[ "$(readlink "$dst")" != "$expected" ]]; then
            warn "$dst -> $(readlink "$dst") (expected $expected)"
            failed=1
        else
            ok "$dst"
        fi
    done

    step "System"
    ok "macOS $(sw_vers -productVersion)"
    xcode-select -p >/dev/null 2>&1 && ok "Command Line Tools" \
        || { warn "Command Line Tools missing — xcode-select --install"; failed=1; }
    if [[ -d /Applications/Xcode.app ]]; then
        defaults read /Library/Preferences/com.apple.dt.Xcode \
            IDEXcodeVersionForAgreedToGMLicense >/dev/null 2>&1 \
            && ok "Xcode license accepted" \
            || { warn "Xcode license not accepted — sudo xcodebuild -license accept"; failed=1; }
    fi
    ls "$HOME/Library/Application Support/com.apple.TCC" >/dev/null 2>&1 \
        && ok "Full Disk Access granted to this terminal" \
        || warn "no Full Disk Access for this terminal (cursor colors can't be set)"

    local shell_now
    shell_now=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}') || true
    if brew_shellenv && [[ -x "$(brew --prefix)/bin/zsh" ]]; then
        [[ "$shell_now" == "$(brew --prefix)/bin/zsh" ]] \
            && ok "login shell $shell_now" \
            || { warn "login shell is $shell_now, expected $(brew --prefix)/bin/zsh"; failed=1; }
    fi

    step "Brew dependencies"
    if ! brew_shellenv; then
        warn "brew is not installed"
        failed=1
    elif [[ ! -f "$BREWFILE" ]]; then
        info "no Brewfile at $BREWFILE"
    elif brew bundle check --file="$BREWFILE" >/dev/null 2>&1; then
        ok "all packages present"
    else
        warn "missing packages — run: brew bundle --file=$BREWFILE"
        # Not a pipeline: `brew bundle check` exits non-zero by design here,
        # and under `set -o pipefail` that status would abort the doctor
        # before it printed the Apps section or its verdict.
        local detail="${TMPDIR:-/tmp}/dotfiles-bundle-check.$$"
        brew bundle check --file="$BREWFILE" --verbose >"$detail" 2>&1 || true
        sed 's/^/        /' "$detail"
        rm -f "$detail"
        failed=1
    fi

    step "Git identity"
    local priv="$HOME/.private/gitconfig"
    local signers="$HOME/.config/git/allowed_signers"
    if [[ -f "$priv" ]]; then ok "$priv"
    else warn "$priv missing — copy gitconfig.private.example there"; failed=1; fi
    local d_email d_key
    d_email="$(git config --get user.email || true)"
    d_key="$(git config --get user.signingkey || true)"
    [[ -n "$d_email" ]] && ok "user.email $d_email" \
        || { warn "user.email unset — git cannot commit"; failed=1; }
    if [[ -z "$d_key" ]]; then
        info "no user.signingkey — commits will be unsigned"
    else
        # Compare on the base64 field alone: the key may be stored as
        # literal material or as a path to a .pub, and comments differ.
        local d_mat=""
        if [[ "$d_key" == ssh-* ]]; then
            d_mat="$(echo "$d_key" | cut -d' ' -f2)"
        elif [[ -r "${d_key/#\~/$HOME}" ]]; then
            d_mat="$(head -1 "${d_key/#\~/$HOME}" | cut -d' ' -f2)"
        fi
        if [[ -n "$d_mat" ]] && [[ -f "$signers" ]] && grep -qF "$d_mat" "$signers"; then
            ok "allowed_signers"
        elif [[ -f "$signers" ]]; then
            warn "$signers does not list user.signingkey"; failed=1
        else
            warn "$signers missing — good signatures show as untrusted. Run: install.sh"; failed=1
        fi
    fi

    step "Apps"
    local app
    for app in "iTerm" "Google Chrome" "1Password" "Alfred 5"; do
        [[ -d "/Applications/$app.app" ]] && ok "$app.app" \
            || { warn "/Applications/$app.app missing"; failed=1; }
    done

    echo
    if (( failed )); then
        printf '%sdoctor: issues found%s\n' "$yellow" "$reset"
        return 1
    fi
    printf '%sdoctor: all good%s\n' "$green" "$reset"
}

# --------------------------------------------------------------- main

summary() {
    if [[ -d "$BACKUP" ]]; then
        step "Backups"
        info "Replaced files saved to $BACKUP"
    fi

    if (( ${#TODO[@]} )); then
        step "${#TODO[@]} thing(s) still need you"
        local i=1 t
        for t in "${TODO[@]}"; do
            printf '    %s%d.%s %s\n' "$bold" "$i" "$reset" "$t"
            i=$(( i + 1 ))
        done
        echo
        info "Re-run '$DOTFILES/install.sh --check' once they're done."
    else
        step "Done"
        info "Nothing left to do by hand."
    fi

    echo
    info "Open a new terminal to pick up the new login shell."
    info "Tap-to-click and cursor size need a logout to take effect."

    # One logout prompt for the whole install, at the end, only if we
    # actually have a human on the other end.
    [[ -t 0 ]] || return 0
    echo
    printf '    Log out now to finish applying them? [y/N] '
    local ans; read -r ans || return 0
    if [[ "$ans" == [yY] ]]; then
        info "Logging out..."
        # Raw "rlgo" Apple event — logout without the 60s confirmation dialog.
        osascript -e 'tell application "loginwindow" to «event aevtrlgo»'
    fi
}

main() {
    local run_macos=1
    case "${1:-}" in
        --check|-c|doctor) check; exit $? ;;
        links)             preflight; do_links; summary; exit 0 ;;
        brew)              preflight; do_brew;  summary; exit 0 ;;
        macos)             exec "$DOTFILES/bin/macos-defaults" ;;
        --no-macos)        run_macos=0 ;;
        "")                ;;
        *) die "Usage: $0 [--check|--no-macos|links|brew|macos]" ;;
    esac

    preflight
    do_brew          # first: everything below wants git, dockutil, zsh
    do_links
    do_gitidentity
    do_shell
    (( run_macos )) && do_macos
    summary
}

main "$@"
