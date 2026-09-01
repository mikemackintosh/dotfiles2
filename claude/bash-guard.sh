#!/usr/bin/env bash
# bash-guard.sh — a PreToolUse gate on Bash for the command shapes that keep going wrong.
#
# WHY THIS EXISTS. Three incidents in one session, all in the same shape: a throwaway command
# written in service of some other goal. A `|| cp` backup that fell through and left two
# deliberate breakages in a config; a `vitest | grep && git commit` whose grep masked a failing
# test so a commit landed on red; a `git stash -u` that swallowed uncommitted work.
#
# None of them was ignorance — every one is named in a CLAUDE.md. The rules fire when you are
# thinking about the topic, and these were written while thinking about something else. So the
# trigger has to be SYNTACTIC (does the string contain `stash`) rather than semantic (is this
# risky), because the judgement is exactly what is missing in that moment.
#
# Reads the PreToolUse payload on stdin, prints a decision, exits 0 either way. Silence = no
# opinion; the command proceeds through normal permissions.

set -uo pipefail

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# Strip single- and double-quoted runs before matching, so an echo or a grep pattern that merely
# NAMES one of these does not trip the guard. Crude but it kills the common false positive.
bare=$(printf '%s' "$cmd" | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g')

decide() { # decide <deny|ask> <reason>
  jq -nc --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  exit 0
}

# ── Always wrong, because a clean alternative exists ────────────────────────────────────

# `git stash` — it moves work somewhere you will forget to look. Git is already the backup.
if grep -Eq '(^|[;&|]|\s)git\s+stash\b' <<<"$bare"; then
  decide deny "git stash hides uncommitted work somewhere easy to forget — it swallowed a file's worth of work this way. Commit it instead (a WIP commit is free and amendable), then use git checkout HEAD -- <path> to restore. If you truly need a stash, say so and run it yourself."
fi

# `cmd || cp/mv` — the fallthrough backup. When the first arm succeeds the fallback never runs,
# so the restore that references it fails and leaves the edit in place.
if grep -Eq '\|\|\s*(cp|mv)\b' <<<"$bare"; then
  decide deny "A backup behind || only exists when the first command FAILS, so the restore afterwards silently has nothing to restore from — that left two deliberate breakages in a config file. Do not shell-backup at all: commit first, then git checkout HEAD -- <path> to restore."
fi

# A pipeline feeding && a state-changing command. The pipeline reports its LAST stage, so the
# mutation runs even when the real command failed.
if grep -Eq '\|[^|]+&&' <<<"$bare" &&
   grep -Eq '&&[^&]*\b(git\s+(commit|push|merge|rebase|reset|checkout|tag)|rm|mv|cp|docker\s+(rm|rmi|volume)|kubectl\s+(delete|apply)|npm\s+publish)\b' <<<"$bare"; then
  decide deny "A pipeline reports its LAST stage, so a grep/head after the real command masks its exit status and the && still fires — that is how a commit landed on a red test suite. Run the command on its own line and check \$? (cmd > /tmp/out 2>&1; echo \$?), or set -o pipefail."
fi

# ── Sometimes right, never reflexive ───────────────────────────────────────────────────

if grep -Eq '(^|[;&|]|\s)git\s+reset\s+(--hard|--merge|--keep)\b' <<<"$bare"; then
  decide ask "git reset --hard discards uncommitted work irrecoverably. Confirm this is what you mean."
fi

# `git checkout HEAD -- <path>` is deliberately NOT gated: it is the restore idiom this guard
# pushes you toward (commit first, edit, restore from HEAD), and putting friction on the
# recommended path is how you end up back at ad-hoc `.bak` files — the thing being prevented.
# Bare `git checkout -- <path>` still asks: same effect, but it does not say what it restores TO.
if grep -Eq '(^|[;&|]|\s)git\s+checkout\s+--\s' <<<"$bare"; then
  decide ask "git checkout -- <path> discards that file's uncommitted changes without naming what it restores to. If you mean 'put it back to the last commit', say git checkout HEAD -- <path>, which is not gated."
fi

if grep -Eq '(^|[;&|]|\s)git\s+push\b[^;&|]*(--force\b|--force-with-lease\b|\s-f(\s|$))' <<<"$bare"; then
  decide ask "A force push rewrites remote history. Confirm the branch and that nobody else has it."
fi

if grep -Eq '(^|[;&|]|\s)rm\s+(-[a-zA-Z]*[rR][a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*[rR])' <<<"$bare"; then
  decide ask "rm -rf is irreversible and does not ask. Confirm the path is what you think it is."
fi

exit 0
