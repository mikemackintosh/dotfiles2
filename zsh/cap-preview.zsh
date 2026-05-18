#!/usr/bin/env zsh
# Cap glyph comparison — Nerd Font required (you have Hack Nerd Font Mono).
# Run: zsh ~/.dotfiles/zsh/cap-preview.zsh
# Each row uses a different left cap; everything else is identical.

local sep=$''        # standard right chevron for sep
local git=$''        # git icon
local dir_bg='#A277FF'
local dir_fg='#15141B'
local git_bg='#FFCA85'
local git_fg='#15141B'

_render() {
    local label=$1 cap=$2 codepoint=$3 name=$4
    printf '%-3s ' "$label"
    print -nP "%F{$dir_bg}${cap}%f%K{$dir_bg}%F{$dir_fg}%B ~/repo %b%f%k"
    print -nP "%K{$git_bg}%F{$dir_bg}${sep}%f%k%K{$git_bg}%F{$git_fg}%B ${git} main %b%f%k"
    print -nP "%F{$git_bg}${sep}%f"
    printf "   %-7s %s\n" "$codepoint" "$name"
}

print "Cap options (all rendered with Hack Nerd Font Mono):\n"

_render "A" $'' "U+E0D7" "ple-left_hard_divider_inverse (current — thin)"
_render "B" $'' "U+E0D6" "ple-left_hard_divider"
_render "C" $'' "U+E0B6" "pl-left_half_circle_thick (rounded bulge)"
_render "D" $'' "U+E0B7" "pl-left_half_circle_thin"
_render "E" $'' "U+E0BC" "pl-upper_left_triangle (solid slab)"
_render "F" $'' "U+E0BE" "pl-lower_left_triangle"
_render "G" $'' "U+E0D2" "ple-left_half_circle_inverse"
_render "H" $'' "U+E0B2" "pl-right_hard_divider (left chevron)"
