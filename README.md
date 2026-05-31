# dotfiles

Personal macOS dotfiles. zsh + tmux + vim + a sanitized git config, plus a few
small CLI tools and global git hooks. No plugin manager, no starship — pure
shell where possible.

## Install

```sh
git clone <repo-url> ~/.dotfiles
~/.dotfiles/install.sh                   # symlinks + installs brew + brew bundle

# Identity (never committed)
cp ~/.dotfiles/gitconfig.private.example ~/.private/gitconfig
$EDITOR ~/.private/gitconfig             # fill in name/email/signing key

# Optional: apply macOS system prefs (scrolling, cursor color, Dock)
macos-defaults
```

Verify everything afterwards:

```sh
~/.dotfiles/install.sh --check           # symlinks + brew deps audit
```

## Layout

```
.zshrc, .zprofile, .hushlogin, .gitconfig   symlinked into $HOME by install.sh
Brewfile                                    brew bundle dependencies
bin/                                        user scripts (added to $PATH)
claude/                                     Claude Code settings + statusline
githooks/                                   global git hooks (core.hooksPath)
gitconfig.private.example                   template for ~/.private/gitconfig
install.sh                                  idempotent symlink installer
iterms/                                     iTerm2 color themes
tmux/tmux.conf                              tmux config
vim/                                        vimrc + vendored plugins
zsh/                                        plugin files sourced from .zshrc
```

## Identity & signing

The public `.gitconfig` contains zero personal data. Identity lives in
`~/.private/gitconfig` (template in this repo) and is pulled in via `include`.

For work commits under `~/go/src/github.com/wealthsimple/...`, an `includeIf`
overlay auto-swaps `user.email` to the work address from
`~/.private/gitconfig-work`. Other paths keep the personal email.

## tmux (prefix `C-b`)

| Binding              | Action                                              |
|----------------------|-----------------------------------------------------|
| `prefix T`           | Open `tmux-sessionizer` project picker              |
| `prefix \|` / `-`     | Split window vertically / horizontally (cwd-aware)  |
| `prefix c`           | New window (cwd-aware)                              |
| `prefix h j k l`     | Move pane focus (vim-style)                         |
| `prefix H J K L`     | Resize pane (repeatable with `-r`)                  |
| `prefix Tab`         | Last window                                         |
| `prefix Enter`       | Toggle zoom                                         |
| `prefix S`           | Toggle synchronize-panes                            |
| `prefix C-l`         | Clear scrollback                                    |
| `prefix r`           | Reload tmux config                                  |
| `prefix f`           | tmux default — find-window                          |

In copy-mode: `v` start selection, `y` yank to pasteboard.

## zsh key bindings

| Binding         | Action                                              |
|-----------------|-----------------------------------------------------|
| `Ctrl-R`        | fzf history search                                  |
| `Ctrl-T`        | fzf file picker under cwd                           |
| `Alt-C`         | fzf cd into subdir                                  |
| `Ctrl-G`        | fzf-pick a local git branch — switches on enter     |
| `Ctrl-X Ctrl-J` | fzf-pick a zoxide-known dir by frecency — cd on enter |
| `Tab`           | Accept autosuggestion if shown, else complete       |

## Git aliases

In `.gitconfig` (works as `git <alias>`):

| Alias    | Expands to                                  |
|----------|---------------------------------------------|
| `git st` | `git status`                                |
| `git d`  | `git diff --patience`                       |
| `git br` | `git branch`                                |
| `git co` | `git checkout`                              |
| `git ci` | `git commit -a`                             |
| `git cm` | `git commit -m`                             |
| `git up` | `git pull`                                  |
| `git main` | `git checkout main && git pull`           |
| `git lg` / `lgo` / `lga` | Graph logs (decorated / oneline / all) |

In `zsh/alias.zsh` (terminal shortcuts):

| Alias        | Expands to                                       |
|--------------|--------------------------------------------------|
| `gs`         | `git status`                                     |
| `gl`         | `git log --oneline --graph --decorate`           |
| `gp`         | `git pull`                                       |
| `gm`         | `git main`                                       |
| `gb [name]`  | switch to branch, or print current               |
| `gcm <msg>`  | `git commit -m` (rejects empty messages)         |

## Tools in `bin/`

### `memories` — browse / create / search Claude Code project memories

The zsh prompt counts per-project memory files; this is the CLI to manage them.

```sh
memories                       # fzf-browse this dir's memories
memories -a                    # fzf-browse memories across every project
memories new <type> <name>     # scaffold a memory, open in $EDITOR
                               #   type ∈ {user, feedback, project, reference}
                               #   name ∈ kebab-case
memories grep <pattern>        # ripgrep across every project's memories
```

Inside the fzf browser: `enter` opens in `$EDITOR`, `Ctrl-Y` copies the path,
`Ctrl-/` toggles preview.

### `tmux-sessionizer` — fzf project switcher for tmux

Picks a project dir and attaches a tmux session named after it (creates on
first use). Works in or out of tmux. Bound to `prefix T`.

```sh
tmux-sessionizer            # fzf picker
tmux-sessionizer <dir>      # skip the picker
```

Default project list: wealthsimple repos under `~/go/src/github.com/wealthsimple/`
plus `~/.dotfiles`. Override per-machine via `~/.dotfiles/.tmux-sessionizer-paths`
(gitignored), one entry per line — exact paths or shell globs:

```
~/work/repos/*
~/.dotfiles
~/personal/blog
```

### `macos-defaults` — apply system preferences

One-shot script that configures the Mac the way I like it: disables natural
scrolling, sets a bright green (`#95ef00`) cursor with an orange (`#ff7f00`)
outline, rewrites the Dock to Messages / System Settings / Chrome plus an
`/Applications` folder and a `~/Downloads` stack (fan reveal) on the right
side, and tweaks Finder (path bar, status bar, `$HOME` in the sidebar).
Idempotent. Cursor color needs a logout to render.

```sh
macos-defaults
```

Requires `dockutil` (in the Brewfile).

## Containerized CLIs (Docker)

Node and kubectl are deliberately **not** installed on the host — they run in
Docker instead, so the toolchain is reproducible and disposable. Both shims
forward every argument straight through, so they're drop-in replacements.

### `node` — Node.js in Docker (`bin/node`)

Transparent `node` on `$PATH`. Runs `node` in a container with `$HOME` mounted
at an **identical path** (as the host user), so `require.resolve(...)` and any
emitted paths stay valid on the host. That's what lets tools which shell out to
node — CocoaPods (`pod install`), Metro, the RN CLI — work with no local Node.

```sh
node -v
NODE_DOCKER_IMAGE=node:22 node script.js     # override image (default node:20)
```

| Env var             | Default    | Purpose                       |
|---------------------|------------|-------------------------------|
| `NODE_DOCKER_IMAGE` | `node:20`  | container image               |
| `NODE_DOCKER_ARGS`  | *(array)*  | extra `docker run` args       |

### `k` — kubectl in Docker (`zsh/kube.zsh`)

`k` is a drop-in kubectl: runs the configured image with your kubeconfig mounted
read-only and forwards all args. `kconfig` prints the effective settings.

```sh
k get pods
k -n qondom rollout restart deployment qondom-web
echo "$manifest" | k apply -f -
kconfig                                       # show image / kubeconfig / namespace
```

Override per-machine in `zsh/private.zsh`, or per-repo with a direnv `.envrc`:

| Env var             | Default                          | Purpose                          |
|---------------------|----------------------------------|----------------------------------|
| `KUBE_IMAGE`        | `bitnami/kubectl:latest`         | container image                  |
| `KUBECONFIG_FILE`   | `$HOME/dcs-pro1-kubeconfig.yaml` | kubeconfig, mounted RO           |
| `KUBE_NAMESPACE`    | *(empty)*                        | default namespace (adds `-n`)    |
| `KUBE_DOCKER_ARGS`  | *(array)*                        | extra `docker run` args          |
| `KUBE_KUBECTL_ARGS` | *(array)*                        | extra kubectl args, prepended    |

## Prompt

Pure-zsh powerline prompt, three palettes. Toggle with `prompt-theme`:

```sh
prompt-theme               # cycle: zush → tokyo → noir
prompt-theme tokyo         # set explicitly
```

Persists to `~/.zp-theme`. The "memory count" segment shows project-scoped
memory files for the current directory (cached by mtime, free per-prompt).

## Git hooks

Global `core.hooksPath = ~/.dotfiles/githooks`. Currently provides:

- **pre-push**: runs `gitleaks detect` against the repo and blocks the push on
  any finding. No-ops cleanly if `gitleaks` isn't installed.

```sh
git push --no-verify                              # bypass once
git config --local core.hooksPath .git/hooks      # disable for one repo
```

`.gitleaks.toml` allowlists `vim/pack/vendor/` — vendored plugin trees aren't
audited.

## Vim

LazyVim-feel in plain vim 8+ via the native package manager. Plugins are
vendored under `vim/pack/vendor/start/`, refreshed by `vim/upgrade.sh`
(versions pinned in `vim/vendor.lock`).

Theme:

```vim
:VimTheme tokyonight
:VimTheme gruvbox
```

(Takes effect on next vim start. Persists to `~/.vim-theme`.)

Leader is `<space>`. The interesting bindings (full set in `vim/vimrc`):

| Mapping        | Action                                  |
|----------------|-----------------------------------------|
| `<leader>e`    | Toggle NERDTree                         |
| `<leader>ff`   | fzf files                               |
| `<leader>fg`   | fzf ripgrep                             |
| `<leader>fb`   | fzf buffers                             |
| `gd` / `gr`    | LSP definition / references             |
| `K`            | LSP hover                               |
| `]h` / `[h`    | Next / previous git hunk                |
| `<C-h/j/k/l>`  | Move between splits                     |

## Claude Code

`claude/settings.json` is symlinked into `~/.claude/`. Notable choices:

- `Bash(gh)` / `Bash(gh *)` are denied — `gh` CLI is never used; GitHub work
  goes through MCP tools.
- Status line is `claude/statusline.sh`, which renders dir / git branch /
  model / context-window percent / token + cost counters.
