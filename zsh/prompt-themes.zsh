# Extra palettes, shapes and styles for zsh/prompt.zsh.
# Sourced by prompt.zsh; nothing here runs on its own.
#
# A theme is just a function named _zp_palette_<name>. prompt.zsh discovers
# them by name, so adding one here needs no edit anywhere else. A palette may
# also set _ZP_THEME_SHAPE / _ZP_THEME_STYLE / _ZP_THEME_DENSITY to ship its
# own defaults; prompt-shape, prompt-style and prompt-density override them.

# --- Palettes ---------------------------------------------------------

# Rosé Pine — muted plum base, rose and gold accents. Soft, low-contrast.
_zp_palette_rose() {
    _ZP_USER_BG='#eb6f92';  _ZP_USER_FG='#191724'
    _ZP_DIR_BG='#f6c177';   _ZP_DIR_FG='#191724'
    _ZP_GIT_BG='#9ccfd8';   _ZP_GIT_FG='#191724'
    _ZP_BRAIN_BG='#c4a7e7'; _ZP_BRAIN_FG='#191724'
    _ZP_DUR_BG='#31748f';   _ZP_DUR_FG='#e0def4'
    _ZP_TIME_BG='#524f67';  _ZP_TIME_FG='#e0def4'
    _ZP_OK='#9ccfd8'; _ZP_ERR='#eb6f92'
    _ZP_THEME_SHAPE=round
}

# Catppuccin Mocha — the current community default. Pastel on espresso.
_zp_palette_catppuccin() {
    _ZP_USER_BG='#cba6f7';  _ZP_USER_FG='#1e1e2e'
    _ZP_DIR_BG='#89b4fa';   _ZP_DIR_FG='#1e1e2e'
    _ZP_GIT_BG='#a6e3a1';   _ZP_GIT_FG='#1e1e2e'
    _ZP_BRAIN_BG='#f5c2e7'; _ZP_BRAIN_FG='#1e1e2e'
    _ZP_DUR_BG='#fab387';   _ZP_DUR_FG='#1e1e2e'
    _ZP_TIME_BG='#585b70';  _ZP_TIME_FG='#cdd6f4'
    _ZP_OK='#a6e3a1'; _ZP_ERR='#f38ba8'
}

# Nord — restrained arctic blues. Blocky, no pointed separators.
_zp_palette_nord() {
    _ZP_USER_BG='#5e81ac';  _ZP_USER_FG='#eceff4'
    _ZP_DIR_BG='#88c0d0';   _ZP_DIR_FG='#2e3440'
    _ZP_GIT_BG='#a3be8c';   _ZP_GIT_FG='#2e3440'
    _ZP_BRAIN_BG='#b48ead'; _ZP_BRAIN_FG='#2e3440'
    _ZP_DUR_BG='#ebcb8b';   _ZP_DUR_FG='#2e3440'
    _ZP_TIME_BG='#4c566a';  _ZP_TIME_FG='#eceff4'
    _ZP_OK='#a3be8c'; _ZP_ERR='#bf616a'
    _ZP_THEME_SHAPE=block
}

# Gruvbox — retro earth tones, flame separators to match the warmth.
_zp_palette_gruvbox() {
    _ZP_USER_BG='#d79921';  _ZP_USER_FG='#282828'
    _ZP_DIR_BG='#d65d0e';   _ZP_DIR_FG='#fbf1c7'
    _ZP_GIT_BG='#98971a';   _ZP_GIT_FG='#282828'
    _ZP_BRAIN_BG='#b16286'; _ZP_BRAIN_FG='#fbf1c7'
    _ZP_DUR_BG='#689d6a';   _ZP_DUR_FG='#282828'
    _ZP_TIME_BG='#504945';  _ZP_TIME_FG='#ebdbb2'
    _ZP_OK='#b8bb26'; _ZP_ERR='#fb4934'
    _ZP_THEME_SHAPE=flame
}

# Synthwave — neon on violet. Slanted separators for the 80s dashboard look.
_zp_palette_synthwave() {
    _ZP_USER_BG='#ff2e97';  _ZP_USER_FG='#1a0033'
    _ZP_DIR_BG='#b967ff';   _ZP_DIR_FG='#ffffff'
    _ZP_GIT_BG='#00e5ff';   _ZP_GIT_FG='#1a0033'
    _ZP_BRAIN_BG='#ffb400'; _ZP_BRAIN_FG='#1a0033'
    _ZP_DUR_BG='#7a04eb';   _ZP_DUR_FG='#ffffff'
    _ZP_TIME_BG='#2b1055';  _ZP_TIME_FG='#00e5ff'
    _ZP_OK='#00e5ff'; _ZP_ERR='#ff2e97'
    _ZP_THEME_SHAPE=slant
}

# Kanagawa — Hokusai woodblock: wave blue, autumn orange, sakura pink.
_zp_palette_kanagawa() {
    _ZP_USER_BG='#7e9cd8';  _ZP_USER_FG='#1f1f28'
    _ZP_DIR_BG='#98bb6c';   _ZP_DIR_FG='#1f1f28'
    _ZP_GIT_BG='#7fb4ca';   _ZP_GIT_FG='#1f1f28'
    _ZP_BRAIN_BG='#d27e99'; _ZP_BRAIN_FG='#1f1f28'
    _ZP_DUR_BG='#ffa066';   _ZP_DUR_FG='#1f1f28'
    _ZP_TIME_BG='#54546d';  _ZP_TIME_FG='#dcd7ba'
    _ZP_OK='#98bb6c'; _ZP_ERR='#e82424'
    _ZP_THEME_SHAPE=slant
}

# Ember — forge colors, hottest segment first, cooling to charcoal.
_zp_palette_ember() {
    _ZP_USER_BG='#ffd000';  _ZP_USER_FG='#2b0a00'
    _ZP_DIR_BG='#ff8c00';   _ZP_DIR_FG='#2b0a00'
    _ZP_GIT_BG='#ff5f00';   _ZP_GIT_FG='#ffe9d6'
    _ZP_BRAIN_BG='#d72638'; _ZP_BRAIN_FG='#ffe9d6'
    _ZP_DUR_BG='#8c1c13';   _ZP_DUR_FG='#ffe9d6'
    _ZP_TIME_BG='#3f0d12';  _ZP_TIME_FG='#ffb400'
    _ZP_OK='#ffb400'; _ZP_ERR='#ff2b2b'
    _ZP_THEME_SHAPE=flame
}

# Paper — light pills for a bright room or a projector. Dark text throughout.
_zp_palette_paper() {
    _ZP_USER_BG='#eceff4';  _ZP_USER_FG='#2e3440'
    _ZP_DIR_BG='#d8dee9';   _ZP_DIR_FG='#2e3440'
    _ZP_GIT_BG='#bfd7ea';   _ZP_GIT_FG='#1b2b34'
    _ZP_BRAIN_BG='#e8d8c3'; _ZP_BRAIN_FG='#2e3440'
    _ZP_DUR_BG='#cfe3cf';   _ZP_DUR_FG='#2e3440'
    _ZP_TIME_BG='#9aa5b1';  _ZP_TIME_FG='#1b2b34'
    _ZP_OK='#2f7d32'; _ZP_ERR='#b3261e'
    _ZP_THEME_SHAPE=round
    _ZP_THEME_STYLE=bubble
}

# Matrix — one hue, no fills. Text-only segments on the terminal background.
_zp_palette_matrix() {
    _ZP_USER_BG='#00ff41';  _ZP_USER_FG='#001b00'
    _ZP_DIR_BG='#00c62f';   _ZP_DIR_FG='#001b00'
    _ZP_GIT_BG='#22e55f';   _ZP_GIT_FG='#001b00'
    _ZP_BRAIN_BG='#00a028'; _ZP_BRAIN_FG='#001b00'
    _ZP_DUR_BG='#00892a';   _ZP_DUR_FG='#001b00'
    _ZP_TIME_BG='#007a20';  _ZP_TIME_FG='#001b00'
    _ZP_OK='#00ff41'; _ZP_ERR='#ff3131'
    _ZP_THEME_STYLE=outline
    _ZP_THEME_SHAPE=plain
}

# ASCII — no Nerd Font glyphs anywhere. The one to use over ssh to a box
# with an unpatched font, or in a tty, where every other theme is tofu.
_zp_palette_ascii() {
    _ZP_USER_BG='#7aa2f7';  _ZP_USER_FG='#1a1b26'
    _ZP_DIR_BG='#9ece6a';   _ZP_DIR_FG='#1a1b26'
    _ZP_GIT_BG='#e0af68';   _ZP_GIT_FG='#1a1b26'
    _ZP_BRAIN_BG='#bb9af7'; _ZP_BRAIN_FG='#1a1b26'
    _ZP_DUR_BG='#f7768e';   _ZP_DUR_FG='#1a1b26'
    _ZP_TIME_BG='#7dcfff';  _ZP_TIME_FG='#1a1b26'
    _ZP_OK='#9ece6a'; _ZP_ERR='#f7768e'
    _ZP_THEME_STYLE=outline
    _ZP_THEME_SHAPE=ascii
    _ZP_THEME_DENSITY=lean
}

# --- Shapes -----------------------------------------------------------
# Shape = the glyphs between and around segments. Everything except
# "block", "plain" and "ascii" needs a Nerd Font.
#   _ZP_CAP  leading cap        _ZP_SEP  between segments
#   _ZP_END  trailing cap       _ZP_THIN separator for the outline style

_zp_shape_chevron() { _ZP_CAP=$''; _ZP_SEP=$''; _ZP_END=$''; _ZP_THIN=$'' }
_zp_shape_round()   { _ZP_CAP=$''; _ZP_SEP=$''; _ZP_END=$''; _ZP_THIN=$'' }
_zp_shape_slant()   { _ZP_CAP=$''; _ZP_SEP=$''; _ZP_END=$''; _ZP_THIN=$'' }
_zp_shape_flame()   { _ZP_CAP=$''; _ZP_SEP=$''; _ZP_END=$''; _ZP_THIN=$'' }
_zp_shape_dust()    { _ZP_CAP=$''; _ZP_SEP=$''; _ZP_END=$''; _ZP_THIN=$'' }
# Fills abut directly — the color change is the separator. No font needed.
_zp_shape_block()   { _ZP_CAP=''; _ZP_SEP=''; _ZP_END=''; _ZP_THIN='│' }
_zp_shape_plain()   { _ZP_CAP=''; _ZP_SEP=' '; _ZP_END=''; _ZP_THIN='·' }
_zp_shape_ascii()   { _ZP_CAP='['; _ZP_SEP=']['; _ZP_END=']'; _ZP_THIN='|' }

typeset -ga _ZP_SHAPES=(chevron round slant flame dust block plain ascii)
typeset -ga _ZP_STYLES=(filled outline bubble)
typeset -ga _ZP_DENSITIES=(full lean zen)

_zp_apply_shape() {
    local s=${1:-chevron}
    (( $+functions[_zp_shape_$s] )) || s=chevron
    _zp_shape_$s
    _ZP_SHAPE=$s
    # The ascii shape exists for terminals with no patched font, so the
    # segment icons have to go too — otherwise it trades box-drawing tofu
    # for icon tofu.
    if [[ $s == ascii ]]; then
        _ZP_GIT='git'; _ZP_CLOCK='at'; _ZP_BRAIN='mem'; _ZP_TIMER='took'
    else
        _ZP_GIT=$_ZP_ICON_GIT;     _ZP_CLOCK=$_ZP_ICON_CLOCK
        _ZP_BRAIN=$_ZP_ICON_BRAIN; _ZP_TIMER=$_ZP_ICON_TIMER
    fi
}

# --- Knobs ------------------------------------------------------------
# Each re-renders immediately so the change is visible without a new prompt.

prompt-shape() {
    if [[ -z $1 || $1 == -l || $1 == --list ]]; then
        print "shapes: ${_ZP_SHAPES[*]}   (current: $_ZP_SHAPE)"
        [[ -z $1 ]] || return 0
        return 0
    fi
    if [[ ${_ZP_SHAPES[(r)$1]} != $1 ]]; then
        print "Usage: prompt-shape [${(j:|:)_ZP_SHAPES}]" >&2
        return 1
    fi
    _zp_apply_shape $1; _zp_save; _zp_render
    print "Prompt shape: $_ZP_SHAPE"
}

prompt-style() {
    if [[ -z $1 || $1 == -l || $1 == --list ]]; then
        print "styles: ${_ZP_STYLES[*]}   (current: $_ZP_STYLE)"
        return 0
    fi
    if [[ ${_ZP_STYLES[(r)$1]} != $1 ]]; then
        print "Usage: prompt-style [${(j:|:)_ZP_STYLES}]" >&2
        return 1
    fi
    _ZP_STYLE=$1; _zp_save; _zp_render
    print "Prompt style: $_ZP_STYLE"
}

prompt-density() {
    if [[ -z $1 || $1 == -l || $1 == --list ]]; then
        print "densities: ${_ZP_DENSITIES[*]}   (current: $_ZP_DENSITY)"
        print "  full  every segment, HUD included"
        print "  lean  git + duration + clock, no HUD"
        print "  zen   user + dir + git only"
        return 0
    fi
    if [[ ${_ZP_DENSITIES[(r)$1]} != $1 ]]; then
        print "Usage: prompt-density [${(j:|:)_ZP_DENSITIES}]" >&2
        return 1
    fi
    _ZP_DENSITY=$1; _zp_save; _zp_render
    print "Prompt density: $_ZP_DENSITY"
}

# Every theme rendered as a sample line, in the current shape and style,
# so you can pick one by eye instead of cycling through them.
prompt-gallery() {
    local saved=$_ZP_THEME t
    local -a themes
    themes=( ${(ok)functions[(I)_zp_palette_*]#_zp_palette_} )
    print "\n  ${#themes} themes, each in its own default shape and style"
    print "  (current: $_ZP_THEME / $_ZP_SHAPE / $_ZP_STYLE / $_ZP_DENSITY)\n"
    for t in $themes; do
        _zp_load_theme $t
        printf '  %-12s ' "$t"
        print -nP "$(_zp_sample_line)"
        print -P "  %F{$_ZP_OK}❯%f %F{$_ZP_ERR}❯%f"
    done
    _zp_load_theme $saved
    _zp_render
    print "\n  prompt-theme <name> to keep one.\n"
}
