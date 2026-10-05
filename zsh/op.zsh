# op.zsh — keep the 1Password CLI signed in.
#
# `op inject` / `op read` (what kuse and the registry/sops flows depend on)
# fail the moment the CLI has no active session — and the failure surfaces
# far away: kuse rendered an empty kubeconfig, which became a Docker "is a
# directory" in an unrelated Makefile, and signed commits hung. The session
# dies on its own (app relock, integration toggled, a laptop sleep), so a
# one-time signin isn't enough.
#
# This wraps `op`: before any subcommand that needs a session, if `op whoami`
# shows none, it runs `op signin` and retries a few times, then runs the real
# command. A signed-in call just pays one fast local `op whoami`. Interactive
# shells get the 1Password prompt; a non-interactive context where signin
# can't complete fails fast (bounded retries) instead of hanging.

# Establish an op session, retrying signin. Runs in the CALLER's scope so the
# `eval` persists OP_SESSION_* to that shell (kuse calls this before it renders
# so the session outlives one `op inject`).
_op_signin_retry() {
  command -v op >/dev/null 2>&1 || return 1
  command op whoami >/dev/null 2>&1 && return 0
  local i
  for i in 1 2 3; do
    eval "$(command op signin 2>/dev/null)"
    command op whoami >/dev/null 2>&1 && return 0
    (( i < 3 )) && sleep 1
  done
  return 1
}

op() {
  # Subcommands that don't need (or must not trigger) a session: signin itself,
  # signout, account listing (works signed out — op_probe relies on it), and
  # the trivial info flags.
  case "${1:-}" in
    ""|signin|signout|account|--version|-v|--help|-h|help) command op "$@"; return ;;
  esac
  _op_signin_retry || true   # best effort; let the real op surface any error
  command op "$@"
}
