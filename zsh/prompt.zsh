# Pure-zsh powerline prompt with toggleable palettes.
# Toggle: `prompt-theme [zush|tokyo|noir]`; no arg cycles. Persists to ~/.zp-theme.

[[ -o interactive ]] || return 0

autoload -Uz add-zsh-hook vcs_info
setopt prompt_subst

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes false
zstyle ':vcs_info:git:*' formats '%b'
zstyle ':vcs_info:git:*' actionformats '%b|%a'

# --- Palettes (each sets BG + FG per segment, plus OK/ERR) ---
# zush remote (default — warm)
_zp_palette_zush() {
    _ZP_USER_BG='#e26e88';  _ZP_USER_FG='#1a1b26'
    _ZP_DIR_BG='#f2a272';   _ZP_DIR_FG='#1a1b26'
    _ZP_GIT_BG='#67d4c4';   _ZP_GIT_FG='#1a1b26'
    _ZP_BRAIN_BG='#b48ead'; _ZP_BRAIN_FG='#1a1b26'
    _ZP_TIME_BG='#6bb8d9';  _ZP_TIME_FG='#1a1b26'
    _ZP_OK='#7eca9c'
    _ZP_ERR='#f38ba8'
}

# Tokyo Night Storm (cool)
_zp_palette_tokyo() {
    _ZP_USER_BG='#7aa2f7';  _ZP_USER_FG='#1a1b26'
    _ZP_DIR_BG='#bb9af7';   _ZP_DIR_FG='#1a1b26'
    _ZP_GIT_BG='#9ece6a';   _ZP_GIT_FG='#1a1b26'
    _ZP_BRAIN_BG='#73daca'; _ZP_BRAIN_FG='#1a1b26'
    _ZP_TIME_BG='#e0af68';  _ZP_TIME_FG='#1a1b26'
    _ZP_OK='#73daca'
    _ZP_ERR='#f7768e'
}

# Noir / Cyberpunk (deep indigo + slate + mauve + crimson + cyan)
_zp_palette_noir() {
    _ZP_USER_BG='#504D73';  _ZP_USER_FG='#FFFFFF'   # slate w/ white
    _ZP_DIR_BG='#8E83A4';   _ZP_DIR_FG='#1D1640'    # mauve w/ deep indigo
    _ZP_GIT_BG='#00D0FF';   _ZP_GIT_FG='#1D1640'    # cyan w/ deep indigo
    _ZP_BRAIN_BG='#EA3F5E'; _ZP_BRAIN_FG='#FFFFFF'  # crimson w/ white
    _ZP_TIME_BG='#504D73';  _ZP_TIME_FG='#FFFFFF'   # slate (bookend)
    _ZP_OK='#00D0FF'
    _ZP_ERR='#EA3F5E'
}

typeset -g _ZP_MUTED='#6c7086'

# --- Theme loader / toggler ---
prompt-theme() {
    local target=${1:-}
    if [[ -z $target ]]; then
        case $_ZP_THEME in
            zush)  target=tokyo ;;
            tokyo) target=noir  ;;
            *)     target=zush  ;;
        esac
    fi
    case $target in
        zush)  _zp_palette_zush;  _ZP_THEME=zush  ;;
        tokyo) _zp_palette_tokyo; _ZP_THEME=tokyo ;;
        noir)  _zp_palette_noir;  _ZP_THEME=noir  ;;
        *) echo "Usage: prompt-theme [zush|tokyo|noir]"; return 1 ;;
    esac
    print -- $_ZP_THEME > ~/.zp-theme
    [[ -n $1 ]] || echo "Prompt theme: $_ZP_THEME"
}

# Load saved theme on init
if [[ -r ~/.zp-theme ]]; then
    _ZP_THEME=$(<~/.zp-theme)
else
    _ZP_THEME=zush
fi
case $_ZP_THEME in
    tokyo) _zp_palette_tokyo ;;
    noir)  _zp_palette_noir  ;;
    *)     _zp_palette_zush; _ZP_THEME=zush ;;
esac

# --- Glyphs ---
typeset -g _ZP_CAP=$''    # left half-circle
typeset -g _ZP_SEP=$''    # right chevron
typeset -g _ZP_GIT=$''    # git branch
typeset -g _ZP_CLOCK=$''  # fa-clock-o
typeset -g _ZP_BRAIN=$''  # fa-bookmark

# Cache the memory-file count keyed by "<dir>:<mtime>". A single stat
# is much cheaper than re-globbing every prompt, and the mtime key
# catches files added mid-session without needing a chpwd hook.
zmodload -F zsh/stat b:zstat 2>/dev/null
typeset -g _ZP_MEM_KEY="" _ZP_MEM_COUNT=0

_zp_memory_count() {
    local slug="${PWD//\//-}"
    local dir="$HOME/.claude/projects/${slug}/memory"
    if [[ ! -d $dir ]]; then
        print 0
        return
    fi
    local -a st
    zstat -A st +mtime -- "$dir" 2>/dev/null
    local key="$dir:${st[1]:-0}"
    if [[ $_ZP_MEM_KEY != $key ]]; then
        local files=("$dir"/*.md(N))
        _ZP_MEM_COUNT=${#files}
        [[ -f "$dir/MEMORY.md" ]] && (( _ZP_MEM_COUNT-- ))
        _ZP_MEM_KEY=$key
    fi
    print $_ZP_MEM_COUNT
}

_zp_build_prompt() {
    local last_status=$?
    vcs_info
    print ""
    local branch=$vcs_info_msg_0_
    if (( ${#branch} > 25 )); then
        branch="${branch[1,24]}…"
    fi
    local mem_count=$(_zp_memory_count)

    local p=""
    p+="%F{$_ZP_USER_BG}${_ZP_CAP}%f"
    p+="%K{$_ZP_USER_BG}%F{$_ZP_USER_FG}%B %n %b%f%k"
    p+="%K{$_ZP_DIR_BG}%F{$_ZP_USER_BG}${_ZP_SEP}%f%k"
    p+="%K{$_ZP_DIR_BG}%F{$_ZP_DIR_FG}%B %(3c.…/%2~.%~) %b%f%k"

    local prev=$_ZP_DIR_BG

    if [[ -n $branch ]]; then
        p+="%K{$_ZP_GIT_BG}%F{$prev}${_ZP_SEP}%f%k"
        p+="%K{$_ZP_GIT_BG}%F{$_ZP_GIT_FG}%B ${_ZP_GIT} ${branch} %b%f%k"
        prev=$_ZP_GIT_BG
    fi

    if (( mem_count > 0 )); then
        p+="%K{$_ZP_BRAIN_BG}%F{$prev}${_ZP_SEP}%f%k"
        p+="%K{$_ZP_BRAIN_BG}%F{$_ZP_BRAIN_FG}%B ${_ZP_BRAIN} ${mem_count} %b%f%k"
        prev=$_ZP_BRAIN_BG
    fi

    p+="%K{$_ZP_TIME_BG}%F{$prev}${_ZP_SEP}%f%k"
    p+="%K{$_ZP_TIME_BG}%F{$_ZP_TIME_FG}%B ${_ZP_CLOCK} %* %b%f%k"
    p+="%F{$_ZP_TIME_BG}${_ZP_SEP}%f"

    p+=$'\n'
    if (( last_status == 0 )); then
        p+="%F{$_ZP_OK}%B❯%b%f "
    else
        p+="%F{$_ZP_ERR}%B[${last_status}] ❯%b%f "
    fi
    typeset -g _ZP_FULL_PROMPT=$p
    PROMPT=$_ZP_FULL_PROMPT
    RPROMPT=
}
add-zsh-hook precmd _zp_build_prompt

typeset -g _ZP_TRANSIENT='%F{$_ZP_MUTED}%* %f'

_zp_accept_line() {
    PROMPT=$_ZP_TRANSIENT
    zle reset-prompt
    zle accept-line
}
zle -N _zp_accept_line
bindkey '^M' _zp_accept_line
