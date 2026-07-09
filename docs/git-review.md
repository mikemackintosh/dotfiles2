# `git-review` — one-shot PR review, containerized, with optional auto-fix

Clones a GitHub PR into a fresh `/tmp` checkout, launches Claude inside
the `claude-review:local` container with `claude/prompts/review.md` as
the initial message, and lets Claude review — or (with `--fix`) apply
its own findings and push them.

## Table of contents

- [Quickstart](#quickstart)
- [Flags](#flags)
- [How the pieces fit together](#how-the-pieces-fit-together)
- [Container mounts and safety model](#container-mounts-and-safety-model)
- [Compose port randomization](#compose-port-randomization)
- [Fix mode routing](#fix-mode-routing)
- [Customizing the review prompt](#customizing-the-review-prompt)
- [Troubleshooting](#troubleshooting)
- [Extending](#extending)

## Quickstart

```sh
# Pre-build the container once (optional; claude-in-docker builds it
# lazily on first invocation otherwise).
docker build -t claude-review:local ~/.dotfiles/docker/claude-review/

# Review a PR — Claude prints findings, holds posting.
git review owner/repo 1234
git review https://github.com/owner/repo/pull/1234

# Pick a model.
git review <url> --model claude-opus-4-8

# Apply findings + push — Claude decides push-vs-stacked-PR.
git review <url> --fix

# Yolo (auto-post/push). Only sane inside the container (the default).
git review <url> --fix --no-interactive

# Old on-host behavior (no container).
git review <url> --no-docker
```

## Flags

| Flag                    | Default          | Effect                                                                                                            |
|-------------------------|------------------|-------------------------------------------------------------------------------------------------------------------|
| `--fix`                 | off              | Claude applies its own findings and pushes them (see [Fix mode](#fix-mode-routing)).                              |
| `--no-docker`           | container on     | Skip the `claude-review` container; run Claude on the host. Loses `--dangerously-skip-permissions` safety.        |
| `--no-compose-override` | override on      | Skip generating `docker-compose.override.yml`. Use if the PR's compose file fights the override.                  |
| `--interactive`         | on (default)     | Ask before posting, pushing, applying fixes.                                                                      |
| `--no-interactive`      | off              | Proceed without confirmation. **Only sane inside the container.**                                                 |
| `--model <id>`          | (claude default) | Pass a specific model id (e.g. `claude-opus-4-8`, `claude-sonnet-5`).                                             |

## How the pieces fit together

```
$ git review <owner>/<repo> <pr>
    │
    ├── mkdir /tmp/git-review-<repo>-<pr>.XXXXXX
    ├── git clone --depth=1 <repo>
    ├── git fetch pull/<pr>/head:pr-<pr>
    ├── git checkout pr-<pr>
    │
    ├── bin/gen-compose-override                (only if compose + docker + jq)
    │
    ├── build prompt file (task first, review.md, task reminder)
    │
    ├── pre-populate ~/.claude.json             (hasTrustDialogAccepted, MCP allow-list)
    │
    └── tmux new-session (3 panes, see below)
          │
          ├── pane 0  bin/claude-in-docker --workdir …   (interactive claude)
          │     └── docker run --rm -it --name claude-review-<workdir-suffix> …
          │
          ├── pane 1  docker compose logs -f (retry loop)
          │
          └── pane 2  docker exec -it <container> bash    (shell inside container)

    │  (background) tmux run-shell → wait for container, paste-buffer the
    │               prompt file into pane 0, send Enter to submit
```

**Three-pane layout** (same as `git-feature`):
- **Pane 0 (left, main)** — the wrapped claude launcher. Drops into your shell after claude exits; Ctrl-D there tears down the whole session.
- **Pane 1 (top-right)** — `docker compose --env-file .env.review logs -f` in a retry loop.
- **Pane 2 (bottom-right)** — `docker exec` shell inside the running claude container. Waits up to 60s for the container to appear.

**`--no-docker` still works the old way** — no tmux, single terminal, claude on the host with the prompt as a positional arg. Use this when you want the fastest possible spin-up and don't need the container sandbox.

**Files involved**

| Path                                   | Role                                                                     |
|----------------------------------------|--------------------------------------------------------------------------|
| `bin/git-review`                       | Entrypoint. Parses flags, clones/fetches/checks out the PR.              |
| `bin/claude-in-docker`                 | Assembles mounts, lazy-builds the image, execs `docker run`.             |
| `bin/gen-compose-override`             | Randomizes docker-compose ports + namespaces the project per PR.         |
| `docker/claude-review/Dockerfile`      | Container image: `node:22-slim` + git + ssh + docker CLI + `claude`.     |
| `claude/prompts/review.md`             | The initial prompt Claude receives (behavior lives here).                |

## Container mounts and safety model

The whole point of running Claude in a container is that
`--dangerously-skip-permissions` becomes safe by construction:
Claude can only touch what's mounted.

| Path                              | Mode | Why                                                                            |
|-----------------------------------|------|--------------------------------------------------------------------------------|
| `$workdir` (the PR checkout)      | rw   | Claude reads/edits/commits here.                                               |
| `~/.claude`                       | rw   | Settings, MCP config, memory writes.                                           |
| `~/.gitconfig`                    | ro   | Identity + `[includeIf]` overlays.                                             |
| `~/.private`                      | ro   | Work vs personal identity/config.                                              |
| `~/.ssh`                          | ro   | Private keys — needed to `git push` back to remotes.                           |
| `/var/run/docker.sock`            | rw   | Lets the container drive host Docker for `docker compose` inside the workdir.  |
| `$SSH_AUTH_SOCK`                  | rw   | Forwarded if set — for passphrase-protected keys.                              |

What's **not** mounted: `~/Documents`, `~/Downloads`, `~/go`, `~/Projects`,
`/etc`, the rest of `/tmp`, other users' homes, etc. Claude physically
cannot reach them.

**Blast radius of a mistake in fix mode**: the PR checkout in `/tmp`
(ephemeral) + a `git push`. The push is the only way changes leave the
box, which is why the prompt explicitly forbids `--force` and forbids
touching history Claude didn't create.

## Compose port randomization

`bin/gen-compose-override` is called from `git-review` whenever it sees
a `docker-compose.y{,a}ml` or `compose.y{,a}ml` in the workdir. It:

1. Runs `docker compose config --format json` to resolve the file
   (env-file expansion, `extends:`, anchors — all applied).
2. Parses `services.<svc>.ports[]`, picks a free host port in
   `49152–65535` per (service, container-port), verifies with
   `nc -z 127.0.0.1 <port>`.
3. Writes `.env.review`:
   ```
   COMPOSE_PROJECT_NAME=review-pr-<n>
   POSTGRES_5432_PORT=64735
   REDIS_6379_PORT=58754
   ```
4. Writes `docker-compose.override.yml` using the Compose v2.24+
   `!override` YAML tag to *replace* (not append to) each service's
   `ports:` list:
   ```yaml
   services:
     postgres:
       ports: !override
         - "${POSTGRES_5432_PORT}:5432"
   ```

**Bringing services up** inside the review:

```sh
docker compose --env-file .env.review up -d
# read a port:
grep POSTGRES_5432_PORT .env.review
docker compose --env-file .env.review down -v
```

**Requirements**: Docker Compose v2.24+ for the `!override` tag. The
generator silently skips if `docker` or `jq` aren't on `$PATH`, or if
`docker compose config` fails.

**Silent skip cases**:
- No compose file in the workdir.
- `docker` not on `$PATH`.
- `jq` not on `$PATH`.
- The base compose file fails `docker compose config` (usually a
  reference to an env var that isn't set).

Pass `--no-compose-override` if the auto-generated one is fighting a
repo-specific setup.

## Fix mode routing

`--fix` tells Claude in the prompt (see the `## Fix mode` section of
`claude/prompts/review.md`) to classify its own findings and route
accordingly.

**Nit-class** — push to the author's branch:
- Cumulative diff < ~30 changed lines.
- No new files.
- No new abstractions/functions/classes.
- No signature/API/exported-type changes.
- Confined to files already in the PR diff.

**Rearchitect-class** — open a stacked PR on your `origin`:
- Any nit-class rule violated.
- Anything that reshapes the design rather than fixing a defect.

Claude **prints the routing decision + rationale** before touching git.
In interactive mode it waits for you to confirm. In non-interactive
mode it proceeds.

**Rules Claude will not break**:
- No `--force`. Ever.
- No touching commit history Claude didn't create.
- If the author didn't enable "Allow edits from maintainers", nit-class
  push fails with 403 → Claude falls back to the stacked-PR path.

## Customizing the review prompt

The prompt lives at `claude/prompts/review.md` and is read fresh on
every `git review` invocation — no build, no cache, no restart. Edit
it, run again, done.

**What each section controls**:

| Section                                | Effect                                                                        |
|----------------------------------------|-------------------------------------------------------------------------------|
| First 4 lines                          | Role + tool allow-list. Reiterates: no `gh` CLI.                              |
| `## Environment`                       | Documents `WORKDIR`, `PR_URL`, `REVIEW_MODE`, `INTERACTIVE` for Claude.       |
| `## Workflow`                          | The 7-step review flow. Add/reorder steps here.                               |
| `## Running the PR's docker stack …`   | How Claude should use `.env.review` + the override.                           |
| `## Fix mode`                          | Nit-vs-rearchitect classification, routing procedure, hard rules.             |
| `## Style`                             | Tone. Adjust if the reviews are too/insufficiently blunt.                     |

**Per-run override**: `bin/git-review` currently hardcodes the prompt
path. If you want to point at another file per-run, wrap the `$PROMPT_FILE`
line in `${CLAUDE_REVIEW_PROMPT:-…}` and pass the env var. (Two-line
change; not wired by default.)

**Testing an edit** cheaply:
```sh
# Run against a tiny public PR; --no-docker so you don't pay the
# container spin-up latency for a quick prompt tweak.
git review <owner/repo> <pr> --no-docker
```
The prompt is the initial user message, so it echoes back verbatim
before Claude replies. If a section looks wrong, Ctrl-D and edit.

## Troubleshooting

**MCP tools fail inside the container**
```
Error: mcp__mcplocker__* not available
```
MCPLocker auth may need a first browser round-trip that only works on
the host. Run once with `--no-docker` on the host to re-auth, then
retry with the default (container). Auth caches under `~/.claude` and
is mounted RW. Node, npm/npx, python3, pip, and pipx are all present
in the image for JS/Python-based MCP servers.

**Commit signing (1Password)**
`bin/claude-in-docker` auto-detects 1Password's SSH agent socket at
`~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`
and forwards it as `SSH_AUTH_SOCK=/tmp/ssh-agent.sock` inside the
container. The stock macOS Keychain agent socket is skipped —
it can't proxy 1P's keys into Linux. See
[`docs/git-feature.md`](git-feature.md#commit-signing-with-1password)
for verification steps.

**`docker compose config` fails during override generation**
```
gen-compose-override: 'docker compose config' failed — skipping
```
Usually the PR's compose file references an env var that's not set in
the review workdir (`.env` missing, secret file missing). Two options:
1. Create the missing `.env` in the workdir before Claude uses it.
2. Pass `--no-compose-override` and manage ports manually.

**`docker compose up` fails: "port already in use"**
Race between the free-port check and the actual bind. Retry —
`gen-compose-override` picks new random ports on regeneration.

**Push fails with 403**
Author didn't enable "Allow edits from maintainers". Claude's prompt
tells it to fall back to the stacked-PR path automatically; if it
doesn't, tell it to.

**Image build is slow**
First run only. Pre-build with:
```sh
docker build -t claude-review:local ~/.dotfiles/docker/claude-review/
```

**Container can't reach the docker daemon**
Colima / Docker Desktop / Rancher Desktop each socket-mount differently.
The default `/var/run/docker.sock` works on Docker Desktop for Mac.
For Colima:
```sh
export CLAUDE_REVIEW_DOCKERFILE_DIR=~/.dotfiles/docker/claude-review
# and update bin/claude-in-docker's socket mount to $HOME/.colima/default/docker.sock
```

**Claude claims something needs a tool not in `~/.claude/settings.json`**
Update `claude/settings.json` (it's symlinked into `~/.claude/`).
Container reads it at container start via the RW `~/.claude` mount.

## Extending

**Add a flag**: parse it in the `while (( $# ))` loop in
`bin/git-review`, export a `CLAUDE_REVIEW_<name>` env var (`bin/claude-in-docker`
auto-forwards those), and reference it in `claude/prompts/review.md` under
`## Environment`.

**Change the image**: edit `docker/claude-review/Dockerfile`, then
```sh
docker build -t claude-review:local ~/.dotfiles/docker/claude-review/
```
Or set `CLAUDE_REVIEW_IMAGE=<other-tag>` before running to point at a
different tag entirely.

**Widen/narrow mounts**: edit `bin/claude-in-docker` — the mount block
is a plain array right after the `run=(run --rm -i)` line.

**Add a compose override behavior**: `bin/gen-compose-override` is a
plain bash script; add new stanzas to the emitted `.env.review` or
override YAML from there.
