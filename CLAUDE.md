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
  git-review                                local PR review via /tmp + claude
  pr-spin                                   spin up a "PR making" session
  notify                                    osascript notification wrapper
  macos-defaults                            apply scrolling / cursor / Dock prefs
claude/                                   → Claude Code config
  settings.json                             symlinked into ~/.claude/
  statusline.sh                             symlinked into ~/.claude/
  prompts/                                  workflow prompt templates
githooks/                                 → global hooks (core.hooksPath)
  pre-commit                                gofmt + go vet on staged .go files
  pre-push                                  gitleaks on push
gitconfig.private.example                 → template for ~/.private/gitconfig
install.sh                                → idempotent symlink installer;
                                            `--check` audits state
iterms/                                   → iTerm2 color themes
tmux/tmux.conf                            → tmux config
vim/                                      → vimrc + vendored plugins
zsh/                                      → plugin files sourced by .zshrc
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
- `core.hooksPath = ~/.dotfiles/githooks` is global. If a repo
  needs its own hooks (rare), opt out with:
  `git config --local core.hooksPath .git/hooks`.
- `~/.dotfiles/bin` is on `$PATH` (set in `.zshrc`). Any new script
  there is auto-callable from anywhere; `install.sh` chmod's the
  ones it knows about.

## Conventions for new tools

When adding a new bin/script:
1. Put it at `bin/<name>` with `#!/usr/bin/env bash` or `zsh`.
2. Header comment: one-line summary, usage block, brief example.
3. Add `chmod +x` for it to the list in `install.sh`.
4. Mention it in `README.md` under "Tools in `bin/`".
5. If it has a Claude prompt template, drop it under
   `claude/prompts/` and read it from the script.
