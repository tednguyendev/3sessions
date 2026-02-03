#!/bin/bash
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
# <swiftbar.type>streamable</swiftbar.type>

SCRIPT_PATH="$(readlink "$0" 2>/dev/null || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# === CONFIGURATION ===
CONFIG_DIR="$HOME/.config/freetime"
WORK_DAYS_FILE="$CONFIG_DIR/workdays"
WORK_START_FILE="$CONFIG_DIR/workstart"
WORK_END_FILE="$CONFIG_DIR/workend"
SLEEP_TIME_FILE="$CONFIG_DIR/sleeptime"

DEFAULT_WORK_DAYS="1,2,3,4,5"
DEFAULT_WORK_START="08:00"
DEFAULT_WORK_END="17:00"
DEFAULT_SLEEP_TIME="24:00"

WORK_START_PRESETS="07:00 08:00 09:00 10:00 11:00 12:00"
WORK_END_PRESETS="16:00 17:00 18:00 19:00 20:00 21:00"
SLEEP_TIME_PRESETS="22:00 23:00 24:00 25:00 26:00"

DAY_NAMES=(Mon Tue Wed Thu Fri Sat Sun)

mkdir -p "$CONFIG_DIR"

# === HELPERS ===

read_config() {
  [ -f "$1" ] && cat "$1" || echo "$2"
}

parse_time() {
  local h m
  IFS=: read -r h m <<< "$1"
  echo $(( 10#$h * 60 + 10#$m ))
}

format_time() {
  local mins=$1
  local h=$((mins / 60))
  local m=$((mins % 60))
  if [ "$h" -gt 0 ] && [ "$m" -gt 0 ]; then
    echo "${h}h ${m}m"
  elif [ "$h" -gt 0 ]; then
    echo "${h}h"
  else
    echo "${m}m"
  fi
}

config_hash() {
  cat "$WORK_DAYS_FILE" "$WORK_START_FILE" "$WORK_END_FILE" "$SLEEP_TIME_FILE" 2>/dev/null | md5
}

output_menu() {
  local current_hour current_min current_mins day_of_week
  current_hour=$(date '+%H')
  current_min=$(date '+%M')
  current_mins=$(( 10#$current_hour * 60 + 10#$current_min ))
  day_of_week=$(date '+%u')

  local work_days_str work_start work_end sleep_time
  work_days_str=$(read_config "$WORK_DAYS_FILE" "$DEFAULT_WORK_DAYS")
  work_start=$(read_config "$WORK_START_FILE" "$DEFAULT_WORK_START")
  work_end=$(read_config "$WORK_END_FILE" "$DEFAULT_WORK_END")
  sleep_time=$(read_config "$SLEEP_TIME_FILE" "$DEFAULT_SLEEP_TIME")

  local work_start_min work_end_min sleep_min
  work_start_min=$(parse_time "$work_start")
  work_end_min=$(parse_time "$work_end")
  sleep_min=$(parse_time "$sleep_time")
  [ "$sleep_min" -eq 0 ] && sleep_min=$((24 * 60))

  # Check if today is a work day
  local is_work_day=false
  IFS=',' read -ra work_days_arr <<< "$work_days_str"
  for d in "${work_days_arr[@]}"; do
    [ "$d" = "$day_of_week" ] && is_work_day=true
  done

  # Calculate countdown
  local mins_left
  if [ "$is_work_day" = false ]; then
    mins_left=$((sleep_min - current_mins))
  elif [ "$current_mins" -lt "$work_start_min" ]; then
    mins_left=$((work_start_min - current_mins))
  elif [ "$current_mins" -lt "$work_end_min" ]; then
    mins_left=$((work_end_min - current_mins))
  else
    mins_left=$((sleep_min - current_mins))
  fi
  local display
  display=$(format_time "$mins_left")

  echo "$display"
  echo "---"
  echo "Work Days"
  for i in 1 2 3 4 5 6 7; do
    local name="${DAY_NAMES[$((i - 1))]}"
    local mark=" " new_days=""
    for d in "${work_days_arr[@]}"; do
      if [ "$d" = "$i" ]; then
        mark="✓"
      else
        new_days="${new_days:+$new_days,}$d"
      fi
    done
    if [ "$mark" = " " ]; then
      new_days="$work_days_str,$i"
      new_days=$(echo "$new_days" | tr ',' '\n' | sort -n | tr '\n' ',' | sed 's/,$//')
    fi
    echo "--$mark $name | bash='$SCRIPT_DIR/write_stream.sh' param1='$WORK_DAYS_FILE' param2='$new_days' terminal=false"
  done

  echo "---"
  echo "Start Work: $work_start"
  for preset in $WORK_START_PRESETS; do
    local mark=" "
    [ "$work_start" = "$preset" ] && mark="✓"
    echo "--$mark $preset | bash='$SCRIPT_DIR/write_stream.sh' param1='$WORK_START_FILE' param2='$preset' terminal=false"
  done

  echo "Stop Work: $work_end"
  for preset in $WORK_END_PRESETS; do
    local mark=" "
    [ "$work_end" = "$preset" ] && mark="✓"
    echo "--$mark $preset | bash='$SCRIPT_DIR/write_stream.sh' param1='$WORK_END_FILE' param2='$preset' terminal=false"
  done

  echo "Sleep: $sleep_time"
  for preset in $SLEEP_TIME_PRESETS; do
    local mark=" "
    [ "$sleep_time" = "$preset" ] && mark="✓"
    echo "--$mark $preset | bash='$SCRIPT_DIR/write_stream.sh' param1='$SLEEP_TIME_FILE' param2='$preset' terminal=false"
  done

  echo "~~~"
}

# Initial output
output_menu

# Watch for changes and re-output
last_hash=$(config_hash)
last_minute=$(date '+%M')

while true; do
  sleep 0.5

  current_hash=$(config_hash)
  current_minute=$(date '+%M')

  if [ "$current_hash" != "$last_hash" ] || [ "$current_minute" != "$last_minute" ]; then
    output_menu
    last_hash="$current_hash"
    last_minute="$current_minute"
  fi
done
