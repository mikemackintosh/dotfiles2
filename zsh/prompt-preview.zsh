#!/usr/bin/env zsh
# Compare "techy / masculine / polished" prompt palettes.
# Run: zsh ~/.dotfiles/zsh/prompt-preview.zsh
# Each row shows the full prompt + success and failure arrows.

local cap=$''
local sep=$''
local git=$''
local sample='…/wealthsimple/ainstein'
local branch='main'

_render() {
    local label=$1 dir_bg=$2 dir_fg=$3 git_bg=$4 git_fg=$5 ok=$6 err=$7
    printf '%-22s ' "$label"
    print -nP "%F{$dir_bg}${cap}%f%K{$dir_bg}%F{$dir_fg}%B ${sample} %b%f%k"
    print -nP "%K{$git_bg}%F{$dir_bg}${sep}%f%k%K{$git_bg}%F{$git_fg}%B ${git} ${branch} %b%f%k"
    print -nP "%F{$git_bg}${sep}%f"
    print -nP "  %F{$ok}%B❯%b%f"
    print -P "  %F{$err}%B❯%b%f"
}

print "Techy/masculine/polished palettes — pick a letter:\n"

# A: Tokyo Night Storm — most-loved cool palette
_render "A Tokyo Night" "#7AA2F7" "#1A1B26" "#BB9AF7" "#1A1B26" "#9ECE6A" "#F7768E"

# B: Nord — restrained cool blues (very polished, mature)
_render "B Nord"        "#5E81AC" "#ECEFF4" "#88C0D0" "#2E3440" "#A3BE8C" "#BF616A"

# C: Catppuccin Mocha — refined mauve, current style but cleaner
_render "C Mocha"       "#CBA6F7" "#11111B" "#F5C2E7" "#11111B" "#A6E3A1" "#F38BA8"

# D: Gruvbox Material — earthy + masculine, warm tech
_render "D Gruvbox Mat" "#D8A657" "#1D2021" "#7DAEA3" "#1D2021" "#A9B665" "#EA6962"

# E: Synthwave 84 — deep purple + hot pink (electric retro-tech)
_render "E Synthwave"   "#7209B7" "#FFFFFF" "#F72585" "#FFFFFF" "#06FFA5" "#FF6B6B"

# F: Rose Pine Moon — moody, deep, sophisticated
_render "F Rose Pine"   "#9CCFD8" "#232136" "#C4A7E7" "#232136" "#3E8FB0" "#EB6F92"

# G: One Dark — VSCode default, instantly recognizable
_render "G One Dark"    "#61AFEF" "#282C34" "#C678DD" "#282C34" "#98C379" "#E06C75"

# H: Aura Pro — your current theme but deeper/more saturated
_render "H Aura Pro"    "#7C3AED" "#FFFFFF" "#F472B6" "#FFFFFF" "#34D399" "#FB7185"
