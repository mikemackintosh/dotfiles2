# Pure-zsh powerline prompt with toggleable palettes.
# Toggle: `prompt-theme [zush|tokyo|noir]`; no arg cycles. Persists to ~/.zp-theme.

[[ -o interactive ]] || return 0

autoload -Uz add-zsh-hook vcs_info
zmodload zsh/datetime    # $EPOCHSECONDS for command-duration timing
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
    _ZP_DUR_BG='#a3be8c';   _ZP_DUR_FG='#1a1b26'
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
    _ZP_DUR_BG='#f7768e';   _ZP_DUR_FG='#1a1b26'
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
    _ZP_DUR_BG='#FFB454';   _ZP_DUR_FG='#1D1640'    # amber w/ deep indigo
    _ZP_TIME_BG='#504D73';  _ZP_TIME_FG='#FFFFFF'   # slate (bookend)
    _ZP_OK='#00D0FF'
    _ZP_ERR='#EA3F5E'
}

# Princess — sunset gradient lifted from M365Princess (oh-my-posh).
# plum → blush → salmon → mid-magenta → sky → teal_blue. White FG throughout.
_zp_palette_princess() {
    _ZP_USER_BG='#9A348E';  _ZP_USER_FG='#FFFFFF'   # plum
    _ZP_DIR_BG='#DA627D';   _ZP_DIR_FG='#FFFFFF'    # blush
    _ZP_GIT_BG='#FCA17D';   _ZP_GIT_FG='#FFFFFF'    # salmon
    _ZP_BRAIN_BG='#C13E83'; _ZP_BRAIN_FG='#FFFFFF'  # mid-magenta (gradient fill)
    _ZP_DUR_BG='#86BBD8';   _ZP_DUR_FG='#FFFFFF'    # sky (M365 node-version slot)
    _ZP_TIME_BG='#33658A';  _ZP_TIME_FG='#FFFFFF'   # teal_blue
    _ZP_OK='#FFB6E1'
    _ZP_ERR='#FF26B9'
}

# JBlab 2021 — JetBrains-flavored dual-tone: dark navy + teal,
# purple accent for git. From jblab_2021.omp.json (oh-my-posh).
_zp_palette_jblab() {
    _ZP_USER_BG='#0C212F';  _ZP_USER_FG='#FFFFFF'   # dark navy (OS slot)
    _ZP_DIR_BG='#26BDBB';   _ZP_DIR_FG='#0C212F'    # teal w/ navy text
    _ZP_GIT_BG='#7621DE';   _ZP_GIT_FG='#FFFFFF'    # purple (jblab "dirty" git)
    _ZP_BRAIN_BG='#FFB454'; _ZP_BRAIN_FG='#0C212F'  # amber accent (no jblab analog)
    _ZP_DUR_BG='#26BDBB';   _ZP_DUR_FG='#0C212F'    # teal (matches exec-time slot)
    _ZP_TIME_BG='#0C212F';  _ZP_TIME_FG='#FFFFFF'   # dark navy (matches OS slot)
    _ZP_OK='#26BDBB'
    _ZP_ERR='#910000'
}

typeset -g _ZP_MUTED='#6c7086'

# --- Theme loader / toggler ---
prompt-theme() {
    local target=${1:-}
    if [[ -z $target ]]; then
        case $_ZP_THEME in
            zush)     target=tokyo    ;;
            tokyo)    target=noir     ;;
            noir)     target=princess ;;
            princess) target=jblab    ;;
            *)        target=zush     ;;
        esac
    fi
    case $target in
        zush)     _zp_palette_zush;     _ZP_THEME=zush     ;;
        tokyo)    _zp_palette_tokyo;    _ZP_THEME=tokyo    ;;
        noir)     _zp_palette_noir;     _ZP_THEME=noir     ;;
        princess) _zp_palette_princess; _ZP_THEME=princess ;;
        jblab)    _zp_palette_jblab;    _ZP_THEME=jblab    ;;
        *) echo "Usage: prompt-theme [zush|tokyo|noir|princess|jblab]"; return 1 ;;
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
    tokyo)    _zp_palette_tokyo    ;;
    noir)     _zp_palette_noir     ;;
    princess) _zp_palette_princess ;;
    jblab)    _zp_palette_jblab    ;;
    *)        _zp_palette_zush; _ZP_THEME=zush ;;
esac

# --- Glyphs ---
typeset -g _ZP_CAP=$''  # left half-circle
typeset -g _ZP_SEP=$''  # right chevron
typeset -g _ZP_GIT=$''  # git branch
typeset -g _ZP_CLOCK=$''  # fa-clock-o
typeset -g _ZP_BRAIN=$''  # fa-bookmark
typeset -g _ZP_TIMER=$''  # fa-hourglass-half — last cmd duration
typeset -g _ZP_END=$''  # right half-circle (M365-style trailing cap)

# Command-duration timing: preexec captures start, precmd computes elapsed.
# Only surfaced as a segment when the previous command took >=1s.
typeset -g _ZP_CMD_START=0 _ZP_CMD_DUR=""
_zp_fmt_dur() {
    local s=$1
    if   (( s < 60   )); then printf '%ds'      $s
    elif (( s < 3600 )); then printf '%dm%02ds' $((s/60))   $((s%60))
    else                      printf '%dh%02dm' $((s/3600)) $(((s%3600)/60))
    fi
}
_zp_preexec() { _ZP_CMD_START=$EPOCHSECONDS; }
add-zsh-hook preexec _zp_preexec

# HUD segments: weather / now-playing / AirPods / battery, sourced from
# bin/ helpers. The helpers cache their own data; the prompt also caches
# for 30s so we don't fork 4 processes on every keystroke. Colors are
# fixed (theme-independent) so the segments read as "system info".
typeset -g _ZP_HUD_AT=0
typeset -g _ZP_HUD_WEATHER="" _ZP_HUD_MUSIC=""
typeset -g _ZP_HUD_AIRPODS="" _ZP_HUD_BATTERY=""
_zp_refresh_hud() {
    (( EPOCHSECONDS - _ZP_HUD_AT < 30 )) && return
    _ZP_HUD_AT=$EPOCHSECONDS
    local DOTBIN="$HOME/.dotfiles/bin"
    _ZP_HUD_WEATHER=$("$DOTBIN/weather"         2>/dev/null)
    _ZP_HUD_MUSIC=$(  "$DOTBIN/now-playing"     2>/dev/null)
    _ZP_HUD_AIRPODS=$("$DOTBIN/airpods-battery" 2>/dev/null)
    _ZP_HUD_BATTERY=$("$DOTBIN/battery-info"    2>/dev/null)
}

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

    # Duration of the previous command, if any.
    _ZP_CMD_DUR=""
    if (( _ZP_CMD_START > 0 )); then
        local d=$((EPOCHSECONDS - _ZP_CMD_START))
        _ZP_CMD_START=0
        (( d >= 1 )) && _ZP_CMD_DUR=$(_zp_fmt_dur $d)
    fi

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

    if [[ -n $_ZP_CMD_DUR ]]; then
        p+="%K{$_ZP_DUR_BG}%F{$prev}${_ZP_SEP}%f%k"
        p+="%K{$_ZP_DUR_BG}%F{$_ZP_DUR_FG}%B ${_ZP_TIMER} ${_ZP_CMD_DUR} %b%f%k"
        prev=$_ZP_DUR_BG
    fi

    # HUD segments: refresh at most every 30s. Each renders only if its
    # helper returned data. Theme-independent colors mirror the tmux pills.
    # Double '%' in helper output so zsh's prompt expander doesn't eat it.
    _zp_refresh_hud
    local music=${_ZP_HUD_MUSIC//\%/%%}
    local airpods=${_ZP_HUD_AIRPODS//\%/%%}
    local battery=${_ZP_HUD_BATTERY//\%/%%}
    local weather=${_ZP_HUD_WEATHER//\%/%%}
    if [[ -n $music ]]; then
        p+="%K{#bb9af7}%F{$prev}${_ZP_SEP}%f%k"
        p+="%K{#bb9af7}%F{#1a1b26}%B ${music} %b%f%k"
        prev='#bb9af7'
    fi
    if [[ -n $airpods ]]; then
        p+="%K{#ff9e64}%F{$prev}${_ZP_SEP}%f%k"
        p+="%K{#ff9e64}%F{#1a1b26}%B 🎧 ${airpods} %b%f%k"
        prev='#ff9e64'
    fi
    if [[ -n $battery ]]; then
        p+="%K{#f7768e}%F{$prev}${_ZP_SEP}%f%k"
        p+="%K{#f7768e}%F{#1a1b26}%B ${battery} %b%f%k"
        prev='#f7768e'
    fi
    if [[ -n $weather ]]; then
        p+="%K{#6bb8d9}%F{$prev}${_ZP_SEP}%f%k"
        p+="%K{#6bb8d9}%F{#1a1b26}%B ☁ ${weather} %b%f%k"
        prev='#6bb8d9'
    fi

    p+="%K{$_ZP_TIME_BG}%F{$prev}${_ZP_SEP}%f%k"
    p+="%K{$_ZP_TIME_BG}%F{$_ZP_TIME_FG}%B ${_ZP_CLOCK} %* %b%f%k"
    p+="%F{$_ZP_TIME_BG}${_ZP_END}%f"

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
