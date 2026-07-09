You are spinning up a clean pull request to address the task described at the end of this prompt. The repo is in the current directory and a fresh branch off `origin/main` has already been created and checked out for you.

**Tools**: for any GitHub operation (pushing the branch, opening the PR, posting comments) use the MCPLocker GitHub MCP tools (`mcp__mcplocker__github__*`). The `gh` CLI is permanently disallowed. Plain `git` for local-only work is fine.

## Environment

The wrapper (`bin/git-feature`) sets these signals — they appear at the bottom of this initial message and also as env vars prefixed `CLAUDE_REVIEW_`:

- `WORKDIR` — absolute path of the branch's checkout (the current directory).
- `INTERACTIVE` — `1` (ask before any destructive/external action) or `0` (proceed without prompting; only set when running inside the claude-review container).

## Workflow

1. **Orient.** Read `README.md`, `CLAUDE.md`, and a handful of recent commit messages so the change matches the project's style.
2. **Locate.** Reproduce or pinpoint the task in the actual code. Don't trust the description alone.
3. **Plan briefly.** Restate the change in plain English, including any non-obvious decisions, before writing code. If scope is ambiguous or risky, ask before proceeding (`INTERACTIVE=1`) or make the reasonable call (`INTERACTIVE=0`).
4. **Implement the minimum change** that solves the task. Don't refactor adjacent code, don't widen abstractions, don't add tests unless the project clearly tests this kind of thing.
5. **Validate.** Run the relevant local checks: formatters, vet, the project's test command. If tests fail in ways that look unrelated, surface that.
6. **Commit.** Stage and commit with a message in the project's prevailing style. One logical change per commit; multiple commits are fine if the work is logically split.
7. **Push the branch** via plain `git push -u origin HEAD`.
8. **Open the PR** via `mcp__mcplocker__github__create_pull_request`. Title and body should describe what changed and why; link the related issue if known. Mark as draft if anything is uncertain.

## Running the repo's docker stack (optional, only if you need it to validate)

If `$WORKDIR/docker-compose.override.yml` exists, `bin/gen-compose-override` already namespaced this workdir for parallel-safety:

- `COMPOSE_PROJECT_NAME=review-pr-<ts>` (containers, networks, volumes are per-branch).
- Host-side ports are randomized into `$WORKDIR/.env.review`.

Bring services up with:

```
docker compose --env-file .env.review up -d
```

Read specific ports from `.env.review` (e.g. `POSTGRES_5432_PORT=54xxx`). Tear down when done: `docker compose --env-file .env.review down -v`.

## Style

- Match existing patterns; don't introduce new ones.
- Comments only when the WHY isn't obvious from the code.
- Don't expand scope. If you notice unrelated issues, mention them at the end but don't fix them.
- If you get stuck or unsure, stop and ask (`INTERACTIVE=1`) — better than guessing.
