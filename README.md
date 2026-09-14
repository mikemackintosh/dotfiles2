# dotfiles

Personal macOS dotfiles. zsh + tmux + vim + a sanitized git config, plus a few
small CLI tools and global git hooks. No plugin manager, no starship — pure
shell where possible.

## Install

One command, from a Mac with nothing on it but macOS:

```sh
git clone <repo-url> ~/.dotfiles
~/.dotfiles/install.sh                   # everything, in dependency order

# Identity (never committed)
cp ~/.dotfiles/gitconfig.private.example ~/.private/gitconfig
$EDITOR ~/.private/gitconfig             # fill in name/email/signing key

# SSH keys + signing (never committed)
cp ~/.dotfiles/ssh-config.example ~/.ssh/config
$EDITOR ~/.ssh/config                    # point IdentityFile at your key
```

`install.sh` runs, in this order: preflight (Command Line Tools, Xcode
license, Full Disk Access) → Homebrew + Brewfile → symlinks → login shell →
macOS system prefs → git identity. **Don't run it with sudo** — it asks for a password once,
up front, only for the two steps that genuinely need root. Under `sudo` your
`$HOME` becomes `/var/root` and every `defaults write` would configure root's
account instead of yours; the script refuses rather than doing that quietly.

Nothing aborts the run. A step that can't complete (App Store not signed in,
Full Disk Access not granted yet) is skipped and reprinted as a numbered TODO
list at the end, with the exact command to finish it.

```sh
~/.dotfiles/install.sh --check           # audit; no changes
~/.dotfiles/install.sh --no-macos        # bootstrap without the system prefs
~/.dotfiles/install.sh links             # symlinks only
~/.dotfiles/install.sh brew              # Homebrew + Brewfile only
~/.dotfiles/install.sh macos             # system prefs only
```


### Git identity and signing

Identity and the signing key live in `~/.private/gitconfig`, outside this
repo — `.gitconfig` pulls them in with `[include]`. When that file is absent
git has no `user.email` at all and the first commit fails on "empty ident
name" with nothing pointing at the cause, so `install.sh` checks for it and
prints the fix.

Commits are SSH-signed with a key held in 1Password (no private key on disk).
`install.sh` derives `~/.config/git/allowed_signers` from `user.email` and
`user.signingkey`; without it `git log --show-signature` reports
`Unable to open allowed keys file` and shows good signatures as untrusted.

Two things GitHub needs, and they are separate entries even for one key:
the key registered as an **Authentication key** to push, and as a **Signing
key** for commits to show as Verified.

If a push fails with `ERROR: The key you are authenticating with has been
marked as read only`, a repo deploy key is shadowing your account key — see
the comments in `ssh-config.example`.

### Full Disk Access

One thing no script can grant itself. The cursor-color settings live in
`com.apple.universalaccess`, which is TCC-protected: the **terminal app**
needs Full Disk Access (`sudo` does not help — TCC is per-app, not per-user).
`install.sh` probes for it, opens the right Settings pane if it's missing,
and carries on. Add your terminal, quit and reopen it, then `macos-defaults`.

## Layout

```
.zshrc, .zprofile, .hushlogin, .gitconfig   symlinked into $HOME by install.sh
Brewfile                                    brew bundle dependencies
bin/                                        user scripts (added to $PATH)
claude/                                     Claude Code settings + statusline + prompts
docker/                                     Dockerfiles built by our tools (claude-review)
docs/                                       Deep-dive docs for individual tools
githooks/                                   global git hooks (core.hooksPath)
gitconfig.private.example                   template for ~/.private/gitconfig
ssh-config.example                          template for ~/.ssh/config (1Password agent)
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

### `git-review` — one-shot PR review (optionally auto-fix + push)

Shallow-clones a GitHub PR into `/tmp`, launches Claude inside the
`claude-review:local` container with `claude/prompts/review.md`. Claude reviews;
with `--fix` it applies findings and pushes them (nit-class → author's branch,
rearchitect-class → stacked PR). GitHub work goes through MCP tools; `gh` is
denied.

```sh
git review owner/repo 1234                              # review-only
git review <url> --fix                                  # apply findings + push
git review <url> --fix --no-interactive                 # yolo (safe in-container)
git review <url> --no-docker                            # on-host claude
git review <url> --model claude-opus-4-8
```

Full guide, mount table, troubleshooting: [`docs/git-review.md`](docs/git-review.md).

### `git-feature` — new feature or bug-fix branch, containerized

Symmetric to `git-review`: `git feature "<description>"` creates a fresh
branch off `origin/main`, asks Claude Haiku for a compact tmux session name,
and launches Claude inside the `claude-review:local` container with
`claude/prompts/make-pr.md`. `bin/pr-spin` remains as a back-compat symlink.

```sh
git feature "validate email length before save"
git feature ~/go/src/.../orbital "remove unused redis client"
git feature <desc> --no-docker                          # on-host claude
git feature <desc> --model claude-opus-4-8
```

Full guide: [`docs/git-feature.md`](docs/git-feature.md).

### Shared plumbing: `claude-in-docker`, `gen-compose-override`

Both `git-review` and `git-feature` use:

- `bin/claude-in-docker` — runs `claude --dangerously-skip-permissions` in
  `claude-review:local` with a narrow set of host mounts (workdir, `~/.claude`,
  `~/.gitconfig`, `~/.private`, `~/.ssh`, docker socket).
- `bin/gen-compose-override` — if the workdir has a `docker-compose.y{,a}ml`,
  writes `.env.review` + `docker-compose.override.yml` with randomized host
  ports (49152–65535) and a per-workdir `COMPOSE_PROJECT_NAME`. Uses the
  Compose v2.24+ `!override` YAML tag.
- `docker/claude-review/Dockerfile` — the image (`node:22-slim` + git + ssh
  + docker CLI + `@anthropic-ai/claude-code`). Built lazily by
  `claude-in-docker` on first use, or ahead of time with
  `docker build -t claude-review:local ~/.dotfiles/docker/claude-review/`.

### `claude-doctor` — verify the setup is healthy

Runs PASS/FAIL/SKIP checks across host tools, docker, 1Password, gitconfig,
`~/.claude.json` state, dotfiles pieces, and the built image. Non-zero exit
on any FAIL. Great to run after `install.sh` on a new machine or after a
Docker Desktop upgrade.

```sh
claude-doctor                # redacted output (screenshot-safe)
claude-doctor -v             # show actual values (email, registry URL)
claude-doctor --deep         # +end-to-end tests inside a real container
```

### `macos-defaults` — apply system preferences

One-shot script that configures the Mac the way I like it: disables natural
scrolling, sets a bright green (`#95ef00`) cursor with an orange (`#ff7f00`)
outline, rewrites the Dock to Messages / System Settings / Chrome plus an
`/Applications` folder and a `~/Downloads` stack (fan reveal) on the right
side, tweaks Finder (path bar, status bar, `$HOME` in the sidebar),
imports the iTerm2 color presets, and sets the iTerm2 appearance theme to
Minimal. Idempotent; run by `install.sh` by default.

```sh
macos-defaults                # apply, then offer to log out
macos-defaults --dry-run      # print what would change, touch nothing
macos-defaults --no-logout    # apply only (how install.sh calls it)
```

Supports macOS 12 (Monterey) through 26 (Tahoe). Anything that moved between
releases is branched on the major version explicitly — Sequoia changed the
cursor-color plist from RGBA arrays (`cursorFillColor`) to nested dicts
(`cursorFill` + a `cursorIsCustomized` gate), so both schemas are handled. On
a newer-than-tested macOS it reports what it skipped rather than writing keys
the OS no longer reads.

No step can take down the others: missing `dockutil`, no Full Disk Access, or
an app that isn't installed is skipped and listed in the summary. Refuses to
run under `sudo` (see the Install section for why). Tap-to-click, tap-drag and
cursor *size* need a logout; cursor *colors* and scrolling apply live.

### `iterm-themes` — install the color presets

Imports `iterms/*.itermcolors` into iTerm2 as Custom Color Presets, so they
appear under Settings → Profiles → Colors → Color Presets without dragging
each file onto the app. Called by `macos-defaults`. iTerm2 must be **quit** —
it holds its whole prefs dict in memory and writes it out on exit, which would
clobber the import.

```sh
iterm-themes                  # import all
iterm-themes --list           # show what's installed
```

### `codex-security` — Codex Security scans that survive the shim

Thin wrapper over `npx codex-security`; all arguments pass straight through.

```sh
codex-security scan --path .
codex-security login
```

It exists only to add `--security-opt seccomp=unconfined` to the `npx` shim's
`docker run`. Since `npx` is containerized, `npm install @openai/codex-security`
pulls the **Linux** build (`@openai/codex-linux-arm64`), and Codex on Linux
sandboxes each shell command with its bundled `bwrap`. Creating a user namespace
is blocked by Docker's default seccomp profile, so every command the scan agent
runs fails with `bwrap: No permissions to create a new namespace`; it writes no
artifacts and the scan ends with "did not create required draft artifacts".
Dropping the seccomp profile widens the container's escape surface — the trade
is accepted because it's what lets Codex build its own inner sandbox at all.

## Containerized CLIs (Docker)

Whole language toolchains are deliberately **not** installed on the host — they
run in Docker instead, so the environment is reproducible and disposable. The
shims forward every argument straight through, so they're drop-in replacements.

### Toolchain shims (`bin/docker-shim`)

One multi-call script: each tool name is a symlink to `bin/docker-shim`, which
dispatches by the name it was invoked as (`$0`) to a per-tool image. The host
`$HOME` is mounted at an **identical path** and the container runs as the host
user, so `require.resolve(...)` / emitted paths stay valid on the host (that's
what lets CocoaPods `pod install`, Metro, the RN CLI work with no local Node)
and written files aren't root-owned. Tool caches (`~/.npm`, `~/.cache`,
`~/.gem`, …) live under `$HOME`, so they persist between runs.

```sh
node -v
npm install
pnpm add -D vitest
python3 script.py
pip3 install requests
ruby -v ; bundle install
uvx ruff check .
NODE_DOCKER_IMAGE=node:20 node script.js     # override the image for one tool
DOCKER_SHIM_ARGS='--network host' npm test    # extra docker run args
```

| Tool (symlink → `docker-shim`)        | Default image                              |
|---------------------------------------|--------------------------------------------|
| `node` `npm` `npx` `yarn` `corepack`  | `node:22`                                  |
| `pnpm`                                | `node:22` (activated via bundled corepack) |
| `bun`                                 | `oven/bun:latest`                          |
| `deno`                                | `denoland/deno:latest`                     |
| `python3` `python` `pip3` `pip`       | `python:3.12-slim`                         |
| `uv` `uvx` `poetry`                   | `ghcr.io/astral-sh/uv:python3.12-bookworm-slim` |
| `ruby` `gem` `bundle` `bundler` `irb` | `ruby:3.3-slim`                            |
| `kotlinc` `kotlin` `kotlinc-jvm` `kotlinc-js` `kotlinc-wasm` `kotlinr` `kapt` | `eclipse-temurin:21-jdk` (+ official compiler zip) |

Per-tool image override: `<NAME>_DOCKER_IMAGE` (e.g. `PIP3_DOCKER_IMAGE=python:3.12`).
Extra `docker run` args: `DOCKER_SHIM_ARGS` (all tools) or `<NAME>_DOCKER_ARGS`.
The `-slim` Python/Ruby images can't compile native extensions — override the
image for those. Add a tool by extending the `case` in `bin/docker-shim` and the
symlink loop in `install.sh`.

There's no official JetBrains Kotlin image, so the Kotlin shims run a plain JDK
and bootstrap JetBrains' own `kotlin-compiler-<ver>.zip` into
`~/.cache/kotlin-compiler/` on first use, verifying the published SHA-256. Pin a
different version with `KOTLIN_VERSION=2.1.20 kotlinc -version`.

```sh
kotlinc hello.kt -include-runtime -d hello.jar && kotlin hello.jar
kotlinc -script build.kts
```

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

Three more files are symlinked into `~/.claude/` by `install.sh`:

### `claude/CLAUDE.md` — global answer style

Applies to every project: lead with the answer, separate proven from predicted,
name a ticket the first time rather than leaving a bare `#123`, and the shell
shapes that are never acceptable. The last section is what `bash-guard.sh`
enforces mechanically.

### `claude/bash-guard.sh` — a `PreToolUse` gate on Bash

Reads the hook payload on stdin and either stays silent (command proceeds
through normal permissions) or returns a `deny` / `ask` decision.

| Shape | Decision | Why |
| --- | --- | --- |
| `git stash` | deny | Moves work somewhere easy to forget; commit instead, then `git checkout HEAD -- <path>` |
| `… \|\| cp/mv <backup>` | deny | The fallback only runs when the first command *fails*, so the later restore has nothing to restore from |
| pipe feeding `&&` a state change | deny | A pipeline reports its *last* stage, so a trailing `grep` masks the real failure and the `&&` still fires |
| `git reset --hard/--merge/--keep` | ask | Discards uncommitted work irrecoverably |
| bare `git checkout -- <path>` | ask | Same effect as the HEAD form but doesn't say what it restores *to* |
| `git push --force` / `-f` | ask | Rewrites remote history |
| `rm -rf` | ask | Irreversible and silent |

Two deliberate design points. Matching is **syntactic** — "does this string
contain `stash`" — because the judgement needed for a semantic test is exactly
what is missing in the moment the bad command gets written. And quoted runs are
stripped before matching, so an `echo` or `grep` pattern that merely *names* one
of these shapes doesn't trip the guard. `git checkout HEAD -- <path>` is
explicitly **not** gated: it's the restore idiom the guard pushes you toward,
and friction on the recommended path is how you end up back at ad-hoc `.bak`
files.

### `claude/prompts/security-review.md` — branded assessment report

Prompt template for a full security review: severity rubric with EPSS plus a
modeled exploitation-probability estimate, a self-contained fix brief per
finding, an ethics gate for any live validation (owned accounts only, no
enumeration, scrub recovered secrets at teardown), and a self-contained HTML
report skeleton. See also `docs/android-skills.md` for the Android/Frida lab
cold-start runbook it assumes.
