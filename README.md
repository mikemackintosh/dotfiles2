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
~/.dotfiles/install.sh ssh               # re-check 1Password agent + signing
```

### After the run — the parts no script can do

`install.sh` prints these as a numbered TODO list when it finds them undone,
and `install.sh --check` re-audits at any time. In dependency order — each
step is useless until the one above it is true:

1. **Install 1Password and turn its SSH agent on** — Settings → Developer →
   *Use the SSH agent*. Nothing else here works without it: the private keys
   exist only in the vault, and the agent is the only thing that can use
   them. The tell is `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`
   existing.
2. **Put the signing key in a vault the agent is allowed to serve.** If you
   have written `~/.config/1Password/ssh/agent.toml` by hand, a key outside
   the vaults it lists is invisible to the agent even though it is in your
   account. `ssh-add -l` lists exactly what the agent will offer.
3. **`cp gitconfig.private.example ~/.private/gitconfig`** and fill in
   `user.name`, `user.email` and `user.signingkey` (the **public** key text).
   Leave `gpg.ssh.program` pointing at `bin/git-ssh-sign` with an absolute
   path — git does not tilde-expand that key, and the wrapper is what makes
   a flaky or absent `op-ssh-sign` non-fatal.
4. **`cp ssh-config.example ~/.ssh/config && chmod 600 ~/.ssh/config`**, then
   write your account public key to `~/.ssh/github-account.pub` — the
   `Host github.com` block names it to stop a deploy key from shadowing your
   account key.
5. **Register the key on GitHub twice**: once as an **Authentication key** so
   you can push, and again as a **Signing key** so commits show as Verified.
   Same key, two separate entries, and the only step here that nothing local
   can verify for you.
6. **Re-run `install.sh ssh`.** It signs a throwaway payload with your real
   configured signer and must print both `1Password agent serves the signing
   key` and `signing works`. Anything else and your next commit fails, not
   your next check.
7. **Open a new terminal.** `zsh/ssh-agent.zsh` only pins `SSH_AUTH_SOCK` for
   shells started after the install; the one you ran the installer in still
   has macOS's empty agent.

Then Full Disk Access and the logout for the macOS prefs, both of which
`install.sh` will have already listed for you.

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

Commits and tags are SSH-signed. `gpg.ssh.program` points at
[`bin/git-ssh-sign`](bin/git-ssh-sign) rather than 1Password directly, so the
same config signs on the Mac (via 1Password, with its approval prompt) and
inside containers or cloud sandboxes (via `ssh-keygen` against the forwarded
agent). The verification list — the one signing-related file safe to commit —
is `~/.config/git/allowed_signers`; without it `git log --format=%G?` reports
`U` and "No principal matched" even for good signatures.

Signing from a host you are `ssh`'d into works the same way, with the agent
forwarded rather than local — 1Password's own agent cannot serve a headless
box, because every signature waits on an approval prompt on that machine's
screen. `ForwardAgent yes` for that host (never `Host *`), then make sure the
remote's `gpg.ssh.program` names a path that exists there; the Mac-absolute
default is what usually fails first. Full recipe, including the ControlMaster
and tmux traps, is in the comments of
[`ssh-config.example`](ssh-config.example).

`zsh/ssh-agent.zsh` pins `SSH_AUTH_SOCK` to 1Password's agent. macOS exports
its own socket (`/private/tmp/com.apple.launchd.*/Listeners`) into every login
session and that agent holds no keys — `ssh` never notices, because
`IdentityAgent` in `~/.ssh/config` overrides the env var, so the breakage
lands only on things that talk to the agent directly: `ssh-add -l`,
`ssh-keygen -Y sign`, and `claude-in-docker` forwarding the socket into a
container. `install.sh --check` now proves signing by signing a throwaway
payload with the configured `gpg.ssh.program`; a locked 1Password or a dead
`op-ssh-sign` IPC socket passes every static check and fails at your next
commit instead.

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

### `git-ssh-sign` — pick whichever SSH signer exists

Set as `gpg.ssh.program` in `~/.private/gitconfig` (absolute path — git does
not tilde-expand that key reliably). Execs 1Password's `op-ssh-sign` when
`/Applications` has it, else falls through to `ssh-keygen`, which signs against
whatever agent is forwarded. Both binaries take the same argv, which is what
makes the swap transparent.

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
imports the iTerm2 color presets, sets the iTerm2 appearance theme to
Minimal and every profile's font to MesloLGL Nerd Font Mono. Idempotent;
run by `install.sh` by default.

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

### `term-marks` — prompt marks on remote hosts

Marks are emitted by the **shell**, not the terminal, and reach your terminal
as ordinary bytes in the stream. So `zsh/term-integration.zsh` gives you marks
locally and nothing at all once you `ssh` somewhere — that remote shell needs
its own emitter.

```sh
term-marks                            # print the snippet; paste into a remote rc
term-marks --install user@host        # append it to the host's ~/.bashrc + ~/.zshrc
term-marks --check                    # what the current shell has registered
```

The snippet is shell-portable (zsh hooks, or bash `PROMPT_COMMAND` + a `DEBUG`
trap) and terminal-agnostic: OSC 133 is understood by iTerm2, kitty, WezTerm,
Ghostty, Windows Terminal and recent VTE, and ignored byte-for-byte by
everything else. There is no detection and nothing to configure. Verified
emitting identical A/B/C/D streams — `D;1` after a failing command included —
under both zsh and bash.

`--install` greps for its own marker before appending, so re-running it never
doubles the block.

Navigating the marks is the one part that *can't* be portable: it's a function
of the terminal's UI, not of the stream. In iTerm2 the default global key map
binds `⌘↑`/`⌘↓` (`0xf700`/`0xf701` with modifier mask `0x300000`); `⇧⌘↑`/`⇧⌘↓`
are bound to nothing, which is why pressing them types `;3A`/`;3B` into your
command line — an unbound chord gets encoded and forwarded to the shell. To
use those instead, bind them explicitly in Settings → Keys → Key Bindings with
the action "Select Menu Item…" → Marks and Annotations → Next/Previous Mark.

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

Pure-zsh powerline prompt with four independent, persisted knobs. A theme
picks colors; shape picks the glyphs between segments; style decides whether
segments are filled at all; density decides how many appear.

```sh
prompt-gallery             # every theme as a sample line — pick by eye
prompt-theme               # cycle; -l lists them all
prompt-theme kanagawa      # set explicitly
prompt-shape slant         # chevron round slant flame dust block plain ascii
prompt-style outline       # filled | bubble | outline
prompt-density lean        # full | lean | zen
```

| Theme | Look | Ships with |
|---|---|---|
| `zush` | warm coral/peach (default) | chevron |
| `tokyo` | Tokyo Night Storm, cool | chevron |
| `noir` | deep indigo + cyan + crimson | chevron |
| `princess` | sunset gradient, white text | chevron |
| `jblab` | JetBrains navy + teal | chevron |
| `rose` | Rosé Pine, muted plum and gold | round |
| `catppuccin` | Mocha pastels | chevron |
| `nord` | arctic blues | block |
| `gruvbox` | retro earth tones | flame |
| `synthwave` | neon pink/cyan on violet | slant |
| `kanagawa` | woodblock blue, autumn, sakura | slant |
| `ember` | forge yellow → crimson → charcoal | flame |
| `paper` | light pills for a bright room | round + bubble |
| `matrix` | one green hue, no fills | plain + outline |
| `ascii` | no Nerd Font glyphs at all | ascii + outline + lean |
| `dracula` | the default nerd palette | chevron |
| `crt` | amber P3 phosphor, one hue | plain + outline |
| `tron` | light-cycle cyan, Clu orange | block |
| `blade` | smog, neon and blood orange | slant |
| `neuromancer` | ice blue and chrome, one magenta cut | dust |
| `vaporwave` | pastel neon, floating | round + bubble |
| `nuclear` | hazard yellow, radioactive green | flame |
| `commodore` | C64 boot-screen blues | block |
| `borland` | Turbo Pascal yellow on #0000AA | block |
| `wopr` | WarGames green with amber alerts | block |

`ascii` is the one to pick over ssh to a box with an unpatched font, or in a
tty: it swaps the separators *and* the segment icons for plain characters, so
nothing renders as tofu. Every other shape needs a Nerd Font — see the
Brewfile.

Densities: `full` is everything including the weather/battery/now-playing HUD;
`lean` drops the HUD and keeps git, duration and clock; `zen` is user, dir and
branch only.

Adding a theme takes one function. Any `_zp_palette_<name>` in
`zsh/prompt-themes.zsh` is discovered by name — no list to update. It may set
`_ZP_THEME_SHAPE`, `_ZP_THEME_STYLE` and `_ZP_THEME_DENSITY` to ship its own
defaults, which the knobs then override.

State persists to `~/.zp-theme` as `theme shape style density` (a bare theme
name, the old format, still loads). The "memory count" segment shows
project-scoped memory files for the current directory (cached by mtime, free
per-prompt).


### Terminal integration (OSC 133 / OSC 7 / DEC 2026)

`zsh/term-integration.zsh`. All non-printing; a terminal that doesn't
implement a sequence ignores it.

| Sequence | What it buys |
|---|---|
| `OSC 133 A/B` | marks prompt start and end-of-prompt, emitted inside `$PROMPT` |
| `OSC 133 C` | marks where command output begins (preexec) |
| `OSC 133 D;code` | marks command end with its exit status |
| `OSC 7` | reports cwd, so a new tab or split opens here instead of `~` |
| `DEC 2026` | brackets the async HUD repaint into one atomic frame |

In iTerm2 the marks feed prompt navigation, "Select Output of Last Command",
per-command status marks, and the command/directory history. Nothing about
them is visible — they are structure, not decoration. Defaults per iTerm2's
shell-integration documentation; the menu wins if these ever drift:

| Feature | Menu | Shortcut |
|---|---|---|
| Command History popup | Session → Open Command History… | `⇧⌘;` |
| Autocomplete | Session → Open Autocomplete… | `⌘;` |
| Recent Directories | Session → Open Recent Directories… | `⌥⌘/` |
| Next / Previous mark | Edit → Marks and Annotations | `⇧⌘↓` / `⇧⌘↑` |
| Select Output of Last Command | Edit menu | — |
| History panes | Toolbelt → Command History / Recent Directories | — |

Both popups fill from commands run *after* integration is active, so a tab
opened before the shell sent the handshake stays empty whatever you press.

Three traps, all of which cost real debugging:

- **`A` and `B` live inside `$PROMPT` and must be wrapped in `%{ %}`.** zsh
  counts every byte of the prompt toward the cursor column; an unwrapped
  escape miscounts and corrupts line editing the moment a command wraps.
- **`D` is emitted from the prompt's own precmd**, on the line after `$?`
  is captured. Not for the reason first documented here: zsh 5.9.2 hands
  *every* precmd hook the real `$?` — verified with two hooks where the
  first returns 7 and the second still sees the command's own 1. Keeping
  the capture and the emission adjacent is tidiness, not correctness.
- **`zsh/zupershell.zsh` gates its own 133/7 emitter on
  `TERM_PROGRAM=zupershell`**, which means it is inert in iTerm2 — that file
  buys nothing in a normal terminal. This one bails when zupershell is
  active so the two never double-mark.

DEC 2026 is emitted blind rather than probed with `DECRQM` (`ESC[?2026$p`):
an unsupported private mode is ignored, and querying would put up to 100ms
of latency into every shell start to learn something that costs 8 bytes to
assume. `ZT_SYNC=0` opts out.

Inside tmux, arbitrary OSC needs the passthrough envelope. tmux consumes
OSC 7 itself for `pane_current_path` and handles 133 natively in recent
versions, so these three work, but anything new should be checked there.

### Mouse reporting after a dropped ssh session

`zsh/mouse-guard.zsh`. tmux with `mouse on` asks the *terminal* for mouse
events by writing `\e[?1003h` / `\e[?1006h`. Over ssh those bytes change the
state of the terminal on **this** machine — the remote tmux only borrowed it.
A clean detach writes the matching resets; a dropped connection never does,
and the terminal keeps encoding pointer movement as keystrokes. ZLE eats the
`\e[<` prefix and types the rest, which is where `35;90;24M` on your command
line comes from (`35` = motion, `90` = column, `24` = row).

The hook remembers whether the last command was one that hands a remote or
containerized program control of the terminal — `ssh mosh et autossh tmux
docker kubectl claude-attach`, looking past `sudo`/`command`/`env` — and if
so writes the 36 bytes that clear every mouse mode when you get back to the
prompt.

```sh
fixterm                    # manual escape hatch, for leaks the hook can't see
```

It also fires if you `Ctrl-Z` an ssh session; a later `fg` comes back without
mouse reporting until the remote app redraws. Matching is on whole words, so
`sshuttle` and `git commit -m "ssh stuff"` don't trigger it.

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
