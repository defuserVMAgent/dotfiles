#!/usr/bin/env bash
# Minimalist Claude Code status line: model · effort · context usage
input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // "?"')
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty')
pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')

# Colors
dim='\033[2m'; reset='\033[0m'; sep="${dim} · ${reset}"

out="${model}"
[ -n "$effort" ] && out="${out}${sep}${effort}"

if [ -n "$pct" ]; then
  pct_round=$(printf '%.0f' "$pct")
  # Color the context number by how full it is
  if   [ "$pct_round" -ge 80 ]; then col='\033[31m'   # red
  elif [ "$pct_round" -ge 50 ]; then col='\033[33m'   # yellow
  else                               col='\033[32m'   # green
  fi
  out="${out}${sep}${col}${pct_round}%%${reset}"
fi

# Harvest rate-limit usage for the tmux status bar (rendered by
# ~/.local/bin/tmux-claude-usage). Cache path is hardcoded to $HOME: this runs
# in Claude Code's environment, the segment in tmux's, and $HOME is the one
# variable both always agree on. Never let a harvest failure touch the visible
# status line above.
{
  cache_dir="$HOME/.cache/claude-usage"
  cache="$cache_dir/usage"
  data=$(printf '%s' "$input" | jq -r '.rate_limits as $r
    | "FIVE_HOUR_PCT=\($r.five_hour.used_percentage // "")",
      "FIVE_HOUR_RESET=\($r.five_hour.resets_at // "")",
      "SEVEN_DAY_PCT=\($r.seven_day.used_percentage // "")",
      "SEVEN_DAY_RESET=\($r.seven_day.resets_at // "")"' 2>/dev/null)

  # Shared cache, many sessions: an idle session re-renders replaying the stale
  # snapshot it last saw. Accept only a newer window (greater resets_at) or, in
  # the same window, an equal-or-higher percentage (usage only climbs until the
  # window resets). If either side lacks numbers, don't outsmart it — write.
  fresh() {
    [ -f "$cache" ] || return 0
    awk -v nr="$(printf '%s\n' "$data" | sed -n 's/^FIVE_HOUR_RESET=//p')" \
        -v np="$(printf '%s\n' "$data" | sed -n 's/^FIVE_HOUR_PCT=//p')" \
        -v cr="$(sed -n 's/^FIVE_HOUR_RESET=//p' "$cache")" \
        -v cp="$(sed -n 's/^FIVE_HOUR_PCT=//p' "$cache")" 'BEGIN {
      if (nr == "" || np == "" || cr == "" || cp == "") exit 0
      if (nr+0 > cr+0) exit 0
      if (nr+0 == cr+0 && np+0 >= cp+0) exit 0
      exit 1
    }'
  }

  # Only write when usage numbers are present, so a render without rate_limits
  # (API-key sessions, transient nulls) never clobbers a good cache.
  if printf '%s' "$data" | grep -q 'PCT=[0-9]' && fresh; then
    mkdir -p "$cache_dir"
    { printf '%s\n' "$data"; printf 'UPDATED_AT=%s\n' "$(date +%s)"; } \
      >"$cache.tmp.$$" && mv "$cache.tmp.$$" "$cache"
  fi
} 2>/dev/null

printf "${out}"
