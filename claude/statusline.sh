#!/bin/bash
# Claude Code Status Line - Enhanced with metrics
# Receives JSON input with session data

input=$(cat)

# Extract core info
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')

# Context window metrics
ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')

# Cost & efficiency
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')

# Directory
dir=$(basename "$cwd")

# Git branch
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null || echo "detached")
  git_info=$'\e[35m'"$branch"$'\e[0m '
else
  git_info=""
fi

# Colors using $'...' syntax
GREEN=$'\e[32m'
BLUE=$'\e[34m'
YELLOW=$'\e[33m'
CYAN=$'\e[36m'
RED=$'\e[31m'
DIM=$'\e[2m'
RESET=$'\e[0m'

# Build status line
# Part 1: dir (git:branch) [model]
echo -n "${BLUE}${dir}${RESET} ${git_info}${YELLOW}[${model}]${RESET}"

# Part 2: Context usage with color coding
if [ -n "$ctx_used" ]; then
  ctx_int=${ctx_used%.*}
  if [ "$ctx_int" -lt 50 ]; then
    ctx_color=$GREEN
  elif [ "$ctx_int" -lt 80 ]; then
    ctx_color=$YELLOW
  else
    ctx_color=$RED
  fi
  echo -n " ${ctx_color}ctx:${ctx_used}%${RESET}"
fi

# Part 3: Token counts
if [ -n "$input_tokens" ] && [ -n "$output_tokens" ]; then
  if [ "$input_tokens" -ge 1000 ]; then
    in_fmt=$(awk "BEGIN {printf \"%.1f\", $input_tokens/1000}")k
  else
    in_fmt=$input_tokens
  fi
  if [ "$output_tokens" -ge 1000 ]; then
    out_fmt=$(awk "BEGIN {printf \"%.1f\", $output_tokens/1000}")k
  else
    out_fmt=$output_tokens
  fi
  echo -n " ${DIM}tok:${in_fmt}/${out_fmt}${RESET}"
fi

# Part 4: Cost
if [ -n "$cost" ] && [ "$cost" != "0" ]; then
  cost_fmt=$(awk "BEGIN {printf \"%.3f\", $cost}")
  echo -n " ${CYAN}\$${cost_fmt}${RESET}"
fi

# Part 5: Lines changed
if [ -n "$lines_added" ] && [ "$lines_added" != "0" ]; then
  echo -n " ${GREEN}+${lines_added}${RESET}"
fi
if [ -n "$lines_removed" ] && [ "$lines_removed" != "0" ]; then
  echo -n "${RED}-${lines_removed}${RESET}"
fi

# Part 6: Duration
if [ -n "$duration_ms" ] && [ "$duration_ms" != "0" ]; then
  duration_sec=$((duration_ms / 1000))
  if [ "$duration_sec" -ge 60 ]; then
    mins=$((duration_sec / 60))
    secs=$((duration_sec % 60))
    echo -n " ${DIM}${mins}m${secs}s${RESET}"
  elif [ "$duration_sec" -gt 0 ]; then
    echo -n " ${DIM}${duration_sec}s${RESET}"
  fi
fi
