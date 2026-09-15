# CLAUDE.md — guidance for Claude working in this repo

Personal macOS dotfiles. Most code is small bash/zsh/awk; vim has
vendored plugins; git is configured via `.gitconfig` + `~/.private/`.

## House rules

These are non-obvious and have bitten us before — uphold them.

- **No `gh` CLI, ever.** `claude/settings.json` denies it. For
  GitHub operations use the `mcp__claude_ai_MCPLocker__github__*`
  MCP tools. Plain `git` is fine.
- **Pure shell, no plugin managers, no starship.** The prompt
  (`zsh/prompt.zsh`) is hand-rolled because the user rejects
  starship-class deps for prompt/always-on shell code.
- **Vendor third-party deps as plain committed source, not
  submodules.** See `vim/pack/vendor/start/` and `vim/upgrade.sh` +
  `vim/vendor.lock`. Reason: security review of imported code.
- **Never commit personal identity.** `.gitconfig` is sanitized;
  identity comes from `~/.private/gitconfig` (and
  `~/.private/gitconfig-work` for wealthsimple paths) via
  `[include]` and `[includeIf]`. Don't move identity into the
  committed config.
- **Comments are sparse.** Code should be self-explanatory; comment
  only the non-obvious WHY (a workaround, a constraint, a
  surprising choice). No multi-paragraph docstrings.

## Layout

```
.zshrc .zprofile .gitconfig .hushlogin   → symlinked into $HOME
Brewfile                                  → brew bundle deps
README.md                                 → user-facing reference
bin/                                      → user scripts (on $PATH)
  memories                                  Claude memory browser/creator/grep
  tmux-sessionizer                          fzf project picker (prefix+T in tmux)
  git-review                                local PR review via /tmp + containerized claude
  git-feature                               new feature/bug branch + containerized claude in tmux
  pr-spin                                   back-compat symlink → git-feature
  claude-in-docker                          runs claude with narrow host mounts (safe --dangerously-*)
  codex-security                            npx codex-security + seccomp=unconfined (bwrap needs it)
  gen-compose-override                      randomizes docker-compose ports per PR/branch
  notify                                    osascript notification wrapper
  macos-defaults                            apply scrolling / cursor / Dock prefs
                                            (version-gated, macOS 12-26)
  iterm-themes                              import iterms/*.itermcolors into iTerm2
  docker-shim                               multi-call Docker shim; tool names
                                            (node/npm/pnpm/python3/ruby/…) symlink to it
claude/                                   → Claude Code config
  settings.json                             symlinked into ~/.claude/
  statusline.sh                             symlinked into ~/.claude/
  CLAUDE.md                                 symlinked into ~/.claude/ (global
                                            answer-style + shell rules)
  bash-guard.sh                             symlinked into ~/.claude/;
                                            PreToolUse Bash gate (see below)
  prompts/                                  workflow prompt templates
    security-review.md                        branded security-assessment report
docker/                                   → Dockerfiles built by our tools
  claude-review/                            base image for claude-in-docker
docs/                                     → per-tool deep-dive docs
  git-review.md, git-feature.md             ← start here to learn a tool
  android-skills.md                         Android/Frida lab cold-start runbook
githooks/                                 → global hooks (core.hooksPath)
  pre-commit                                gofmt + go vet on staged .go files
  pre-push                                  gitleaks on push
gitconfig.private.example                 → template for ~/.private/gitconfig
ssh-config.example                        → template for ~/.ssh/config
install.sh                                → idempotent symlink installer;
                                            `--check` audits state
iterms/                                   → iTerm2 color themes
tmux/tmux.conf                            → tmux config
vim/                                      → vimrc + vendored plugins
zsh/                                      → plugin files sourced by .zshrc
  prompt.zsh, prompt-themes.zsh             prompt engine + 15 themes/shapes
  kube.zsh                                  `k` — kubectl in Docker (+ `kconfig`)
```

## How to validate a change

Before committing any shell code:

```sh
zsh -n path/to/file.zsh         # syntax check zsh
bash -n path/to/file.sh         # syntax check bash
./install.sh --check            # symlinks + brew deps healthy
```

`./install.sh --check` will warn about missing brew deps — that's
expected on machines that haven't run `brew bundle`.

## Common pitfalls

- `git tag` without `-m` errors because `[tag] gpgsign = true` makes
  every tag annotated/signed. Use `git branch backup/...` for
  ephemeral safety refs instead.
- `gitleaks` runs on `git push`. False positives in vendored trees
  are allowlisted in `.gitleaks.toml`; for a one-off, add a
  `# gitleaks:allow` inline comment, never `--no-verify` silently.
- Docker is a hard dependency of half of `bin/`. Every docker-shim
  alias (`node`, `npm`, `python3`, `ruby`, …) plus `claude-in-docker`,
  `git-review`, `git-feature`, `codex-security` and the
  `chrome-devtools` MCP exit 127 without it. The Brewfile installs
  Docker Desktop and `install.sh --check` fails when it is absent —
  it used to report "all good" on a machine where none of them ran.
- Commits are SSH-signed with a key from 1Password. If `~/.private/`
  is missing, git has no identity at all and every commit fails;
  `install.sh` now reports that instead of leaving you to guess.
- A read-only **deploy key** in the 1Password agent can shadow your
  account key: ssh offers keys in agent order and stops at the first
  GitHub accepts, so pushes fail with "marked as read only" even
  though auth succeeded. `ssh -T git@github.com` answering
  `Hi owner/repo!` instead of `Hi username!` is the tell; pin the
  account key per `ssh-config.example`.
- `core.hooksPath = ~/.dotfiles/githooks` is global. If a repo
  needs its own hooks (rare), opt out with:
  `git config --local core.hooksPath .git/hooks`.
- `~/.dotfiles/bin` is on `$PATH` (set in `.zshrc`). Any new script
  there is auto-callable from anywhere; `install.sh` chmod's every
  real file in `bin/` by glob (skipping the docker-shim symlinks),
  so a new tool needs no edit to the installer.
- `install.sh` is `set -euo pipefail`. A pipeline whose first stage
  legitimately exits non-zero (`brew bundle check`, `dscl`) will
  kill the whole run — redirect to a file and read that, or append
  `|| true` to the assignment.
- `claude/bash-guard.sh` is a `PreToolUse` hook on Bash. It **denies**
  `git stash`, `… || cp/mv` fallback backups, and a pipe feeding `&&`
  into a state change; it **asks** on `reset --hard`, bare
  `git checkout -- <path>`, force-push and `rm -rf`. Matching is
  syntactic, on the command string with quoted runs stripped, so a
  command that merely names one of these does not trip it.

## Conventions for new tools

When adding a new bin/script:
1. Put it at `bin/<name>` with `#!/usr/bin/env bash` or `zsh`.
2. Header comment: one-line summary, usage block, brief example.
3. `install.sh` chmod's it automatically (glob over `bin/`) — no
   installer edit needed.
4. Mention it in `README.md` under "Tools in `bin/`".
5. If it has a Claude prompt template, drop it under
   `claude/prompts/` and read it from the script.
6. If it touches macOS system state, gate on `sw_vers -productVersion`
   rather than assuming the current release, refuse to run as root
   (sudo makes `$HOME=/var/root`), and skip-and-report instead of
   `exit 1` so one missing tool can't abort the rest.
