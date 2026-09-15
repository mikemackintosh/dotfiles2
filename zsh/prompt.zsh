# Pure-zsh powerline prompt. Four independent knobs, each persisted:
#   prompt-theme    palette      (-l lists, no arg cycles)
#   prompt-shape    separators   chevron round slant flame dust block plain ascii
#   prompt-style    fill         filled | bubble | outline
#   prompt-density  how much     full | lean | zen
#   prompt-gallery  every theme rendered as a sample line
# A theme may ship its own shape/style/density defaults; the knobs override.
# State lives in ~/.zp-theme as "theme shape style density".

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
# Themes are discovered, not enumerated: any function named _zp_palette_<name>
# — here or in prompt-themes.zsh — is a theme, so adding one needs no edit to
# this block. State persists as "theme shape style density" in ~/.zp-theme;
# a bare theme name is the old one-field format and still loads.
source "${${(%):-%x}:A:h}/prompt-themes.zsh"

typeset -g _ZP_THEME=zush _ZP_SHAPE=chevron _ZP_STYLE=filled _ZP_DENSITY=full

_zp_themes() { print -l -- ${(ok)functions[(I)_zp_palette_*]#_zp_palette_} }

_zp_load_theme() {
    local name=$1
    (( $+functions[_zp_palette_$name] )) || return 1
    # A palette may ship its own shape/style/density. Clear them first, or
    # the previous theme's choices leak into one that declares none.
    _ZP_THEME_SHAPE= _ZP_THEME_STYLE= _ZP_THEME_DENSITY=
    _zp_palette_$name
    _ZP_THEME=$name
    _zp_apply_shape ${_ZP_THEME_SHAPE:-chevron}
    _ZP_STYLE=${_ZP_THEME_STYLE:-filled}
    _ZP_DENSITY=${_ZP_THEME_DENSITY:-full}
}

_zp_save() { print -r -- "$_ZP_THEME $_ZP_SHAPE $_ZP_STYLE $_ZP_DENSITY" > ~/.zp-theme }

prompt-theme() {
    local -a all; all=( ${(f)"$(_zp_themes)"} )
    local target=${1:-}
    case $target in
        -l|--list) print "themes: ${all[*]}   (current: $_ZP_THEME)"; return 0 ;;
        "") local i=${all[(i)$_ZP_THEME]}
            (( i >= ${#all} )) && i=0
            target=${all[i+1]} ;;
    esac
    if ! _zp_load_theme $target; then
        print "Usage: prompt-theme [${(j:|:)all}]  (or -l)" >&2
        return 1
    fi
    _zp_save
    (( $+functions[_zp_render] )) && _zp_render
    [[ -n $1 ]] || print "Prompt theme: $_ZP_THEME"
}

# Deferred to after the glyph definitions below: _zp_apply_shape swaps the
# segment icons for ASCII ones, so the icons must exist before it first runs.
_zp_init_theme() {
    local -a saved
    if [[ -r ~/.zp-theme ]]; then
        saved=( ${=$(<~/.zp-theme)} )
        _zp_load_theme ${saved[1]:-zush} || _zp_load_theme zush
        [[ -n ${saved[2]:-} ]] && _zp_apply_shape ${saved[2]}
        [[ -n ${saved[3]:-} ]] && _ZP_STYLE=${saved[3]}
        [[ -n ${saved[4]:-} ]] && _ZP_DENSITY=${saved[4]}
    else
        _zp_load_theme zush
    fi
    return 0
}

# --- Glyphs ---
typeset -g _ZP_GIT=$''  # git branch
typeset -g _ZP_CLOCK=$''  # fa-clock-o
typeset -g _ZP_BRAIN=$''  # fa-bookmark
typeset -g _ZP_TIMER=$''  # fa-hourglass-half — last cmd duration

# Caps and separators now come from the shape (prompt-themes.zsh); these are
# the per-segment icons. Stashed so the ascii shape can swap them out and
# every other shape can put them back.
typeset -g _ZP_ICON_GIT=$_ZP_GIT _ZP_ICON_CLOCK=$_ZP_CLOCK
typeset -g _ZP_ICON_BRAIN=$_ZP_BRAIN _ZP_ICON_TIMER=$_ZP_TIMER
_zp_init_theme

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
# bin/ helpers. Colors are fixed (theme-independent) so the segments read
# as "system info".
#
# These run ASYNC: a background job forks the four helpers off the critical
# path and pipes their values back; an fd-readable callback ingests them
# and repaints via `zle reset-prompt`. The prompt never blocks on a helper
# — notably weather, which can spend up to 4s on a cold curl to wttr.in.
# At most one refresh is in flight at a time, and no more than one per 30s.
typeset -g _ZP_HUD_AT=0 _ZP_HUD_FD=
typeset -g _ZP_HUD_WEATHER="" _ZP_HUD_MUSIC=""
typeset -g _ZP_HUD_AIRPODS="" _ZP_HUD_BATTERY=""

# Called by zle when the background job's pipe becomes readable (i.e. the
# helpers finished and flushed their four lines). Empty IFS preserves the
# values verbatim, including the spaces in e.g. "21°C H:60%".
_zp_hud_callback() {
    local fd=$1
    IFS= read -r -u $fd _ZP_HUD_WEATHER
    IFS= read -r -u $fd _ZP_HUD_MUSIC
    IFS= read -r -u $fd _ZP_HUD_AIRPODS
    IFS= read -r -u $fd _ZP_HUD_BATTERY
    zle -F $fd          # unregister this handler
    exec {fd}<&-        # close the pipe
    _ZP_HUD_FD=
    # Bracket the repaint in DEC 2026 so the terminal presents it as one
    # frame. This is the one place the prompt redraws itself out of band —
    # a 400-byte rewrite triggered by a background job finishing — which is
    # exactly the case that tears without it.
    (( $+functions[_zt_sync_begin] )) && _zt_sync_begin
    _zp_render          # rebuild PROMPT with the fresh HUD values…
    zle reset-prompt    # …and repaint (precmd is NOT re-run by reset-prompt)
    (( $+functions[_zt_sync_end] )) && _zt_sync_end
}

_zp_refresh_hud() {
    (( EPOCHSECONDS - _ZP_HUD_AT < 30 )) && return
    [[ -n $_ZP_HUD_FD ]] && return          # a refresh is already in flight
    _ZP_HUD_AT=$EPOCHSECONDS
    local DOTBIN="$HOME/.dotfiles/bin"
    # Each helper computes first (the slow part) then prints one line, so
    # the pipe only becomes readable once all the work is done.
    exec {_ZP_HUD_FD}< <(
        local w m a b
        w=$("$DOTBIN/weather"         2>/dev/null)
        m=$("$DOTBIN/now-playing"     2>/dev/null)
        a=$("$DOTBIN/airpods-battery" 2>/dev/null)
        b=$("$DOTBIN/battery-info"    2>/dev/null)
        print -r -- "$w"; print -r -- "$m"; print -r -- "$a"; print -r -- "$b"
    )
    zle -F $_ZP_HUD_FD _zp_hud_callback
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

typeset -g _ZP_STATUS=0 _ZP_BRANCH="" _ZP_MEM=0
typeset -ga _ZP_SEG_BG _ZP_SEG_FG _ZP_SEG_TXT

_zp_seg() { _ZP_SEG_BG+=($1); _ZP_SEG_FG+=($2); _ZP_SEG_TXT+=($3) }

# Turn the collected segments into a prompt string according to the style:
#   filled   powerline — background fills, the separator carries the color
#            change from one segment to the next
#   bubble   each segment capped both sides and floating on the terminal
#            background, separated by a space
#   outline  no fills at all; the segment color becomes the text color and a
#            muted thin glyph divides them
_zp_assemble() {
    local out="" prev="" bg fg txt i
    for (( i = 1; i <= ${#_ZP_SEG_BG}; i++ )); do
        bg=$_ZP_SEG_BG[i]; fg=$_ZP_SEG_FG[i]; txt=$_ZP_SEG_TXT[i]
        case $_ZP_STYLE in
            outline)
                [[ -n $prev ]] && out+="%F{$_ZP_MUTED}${_ZP_THIN}%f"
                out+="%F{$bg}%B${txt}%b%f"
                ;;
            bubble)
                out+="%F{$bg}${_ZP_CAP}%f%K{$bg}%F{$fg}%B${txt}%b%f%k%F{$bg}${_ZP_END}%f "
                ;;
            *)
                if [[ -z $prev ]]; then
                    out+="%F{$bg}${_ZP_CAP}%f"
                else
                    out+="%K{$bg}%F{$prev}${_ZP_SEP}%f%k"
                fi
                out+="%K{$bg}%F{$fg}%B${txt}%b%f%k"
                ;;
        esac
        prev=$bg
    done
    [[ $_ZP_STYLE == filled && -n $prev ]] && out+="%F{$prev}${_ZP_END}%f"
    print -r -- "$out"
}

# One rendered line per theme, for prompt-gallery. Fixed sample data so the
# rows line up regardless of cwd, branch or clock.
_zp_sample_line() {
    _ZP_SEG_BG=(); _ZP_SEG_FG=(); _ZP_SEG_TXT=()
    _zp_seg $_ZP_USER_BG  $_ZP_USER_FG  " %n "
    _zp_seg $_ZP_DIR_BG   $_ZP_DIR_FG   " ~/dotfiles "
    _zp_seg $_ZP_GIT_BG   $_ZP_GIT_FG   " ${_ZP_GIT} main "
    _zp_seg $_ZP_TIME_BG  $_ZP_TIME_FG  " ${_ZP_CLOCK} 16:36 "
    _zp_assemble
}

# Assemble PROMPT from the per-command state captured in _zp_build_prompt
# (status / branch / duration / mem count) plus the current HUD values.
# Split out from the precmd hook so the async HUD callback can rebuild and
# repaint without re-running precmd (which `zle reset-prompt` won't do).
_zp_render() {
    _ZP_SEG_BG=(); _ZP_SEG_FG=(); _ZP_SEG_TXT=()

    _zp_seg $_ZP_USER_BG $_ZP_USER_FG " %n "
    _zp_seg $_ZP_DIR_BG  $_ZP_DIR_FG  " %(3c.…/%2~.%~) "
    [[ -n $_ZP_BRANCH ]] && _zp_seg $_ZP_GIT_BG $_ZP_GIT_FG " ${_ZP_GIT} ${_ZP_BRANCH} "

    # zen keeps only who/where/which-branch. lean adds the working segments
    # but no HUD. full is everything.
    if [[ $_ZP_DENSITY != zen ]]; then
        (( _ZP_MEM > 0 )) && _zp_seg $_ZP_BRAIN_BG $_ZP_BRAIN_FG " ${_ZP_BRAIN} ${_ZP_MEM} "
        [[ -n $_ZP_CMD_DUR ]] && _zp_seg $_ZP_DUR_BG $_ZP_DUR_FG " ${_ZP_TIMER} ${_ZP_CMD_DUR} "
    fi

    # HUD segments: each renders only if its helper returned data. Values
    # are populated asynchronously (see _zp_refresh_hud). Theme-independent
    # colors mirror the tmux pills. Double '%' so the prompt expander
    # doesn't eat percent signs in helper output (e.g. "H:60%").
    if [[ $_ZP_DENSITY == full ]]; then
        local music=${_ZP_HUD_MUSIC//\%/%%}
        local airpods=${_ZP_HUD_AIRPODS//\%/%%}
        local battery=${_ZP_HUD_BATTERY//\%/%%}
        local weather=${_ZP_HUD_WEATHER//\%/%%}
        [[ -n $music   ]] && _zp_seg '#bb9af7' '#1a1b26' " ${music} "
        [[ -n $airpods ]] && _zp_seg '#ff9e64' '#1a1b26' " 🎧 ${airpods} "
        [[ -n $battery ]] && _zp_seg '#f7768e' '#1a1b26' " ${battery} "
        [[ -n $weather ]] && _zp_seg '#6bb8d9' '#1a1b26' " ☁ ${weather} "
    fi

    [[ $_ZP_DENSITY != zen ]] && _zp_seg $_ZP_TIME_BG $_ZP_TIME_FG " ${_ZP_CLOCK} %* "

    local p
    # OSC 133 A marks the prompt start; it must lead the whole string.
    p="${_ZT_A-}$(_zp_assemble)"
    p+=$'\n'
    if (( _ZP_STATUS == 0 )); then
        p+="%F{$_ZP_OK}%B❯%b%f "
    else
        p+="%F{$_ZP_ERR}%B[${_ZP_STATUS}] ❯%b%f "
    fi
    # OSC 133 B: everything after this point is what the user typed.
    p+="${_ZT_B-}"
    typeset -g _ZP_FULL_PROMPT=$p
    PROMPT=$_ZP_FULL_PROMPT
    RPROMPT=
}
# precmd hook: capture the per-command state that's fixed for this prompt's
# lifetime, kick off the async HUD refresh, then render. The HUD values may
# still be stale here; the async callback repaints once they land.
_zp_build_prompt() {
    _ZP_STATUS=$?
    # OSC 133 D must carry the real exit code, so it is emitted here rather
    # than from a precmd hook of its own — zsh hands only the FIRST precmd
    # hook the true $?, and later ones see the previous hook's status.
    (( $+functions[_zt_mark_d] )) && _zt_mark_d $_ZP_STATUS
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
    _ZP_BRANCH=$branch
    _ZP_MEM=$(_zp_memory_count)

    _zp_refresh_hud
    _zp_render
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
