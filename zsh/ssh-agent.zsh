# SSH_AUTH_SOCK — 1Password's agent, not macOS's empty one.
#
# Every macOS login session exports
# SSH_AUTH_SOCK=/private/tmp/com.apple.launchd.*/Listeners. That agent
# holds nothing — the keys are in 1Password. `ssh` itself does not care,
# because IdentityAgent in ~/.ssh/config overrides the env var, which is
# why this stayed invisible for so long: everything that talks to the
# agent DIRECTLY was broken the whole time. `ssh-add -l` answers "The
# agent has no identities", `ssh-keygen -Y sign` cannot sign a commit,
# and bin/claude-in-docker forwarded the empty socket into the container.
#
# Skipped inside an ssh session: there SSH_AUTH_SOCK is the forwarded
# agent from the machine you came from, and that is the one you want.
if [[ -z ${SSH_CONNECTION:-} ]]; then
    _1p_agent="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    [[ -S $_1p_agent ]] && export SSH_AUTH_SOCK=$_1p_agent
    unset _1p_agent
fi
