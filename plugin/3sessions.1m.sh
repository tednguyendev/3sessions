#!/bin/bash
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>

SCRIPT_PATH="$(readlink "$0" 2>/dev/null || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# === CONFIGURATION ===
CONFIG_DIR="$HOME/.config/freetime"
WORK_DAYS_FILE="$CONFIG_DIR/workdays"
WORK_START_FILE="$CONFIG_DIR/workstart"
WORK_END_FILE="$CONFIG_DIR/workend"
SLEEP_TIME_FILE="$CONFIG_DIR/sleeptime"
STATE_FILE="$CONFIG_DIR/state"
HISTORY_FILE="$CONFIG_DIR/history.log"

DEFAULT_WORK_DAYS="1,2,3,4,5"
DEFAULT_WORK_START="08:00"
DEFAULT_WORK_END="17:00"
DEFAULT_SLEEP_TIME="24:00"

WORK_START_PRESETS="05:00 06:00 07:00 08:00 09:00 10:00 11:00 12:00 13:00 14:00"
WORK_END_PRESETS="12:00 13:00 14:00 15:00 16:00 17:00 18:00 19:00 20:00 21:00 22:00 23:00"
SLEEP_TIME_PRESETS="20:00 21:00 22:00 23:00 24:00 25:00 26:00 27:00 28:00"

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

display_sleep_time() {
  local h
  IFS=: read -r h _ <<< "$1"
  h=$((10#$h))
  [ "$h" -ge 24 ] && h=$((h - 24))
  printf "%02d:00" "$h"
}

log_state_change() {
  local state="$1" display="$2" timestamp="$3"
  local old_state=""
  [ -f "$STATE_FILE" ] && old_state=$(cat "$STATE_FILE")
  if [ "$old_state" != "$state" ]; then
    echo "$timestamp | $state | $display" >> "$HISTORY_FILE"
  fi
  printf '%s' "$state" > "$STATE_FILE"
}

# === READ CONFIG ===

now_timestamp=$(date '+%Y-%m-%d %H:%M')
current_hour=$(date '+%H')
current_min=$(date '+%M')
current_mins=$(( 10#$current_hour * 60 + 10#$current_min ))
day_of_week=$(date '+%u')  # 1=Mon, 7=Sun

work_days_str=$(read_config "$WORK_DAYS_FILE" "$DEFAULT_WORK_DAYS")
work_start=$(read_config "$WORK_START_FILE" "$DEFAULT_WORK_START")
work_end=$(read_config "$WORK_END_FILE" "$DEFAULT_WORK_END")
sleep_time=$(read_config "$SLEEP_TIME_FILE" "$DEFAULT_SLEEP_TIME")

work_start_min=$(parse_time "$work_start")
work_end_min=$(parse_time "$work_end")
sleep_min=$(parse_time "$sleep_time")
[ "$sleep_min" -eq 0 ] && sleep_min=$((24 * 60))

# Check if today is a work day
is_work_day=false
IFS=',' read -ra work_days_arr <<< "$work_days_str"
for d in "${work_days_arr[@]}"; do
  [ "$d" = "$day_of_week" ] && is_work_day=true
done

# === 1. MAIN STATUS ===

if [ "$is_work_day" = false ]; then
  mins_left=$((sleep_min - current_mins))
  display=$(format_time "$mins_left")
  log_state_change "free_day" "$display" "$now_timestamp"
elif [ "$current_mins" -lt "$work_start_min" ]; then
  mins_left=$((work_start_min - current_mins))
  display=$(format_time "$mins_left")
  log_state_change "before_work" "$display" "$now_timestamp"
elif [ "$current_mins" -lt "$work_end_min" ]; then
  mins_left=$((work_end_min - current_mins))
  display=$(format_time "$mins_left")
  log_state_change "during_work" "$display" "$now_timestamp"
else
  mins_left=$((sleep_min - current_mins))
  display=$(format_time "$mins_left")
  log_state_change "after_work" "$display" "$now_timestamp"
fi

echo "$display"

# === 2. WORK DAYS MENU ===

echo "---"
echo "Work Days"
for i in 1 2 3 4 5 6 7; do
  name="${DAY_NAMES[$((i - 1))]}"
  mark=" "
  new_days=""
  for d in "${work_days_arr[@]}"; do
    if [ "$d" = "$i" ]; then
      mark="✓"
    else
      new_days="${new_days:+$new_days,}$d"
    fi
  done
  if [ "$mark" = " " ]; then
    # Add this day and sort
    new_days="$work_days_str,$i"
    new_days=$(echo "$new_days" | tr ',' '\n' | sort -n | tr '\n' ',' | sed 's/,$//')
  fi
  echo "--$mark $name | bash='$SCRIPT_DIR/write.sh' param1='$WORK_DAYS_FILE' param2='$new_days' terminal=false"
done

# === 3. START WORK MENU ===

echo "---"
echo "Start Work: $work_start"
for preset in $WORK_START_PRESETS; do
  mark=" "
  [ "$work_start" = "$preset" ] && mark="✓"
  echo "--$mark $preset | bash='$SCRIPT_DIR/write.sh' param1='$WORK_START_FILE' param2='$preset' terminal=false"
done

# === 4. STOP WORK MENU ===

echo "Stop Work: $work_end"
for preset in $WORK_END_PRESETS; do
  mark=" "
  [ "$work_end" = "$preset" ] && mark="✓"
  echo "--$mark $preset | bash='$SCRIPT_DIR/write.sh' param1='$WORK_END_FILE' param2='$preset' terminal=false"
done

# === 5. SLEEP TIME MENU ===

echo "Sleep: $(display_sleep_time "$sleep_time")"
for preset in $SLEEP_TIME_PRESETS; do
  mark=" "
  [ "$sleep_time" = "$preset" ] && mark="✓"
  echo "--$mark $(display_sleep_time "$preset") | bash='$SCRIPT_DIR/write.sh' param1='$SLEEP_TIME_FILE' param2='$preset' terminal=false"
done
