# `git-feature` — spin up a new feature or bug-fix branch, containerized

Symmetric to `git-review`: `git feature "<description>"` mirrors
`git review <pr>`. Creates a fresh branch off `origin/main`, opens a
tmux session with an AI-generated name, and starts Claude inside the
`claude-review:local` container with `claude/prompts/make-pr.md` as
the initial message.

`bin/pr-spin` is a back-compat symlink to `bin/git-feature`.

## Table of contents

- [Quickstart](#quickstart)
- [Flags](#flags)
- [How the pieces fit together](#how-the-pieces-fit-together)
- [tmux session naming](#tmux-session-naming)
- [Container mounts and safety model](#container-mounts-and-safety-model)
- [Compose port randomization](#compose-port-randomization)
- [Customizing the make-pr prompt](#customizing-the-make-pr-prompt)
- [Troubleshooting](#troubleshooting)

## Quickstart

```sh
# Cwd repo, defaults (container + compose override + interactive)
git feature "validate email length before save"

# By local path
git feature ~/go/src/.../some-repo "remove unused redis client"

# By owner/repo — resolves to ~/go/src/github.com/<owner>/<repo>
git feature owner/repo "remove unused redis client"

# By full URL — same resolution
git feature https://github.com/owner/repo "…"

# Pick a model
git feature "add pagination to /users" --model claude-opus-4-8

# No container (old on-host behavior)
git feature "quick typo fix" --no-docker

# Don't refuse on a dirty tree (rare — usually you want the refusal)
git feature "…" --allow-dirty
```

**Two resolution modes:**

| Spec form                          | Mode          | Where it works                                                                                     |
|------------------------------------|---------------|----------------------------------------------------------------------------------------------------|
| No spec (cwd)                      | in-place      | The current directory. Must be a git checkout. Dirty check enforced.                              |
| Local path (e.g. `~/some/repo`)    | in-place      | That directory. Dirty check enforced.                                                             |
| `<owner>/<repo>` or `<github-url>` | **agent-work**| Fresh clone at `~/agent-work/<owner>/<repo>-<random>`. Each run isolated. Dirty check N/A.        |

**Agent-work model.** URL / owner-repo specs never touch your canonical
checkout. A fresh clone goes into `~/agent-work/<owner>/<repo>-XXXXXX`
(via `mktemp -d`, six random alphanumerics). Each run gets its own real
git checkout — not a git worktree, so `.git/` isn't shared and there's
nothing to `git worktree remove` later. Cleanup is `rm -rf` on the dir.

**Local-reference optimization.** If a canonical checkout exists on
disk (searched in this order: `~/go/src/github.com/<owner>/<repo>` →
`~/Projects/<repo>` → `~/src/github.com/<owner>/<repo>` →
`~/code/<owner>/<repo>` → `~/repos/<repo>`), it's passed as
`git clone --reference-if-able` so most objects come from your local
disk via hardlinks instead of the network. When no reference exists,
falls back to a `--depth 100` shallow clone.

Either way, the clone's `origin` points at github, so `git push` works.

**Cleanup.** `~/agent-work/` grows over time. Prune with:
```sh
find ~/agent-work -mindepth 2 -maxdepth 2 -type d -mtime +14 -exec rm -rf {} +
```
(everything older than two weeks). No auto-cleanup — you're in charge.

## Flags

| Flag                    | Default          | Effect                                                                                                            |
|-------------------------|------------------|-------------------------------------------------------------------------------------------------------------------|
| `--no-docker`           | container on     | Skip the `claude-review` container; run Claude on the host.                                                        |
| `--no-compose-override` | override on      | Skip generating `docker-compose.override.yml`.                                                                    |
| `--interactive`         | on (default)     | Claude asks before pushing/opening a PR.                                                                          |
| `--no-interactive`      | off              | Prompt-side: skip confirmations Claude asks about (per `make-pr.md`). Does not itself grant tool permissions.     |
| `--yolo`                | **off**          | Add `--dangerously-skip-permissions` to the claude call. **Explicit opt-in.** Container sandbox is your safety net when enabled. |
| `--model <id>`          | (claude default) | Pass a specific model id (e.g. `claude-opus-4-8`).                                                                |
| `--allow-dirty`         | refuse on dirty  | Skip the "uncommitted changes" refusal. Rare; usually you want the refusal.                                       |

## How the pieces fit together

```
$ git feature "<description>"
    │
    ├── slugify → branch name (feat/<slug>-<unix-ts>)
    ├── git fetch origin main
    ├── git checkout -b <branch> origin/main
    │
    ├── bin/gen-compose-override               (only if compose file present + docker+jq installed)
    │     └── writes .env.review + docker-compose.override.yml
    │
    ├── claude -p --model claude-haiku-4-5 "…" (session-name generator; slug fallback on failure)
    │
    └── tmux new-session -s <ai-name> -c <repo>
          └── (inside pane) claude-in-docker --workdir <repo> -- "<make-pr.md + task>"
                └── exec docker run …  (see git-review docs for mount list)
```

**Files involved**

| Path                                   | Role                                                                     |
|----------------------------------------|--------------------------------------------------------------------------|
| `bin/git-feature`                      | Entrypoint. Parses flags, creates the branch, launches tmux.             |
| `bin/pr-spin`                          | Symlink → `git-feature` (back-compat).                                   |
| `bin/claude-in-docker`                 | Container wrapper — shared with `git-review`.                            |
| `bin/gen-compose-override`             | Port randomizer — shared with `git-review`.                              |
| `docker/claude-review/Dockerfile`      | Container image — shared with `git-review`.                              |
| `claude/prompts/make-pr.md`            | The initial prompt Claude receives.                                      |

## Branch slug + tmux session naming

Old `pr-spin` used a naive slugify: for a long description you'd get
`feat/we-need-to-explore-workflow-and-tool-use-should-t-<ts>` — truncated
mid-word, no summary of intent.

`git-feature` now makes ONE call to Claude Haiku that returns both a
meaningful branch slug and a short session name:

```sh
$ git feature "we need to explore whether tools should have descriptor cards or route through an agent"
→ Asking Haiku for a branch slug + session name
→ Branch:  feat/tool-descriptor-vs-agent-routing-1704812345
→ Session: tool-routing
```

The prompt asks for two lines: `BRANCH:` (3–6 words) and `SESSION:`
(2–4 words), kebab-case only. Both lines are sanitized (only
`[a-z0-9-]`, capped at 48 / 40 chars respectively) and if the tmux
session name already exists, suffixed with the slug head.

**Fallback**: if `claude -p` fails or returns unparseable output, the
slug reverts to naive `[^a-z0-9]+ → -` slugify, and the session falls
back to `<repo-basename>-<slug-head>`. You always get *some* branch.

**Skip the Haiku call**: run `PATH=/tmp:$PATH git-feature "…"` — the
CLI check fails and the naive slugify path runs. Or accept the ~1-second
cost; it's usually worth it.

## Dirty-tree refusal

**In-place mode only.** When you pass a local path or use cwd, an
uncommitted working tree would follow you onto the new branch.
`git-feature` refuses to run if `git status --porcelain` returns
anything non-empty, printing the current status and telling you to
commit / stash / restore.

Bypass with `--allow-dirty` if you deliberately want to carry
uncommitted work over.

**Agent-work mode** skips the check — the clone is fresh, so it's
always clean by construction.

## Container mounts and safety model

Identical to `git-review` — see [`docs/git-review.md`](git-review.md#container-mounts-and-safety-model)
for the full mount table. The one difference: the `$workdir` is the
repo you're working in (typically `~/go/src/github.com/…/<repo>`),
not a `/tmp` checkout. So changes are *not* ephemeral by default —
they persist to your working tree, and the branch you're on when
Claude exits is the branch it was working on.

**Practical implication**: if you `--no-interactive`, Claude may
`git push -u origin HEAD` and open the PR without confirming. That's
the point; just be sure that's what you want.

## Compose port randomization

Same mechanism as `git-review`. Sees `docker-compose.y{,a}ml` or
`compose.y{,a}ml` in the repo, runs `gen-compose-override` with a
"PR number" derived from the branch's unix-timestamp tail (so
parallel branches don't collide).

See [`docs/git-review.md`](git-review.md#compose-port-randomization)
for the details.

## Customizing the make-pr prompt

Lives at `claude/prompts/make-pr.md`. Read fresh on every invocation.
Same edit-and-rerun cycle as the review prompt.

**What each section controls**:

| Section                                | Effect                                                                        |
|----------------------------------------|-------------------------------------------------------------------------------|
| First 4 lines                          | Role + tool allow-list. Reiterates: no `gh` CLI.                              |
| `## Environment`                       | Documents `WORKDIR`, `INTERACTIVE` for Claude.                                |
| `## Workflow`                          | 8-step flow: orient → locate → plan → implement → validate → commit → push → PR. |
| `## Running the repo's docker stack …` | How Claude should use `.env.review` + the override.                           |
| `## Style`                             | Tone. Restrict/loosen as needed.                                              |

## The three-pane tmux layout

`git-feature` builds a session with three panes on hand-off:

```
+-----------------------+------------------+
|                       |  compose logs    |
|      claude           |  (pane 2)        |
|      (pane 0)         +------------------+
|                       |  container shell |
|                       |  (pane 2, right) |
+-----------------------+------------------+
```

- **Pane 0 (left, main)** — the wrapped `claude-in-docker` launcher.
  This is where you interact with Claude. When the command exits, the
  pane drops into your shell so you can see any error output.
- **Pane 1 (top-right)** — `docker compose --env-file .env.review logs -f`
  in a retry loop. It idles until a compose service starts, then
  streams logs. Falls back to a shell message if no compose override
  was generated.
- **Pane 2 (bottom-right)** — a shell **inside** the running claude
  container (`docker exec -it claude-review-<session> bash`). Waits
  up to 60s for the container to appear, then execs in. Use this
  when you want to poke at the container's environment: install a
  missing MCP dependency, inspect mounts, run `claude mcp list`,
  check `ssh-add -l` for the 1Password agent, etc. Falls back to a
  host shell if the container never comes up.

Pane borders show titles (`claude` / `compose logs` / `container shell`)
if your tmux is new enough for `pane-border-status`.

Default focus starts on the claude pane. Move with `Ctrl-B` + arrow
keys.

## Watching a running session

`git-feature` prints the tmux session name + reattach commands before it
hands off. Copy them from your scrollback:

```
→ tmux session: tool-routing
→ To reattach from any other terminal: tmux attach -t tool-routing
→ To peek without stealing the session: tmux attach -r -t tool-routing
→ Haiku debug log:                     /tmp/git-feature-haiku-12345.log
```

- **From the current terminal**: you were attached automatically. If you
  got kicked back to a shell prompt in the pane, the wrapped launcher
  has kept the pane alive — anything Claude or docker printed is in
  scrollback. Type `exit` (or Ctrl-D) to close.
- **From another terminal**: `tmux attach -t <name>`. Two people can
  attach at once — you'll both see the same thing.
- **Read-only peek**: `tmux attach -r -t <name>`. No keystrokes get
  through to Claude; use it if you just want to watch progress.
- **List active sessions**: `tmux ls`.
- **Detach without killing**: `Ctrl-B d` (default tmux prefix).

## Getting prompted (Claude asks a question, docker asks for confirmation, etc.)

The tmux pane is a full TTY. Any interactive prompt from Claude, docker,
git, or your ssh agent is passed through and you can respond as normal.

If you weren't attached when the prompt appeared, `tmux attach -t <name>`
brings you into the same live pane — the prompt is right there waiting.

## Pane stays open on exit

The launch command is wrapped so that when Claude (or claude-in-docker)
exits — success or crash — the pane drops into your login shell inside
the same workdir, and prints:

```
[exited with status N — pane kept open. Ctrl-D or type exit to close.]
```

That means: you can always see what happened, even if Claude died
instantly. `cd`, `ls`, `git status` — poke around, run `docker logs …`,
whatever. Ctrl-D closes the pane and the session ends.

## Debugging the Haiku slug/session call

If the branch name or session name looks wrong (e.g. reverted to the
naive slug or `<repo>-<random>`), Haiku either failed or returned
something unparseable. Its raw stdout + stderr is saved to
`$TMPDIR/git-feature-haiku-<pid>.log` — the path is printed as
`→ Haiku debug log: …` before tmux takes over. `cat` it to see what
happened.

Common causes: `claude -p --model claude-haiku-4-5` isn't a valid
invocation for your CLI version, or the model id has drifted. Update
`bin/git-feature`'s `gen_slug_and_session` accordingly.

## Commit signing with 1Password

Three cooperating pieces make this work:

1. **SSH agent socket forwarding — SAME-PATH mount.**
   `bin/claude-in-docker` auto-detects 1Password's SSH agent socket at
   `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`
   and bind-mounts it at the **literal same path** inside the container,
   with `SSH_AUTH_SOCK` set to that path.

   Why same-path (not `/tmp/ssh-agent.sock`)? Your `~/.ssh/config`
   contains an explicit `IdentityAgent ~/Library/Group Containers/…`
   line. SSH honors that OVER `SSH_AUTH_SOCK`. If we remap the socket
   to a different path, the `IdentityAgent` line points at a
   non-existent file inside the container and SSH errors out with
   "No such file" or falls back and gets permission-denied. Mounting
   at the identical path means the same host `.gitconfig` +
   `.ssh/config` chain resolves verbatim — the container uses the
   exact same identity flow that works on your Mac.

   The stock macOS Keychain socket at
   `/var/run/com.apple.launchd.*/Listeners` is deliberately skipped —
   it can't proxy 1P keys into a Linux container.

2. **`gpg.ssh.program` override.** Your `~/.private/gitconfig` sets:

   ```gitconfig
   [gpg "ssh"]
       program = /Applications/1Password.app/Contents/MacOS/op-ssh-sign
   ```

   That binary is macOS-only. `claude-in-docker` passes
   `GIT_CONFIG_PARAMETERS="'gpg.ssh.program=ssh-keygen'"` into the
   container to override it back to the git default. `git commit -S`
   then calls `ssh-keygen -Y sign`, which talks to the forwarded 1P
   agent — 1Password prompts on your host to unlock the key, and the
   commit gets signed.

3. **Everything else you already had.** Your `~/.gitconfig` and
   `~/.private/gitconfig` are RO-mounted, so `user.signingkey`,
   `commit.gpgsign`, `tag.gpgsign`, `gpg.format = ssh`, and any
   `[includeIf]` overlays apply verbatim.

Verify inside the container (pane 2 — the container shell):

```sh
# 1. Socket forwarding works
ls -la "$SSH_AUTH_SOCK"           # should show the 1P socket at its
                                  #   ~/Library/Group Containers/… path
ssh-add -l                        # 1P should list your signing key(s)

# 2. Git config sees SSH signing + our program override
git config --get gpg.format       # ssh
git config --get gpg.ssh.program  # ssh-keygen (from GIT_CONFIG_PARAMETERS)
git config --get user.signingkey  # your ssh-rsa/ecdsa pubkey blob

# 3. End-to-end: empty signed commit
cd "$CLAUDE_REVIEW_WORKDIR"
git commit --allow-empty -m "test signing" -S
git log -1 --show-signature       # should say "Good signature"

# 4. End-to-end: SSH connect to github
ssh -T git@github.com             # should say "Hi <you>! You've successfully authenticated"
```

The 1Password app pops up on your host desktop on the first signing
call to authorize. If it never pops up — the socket isn't reaching the
container. Check Docker Desktop's file-sharing settings: `~/Library/`
must be on the shared paths list (it is by default on modern Docker
Desktop for Mac).

**If verification fails**, the culprit is usually one of:
- Docker Desktop needs to be granted **Full Disk Access** in
  macOS System Settings → Privacy & Security so it can reach the App
  Sandboxed Group Containers path.
- 1Password → Developer settings → **Use SSH agent** must be enabled.
- 1Password's SSH agent settings must have the key you use for github
  loaded and authorized for signing.

## iTerm2 status-line hook (`cc-status`)

Your host `~/.claude/settings.json` wires up every Claude event
(`PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`, …) to run
`/Users/duppster/.config/iterm2/cc-status` — a macOS Mach-O binary
shipped with iTerm.app that updates iTerm2's status line. It can't
run in the Linux container, and every tool call would print
`/bin/sh: … cc-status: not found` into the claude pane.

`bin/claude-in-docker` bind-mounts a no-op stub over that exact path
inside the container:

```
docker/claude-review/cc-status-stub  →  ~/.config/iterm2/cc-status  (ro)
```

The hooks still fire, the stub exits 0 silently, and Claude's output
stays clean. The trade-off: iTerm2's status line isn't updated from
inside the container. If that matters, run with `--no-docker` for the
session (Claude on host → real cc-status runs) or write a portable
replacement.

## Persisting Claude Code state across container runs

Claude Code splits its state across several files. `bin/claude-in-docker`
mounts each so container runs pick up the same account, trust decisions,
and MCP approvals your host session has.

| Path                           | Mount | Holds                                                                |
|--------------------------------|-------|----------------------------------------------------------------------|
| `~/.claude/`                   | RW    | Settings, hooks, plugins, memory, MCP config, project scratch dirs.  |
| `~/.claude/.credentials.json`  | RW    | (inside `~/.claude`) OAuth token — Claude Code's Linux fallback.     |
| `~/.claude.json`               | RW    | Top-level state: `oauthAccount`, `machineID`, `hasCompletedOnboarding`, per-project `hasTrustDialogAccepted` / `enabledMcpjsonServers`. |

**Why both `~/.claude/` and `~/.claude.json`?** They're separate paths.
`~/.claude/` (directory) holds the settings/hooks/plugins tree. But
`~/.claude.json` (a single file at HOME root) is where the CLI writes
identity + per-project trust. Missing that mount = every container run
is a "first run" → onboarding wizard → OAuth sign-in URL → theme picker.

**macOS Keychain isn't reachable inside the container.** On the host,
Claude Code stores your OAuth token in the Keychain
(`security find-generic-password -s "Claude Code-credentials"`). Inside
the container (Linux) it can't reach the Keychain, so it uses the file
fallback at `~/.claude/.credentials.json`. Once you've signed in from
inside the container once, that file has a valid token and subsequent
runs reuse it silently.

## Skipping Claude's startup prompts

By default a fresh Claude Code session in a new directory asks three
things before it starts responding:

1. "**Is this a project you created or one you trust?**" — the trust dialog.
2. "**New MCP server found in this project: `<name>`. Use this MCP server?**" — one per MCP declared in the workdir's `.mcp.json`.
3. "**WARNING: Claude Code running in Bypass Permissions mode**" — the `--dangerously-skip-permissions` acknowledgement.

Because `git-feature` clones each session into
`~/agent-work/<owner>/<repo>-<random>`, that path is *new* every time,
so Claude has no memory of your previous trust/MCP decisions.
`git-feature` fixes this by pre-populating the answers before launching:

```jsonc
// ~/.claude.json — merged in-place per invocation
"projects": {
  "/Users/you/agent-work/<owner>/<repo>-XXXXXX": {
    "hasTrustDialogAccepted": true,
    "hasClaudeMdExternalIncludesApproved": true,
    "hasClaudeMdExternalIncludesWarningShown": true,
    "projectOnboardingSeenCount": 1,
    "enabledMcpjsonServers": ["playwright", …]   // names read from $repo/.mcp.json
  }
}
```

And `bin/claude-in-docker` adds `--add-dir "$workdir"` on the claude
invocation as a belt-and-suspenders trust hint.

**The bypass-mode warning** (prompt 3) is controlled by
`skipDangerousModePermissionPrompt: true` in `~/.claude/settings.json`
— your host already has this set, and the file is mounted RW into
the container. If the warning still appears inside the container
(some Claude Code versions tie acceptance to `machineID`, which
differs in the container), swap the flag in `bin/claude-in-docker`:

```diff
-run+=("$IMAGE" claude --dangerously-skip-permissions --add-dir "$workdir")
+run+=("$IMAGE" claude --permission-mode bypassPermissions --add-dir "$workdir")
```

`--permission-mode bypassPermissions` has the same runtime effect as
`--dangerously-skip-permissions` but doesn't force the acknowledgement
dialog.

## Docker socket access from inside the container

The `/var/run/docker.sock` bind-mount is `root:root 0660` inside the
container (Docker Desktop's default). Since our process runs as your
host uid/gid (501:20) with no supplementary groups by default, that
mode denies access → `docker` commands inside fail with EACCES.

Fix: `bin/claude-in-docker` passes `--group-add 0` to `docker run`,
which gives the container process **group 0 (root) as a supplementary
group**. That grants the group-read/write bit on the socket without
requiring root privileges or a `docker` group inside the image. Host
group membership is unchanged.

Verify inside pane 2:

```sh
id                                # should show groups=20(...) 0(root)
docker info                       # should succeed
docker compose --env-file .env.review up -d
```

## MCP tools inside the container

`~/.claude` is mounted read-write into the container. Claude Code
picks up MCP server config from there just like on the host, and
cached auth tokens (e.g. MCPLocker's OAuth) transfer over.

**First-time auth caveat:** if a specific MCP server has never been
authenticated on this machine, its OAuth flow may require a browser
round-trip that doesn't work headless inside the container. Fix:

1. Run one interactive session on the **host** first
   (`git feature "..." --no-docker`).
2. Complete the MCP auth in the browser as prompted.
3. Retry in the container — cached tokens under `~/.claude` are now
   accessible.

**Verify inside the container** (pane 2):

```sh
claude mcp list                    # servers Claude is aware of
claude mcp status                  # per-server connect state
```

**Common runtime deps** are baked into the image: `node`, `npm`,
`npx` (JS-based MCPs), `python3`, `pip`, `pipx` (Python-based MCPs),
`git`, `curl`, `jq`. For anything else, install it from pane 2
(the container shell) — it lives only for that session because
`docker run --rm`.

**Private npm registry.** If `~/.npmrc` exists on the host,
`bin/claude-in-docker`:

- Passes it as a BuildKit secret when building the image
  (`docker build --secret id=npmrc,src=$HOME/.npmrc …`) so
  `npm i -g @anthropic-ai/claude-code` can authenticate to the private
  registry during build. The secret is mounted only for that one
  `RUN` step and is never baked into a layer.
- Mounts it read-only at `~/.npmrc` inside the container at runtime,
  so any `npx <private-pkg>` MCP servers can authenticate too.

**`ignore-scripts=true` in `~/.npmrc` breaks the postinstall.** The
Dockerfile passes `--ignore-scripts=false` on the `npm install` call
so the vendor postinstall — which downloads the platform-native
`claude` binary — actually runs. Without this the image builds fine,
but `claude` inside errors with:

```
Error: claude native binary not installed.
Either postinstall did not run (--ignore-scripts, ...) or the
platform-native optional dependency was not downloaded (--omit=optional).
```

The Dockerfile also re-runs the postinstall manually as a safety
net and finishes with `claude --version` so the build fails loudly
if the CLI is broken instead of producing a silently-bad image.

If the initial build failed with `ECONNREFUSED` against
`registry.npmjs.org`, that was the missing secret mount — pull latest
and rebuild:

```sh
docker rmi claude-review:local 2>/dev/null
git feature <spec> "…"   # lazy-rebuilds with the secret
# or build explicitly:
DOCKER_BUILDKIT=1 docker build --secret id=npmrc,src=$HOME/.npmrc \
    -t claude-review:local ~/.dotfiles/docker/claude-review/
```

## Troubleshooting

**Claude Haiku session-name call is slow / hangs**
It's one CLI round-trip; usually <2s. If it hangs, Ctrl-C — `git-feature`
will fall back to the slug-based name and continue.

**tmux session name has weird characters**
The sanitizer strips everything but `[a-zA-Z0-9-]`. If Haiku returns
punctuation or emoji, it gets stripped. If the result ends up empty,
falls back to the slug.

**Container fails on macOS Docker Desktop with "socket permission denied"**
Docker Desktop's socket may need a permission bump. Restart Docker
Desktop, or fall back to `--no-docker` for the one task.

**"Not a git repo" error**
`git-feature` refuses to run if the target isn't a git checkout with
`.git/`. If you meant to bootstrap a new repo, do `git init` first.

**Clone into agent-work failed**
Usually network / auth. If a local reference existed it was passed to
`git clone --reference-if-able`, so falling back to a direct
`git clone https://github.com/<owner>/<repo>.git` in a scratch dir will
show the real error. Once you know why, retry `git-feature`.

**"'…' has uncommitted changes"**
Commit, stash, or restore first. Or `--allow-dirty` if you know what
you're doing.

**Wanted to keep pr-spin**
It's still there — `bin/pr-spin` is a symlink to `bin/git-feature`.
Muscle memory works.

**MCP tools fail inside the container**
See [`docs/git-review.md`](git-review.md#troubleshooting) — same
mitigation (re-auth on host with `--no-docker`, retry containerized).
