# git-identity — which 1Password key signs and pushes, where

Every SSH key lives in 1Password. Its agent serves them to `ssh`, to
`ssh-keygen -Y sign` (commit signing) and, forwarded, to the review
containers. That leaves two questions no file in this repo can answer,
because the answer differs per Mac and per repo:

1. **Which key signs commits, and as whom?** A work Mac signs as the
   work address with the work key. A personal Mac signs as the personal
   address. One Mac that holds both needs the work identity only under
   the work checkout path.
2. **Which key does ssh offer GitHub first?** The agent offers every key
   it holds, in its own order, and GitHub accepts the first one it knows.
   If that is a repo deploy key, auth succeeds and every push fails with
   `marked as read only`.

`git-identity` answers both from a picker fed by `ssh-add -L`, and writes
the answers to untracked, per-machine files. Public material only. It
never touches `~/.ssh`.

## The two scopes

**Base** — this machine's default identity.

| writes | what |
|---|---|
| `~/.private/gitconfig` | `user.name`, `user.email`, `user.signingkey` (public key text), `gpg.format = ssh`, `gpg.ssh.program = bin/git-ssh-sign` (only if unset, a placeholder, or a hard `op-ssh-sign` path) |
| `~/.config/1Password/ssh/agent.toml` | the keys this Mac's agent may offer, push key first, then the signing key, then whatever else you chose to keep |
| `~/.config/git/allowed_signers` | `email key` line so your own commits verify locally |

**Overlay** — identity for repos under one directory, via
`includeIf "gitdir:DIR/"`.

| writes | what |
|---|---|
| `~/.private/gitconfig-NAME` | `user.*` for that path; optionally `core.sshCommand` |
| `~/.private/NAME.pub` | only if you picked a per-path push key (see below) |
| `~/.private/gitconfig` | the `includeIf` line, unless the tracked `.gitconfig` already includes that exact file for that dir |
| `allowed_signers` | the overlay's email + key |

Overlay mode never edits `agent.toml`. Which keys the agent offers is a
machine-level fact, not a path-level one.

## agent.toml is an allowlist

This is the sharp edge. The moment `agent.toml` exists, 1Password serves
**only** the items it lists. Base mode therefore asks which of the
remaining keys to keep, defaulting to all of them, and shows the plan
(`6 keys offered now → 3 after 1Password reloads`) before writing.

- It takes effect after 1Password relocks or restarts. `status` will
  keep reporting the old set until then.
- Items are matched by title. Two vault items with the same title are
  ambiguous; the picker flags them and leaves a `# vault = "…"` line to
  fill in.
- On a rerun the picker can only show what the agent currently offers.
  To re-add an excluded key, move `agent.toml` aside, relock 1Password,
  run `git-identity base` again.
- The previous file is kept as `agent.toml.bak-<timestamp>`.

Because it is per machine, this is also how the personal Mac never uses
the work key: leave it out of that Mac's list and the agent does not
have it to offer.

## Per-path push keys need a selector

Signing per path is free: git reads `user.signingkey` from the overlay
and asks the agent for that key. Pushing per path is not, because `ssh`
cannot see git paths. Overlay mode therefore offers two choices:

- **agent order** (default): pushes under this dir use whatever
  `agent.toml` puts first, same as everywhere else.
- **a specific key**: writes its *public* half to `~/.private/NAME.pub`
  and sets `core.sshCommand = ssh -o IdentitiesOnly=yes -o IdentityFile=~/.private/NAME.pub`
  in the overlay. ssh uses the public key to select the private one from
  the agent; nothing private touches disk.

A `.pub` selector is also the only way to pin a key per *host* in
`~/.ssh/config`. `ssh-config.example` keeps that block commented out:
with `IdentitiesOnly yes`, a missing `.pub` means ssh offers nothing and
every push dies with `Permission denied (publickey)`. `status` checks
for exactly that.

## Proof, not configuration

After writing, the picker signs a throwaway payload with the chosen key
(1Password prompts once) and runs `ssh -T git@github.com` with the push
key alone. `Hi <user>!` is an account key. `Hi <owner>/<repo>!` is a
deploy key and the picker says so. `Permission denied` means the key is
not registered under GitHub → Settings → SSH keys → Authentication.

`git-identity status` is what `install.sh --check` runs. It reports each
identity with the *name* of the key it signs with and whether the agent
currently offers it, every overlay `includeIf` declares, `agent.toml`'s
order, and any `IdentityFile` in `~/.ssh/config` that points at a file
that is not there. Exit 1 on any of those.

## Two Macs, one 1Password account

| | work Mac | personal Mac |
|---|---|---|
| `git-identity base` | work email, Wealthsimple key signs and pushes; keep only work keys | personal email, personal signing key, account key pushes; leave the work key out |
| `git-identity overlay` | not needed | only if work repos get cloned here: `~/go/src/github.com/wealthsimple/` → work email + work key |

The tracked `.gitconfig` already declares the wealthsimple `includeIf`
pointing at `~/.private/gitconfig-work`, so the overlay picker defaults
its name to `work` and fills that file rather than adding a second
include.

## Requirements and fallbacks

- Runs under the bash macOS ships (3.2), so it works before `brew bundle`.
  `install.sh` offers it as soon as it finds no signing identity.
- fzf when present (preview pane shows fingerprint, `agent.toml` state,
  and what currently uses each key). Numbered `select` menus otherwise.
- 1Password must be unlocked; a locked agent answers "no identities" and
  the picker says so instead of showing an empty list.
- Non-interactive (`status`, `list`) never prompt. The picker refuses
  to run without a terminal.
