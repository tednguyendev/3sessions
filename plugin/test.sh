#!/bin/bash

PASS=0
FAIL=0
TEMP_DIR=$(mktemp -d)

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  expected: '$expected'"
    echo "  actual:   '$actual'"
  fi
}

assert_file_exists() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL: $label - file not found"; fi
}

assert_file_not_exists() {
  local label="$1" path="$2"
  if [ ! -f "$path" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL: $label - file should not exist"; fi
}

assert_file_contains() {
  local label="$1" path="$2" pattern="$3"
  if grep -q "$pattern" "$path" 2>/dev/null; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL: $label - '$pattern' not in file"; fi
}

assert_file_not_contains() {
  local label="$1" path="$2" pattern="$3"
  if ! grep -q "$pattern" "$path" 2>/dev/null; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL: $label - '$pattern' should not be in file"; fi
}

# Source functions from 3sessions.1m.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
eval "$(sed -n '/^parse_time()/,/^}/p' "$SCRIPT_DIR/3sessions.1m.sh")"
eval "$(sed -n '/^format_time()/,/^}/p' "$SCRIPT_DIR/3sessions.1m.sh")"
eval "$(sed -n '/^display_sleep_time()/,/^}/p' "$SCRIPT_DIR/3sessions.1m.sh")"

reset_data() {
  rm -rf "$TEMP_DIR/data"
  mkdir -p "$TEMP_DIR/data"
  STATE_FILE="$TEMP_DIR/data/state"
  HISTORY_FILE="$TEMP_DIR/data/history.log"
}

# Inline log_state_change for testing (uses STATE_FILE/HISTORY_FILE from reset_data)
log_state_change() {
  local state="$1" display="$2" timestamp="$3"
  local old_state=""
  [ -f "$STATE_FILE" ] && old_state=$(cat "$STATE_FILE")
  if [ "$old_state" != "$state" ]; then
    echo "$timestamp | $state | $display" >> "$HISTORY_FILE"
  fi
  printf '%s' "$state" > "$STATE_FILE"
}

# ============================================================
# format_time tests
# ============================================================

echo "--- format_time ---"

assert_eq "0 minutes" "0m" "$(format_time 0)"
assert_eq "1 minute" "1m" "$(format_time 1)"
assert_eq "30 minutes" "30m" "$(format_time 30)"
assert_eq "59 minutes" "59m" "$(format_time 59)"
assert_eq "1 hour exact" "1h" "$(format_time 60)"
assert_eq "2 hours exact" "2h" "$(format_time 120)"
assert_eq "24 hours exact" "24h" "$(format_time 1440)"
assert_eq "1h 30m" "1h 30m" "$(format_time 90)"
assert_eq "2h 15m" "2h 15m" "$(format_time 135)"
assert_eq "23h 59m" "23h 59m" "$(format_time 1439)"

# ============================================================
# parse_time tests
# ============================================================

echo "--- parse_time ---"

assert_eq "08:00" "480" "$(parse_time "08:00")"
assert_eq "09:00" "540" "$(parse_time "09:00")"
assert_eq "09:30" "570" "$(parse_time "09:30")"
assert_eq "17:00" "1020" "$(parse_time "17:00")"
assert_eq "17:45" "1065" "$(parse_time "17:45")"
assert_eq "24:00" "1440" "$(parse_time "24:00")"
assert_eq "25:00" "1500" "$(parse_time "25:00")"

# ============================================================
# display_sleep_time tests
# ============================================================

echo "--- display_sleep_time ---"

assert_eq "22:00" "22:00" "$(display_sleep_time "22:00")"
assert_eq "23:00" "23:00" "$(display_sleep_time "23:00")"
assert_eq "24:00 wraps" "00:00" "$(display_sleep_time "24:00")"
assert_eq "25:00 wraps" "01:00" "$(display_sleep_time "25:00")"
assert_eq "26:00 wraps" "02:00" "$(display_sleep_time "26:00")"

# ============================================================
# log_state_change tests
# ============================================================

echo "--- log_state_change ---"

# New state writes to history
reset_data
log_state_change "during_work" "5h 30m" "2024-01-15 10:30"
assert_file_exists "history created" "$HISTORY_FILE"
assert_file_contains "logs state" "$HISTORY_FILE" "2024-01-15 10:30 | during_work | 5h 30m"

# Updates state file
reset_data
log_state_change "free_day" "10h" "2024-01-15 10:30"
assert_eq "state file updated" "free_day" "$(cat "$STATE_FILE")"

# Same state does not log
reset_data
printf '%s' "during_work" > "$STATE_FILE"
log_state_change "during_work" "4h" "2024-01-15 11:00"
assert_file_not_exists "no log for same state" "$HISTORY_FILE"

# State transition logs
reset_data
printf '%s' "during_work" > "$STATE_FILE"
log_state_change "after_work" "free!" "2024-01-15 18:00"
assert_file_exists "logs on transition" "$HISTORY_FILE"
assert_file_contains "logs new state" "$HISTORY_FILE" "after_work"

# ============================================================
# state determination tests
# ============================================================

echo "--- state determination ---"

determine_state() {
  local current_mins=$1 day_of_week=$2 work_days_str=$3 work_start_min=$4 work_end_min=$5
  local is_work_day=false
  IFS=',' read -ra days <<< "$work_days_str"
  for d in "${days[@]}"; do
    [ "$d" = "$day_of_week" ] && is_work_day=true
  done

  if [ "$is_work_day" = false ]; then
    echo "free_day"
  elif [ "$current_mins" -lt "$work_start_min" ]; then
    echo "before_work"
  elif [ "$current_mins" -lt "$work_end_min" ]; then
    echo "during_work"
  else
    echo "after_work"
  fi
}

# Sunday (7) not in work days
assert_eq "free day sunday" "free_day" "$(determine_state 600 7 "1,2,3,4,5" 540 1020)"
# Saturday (6) not in work days
assert_eq "free day saturday" "free_day" "$(determine_state 600 6 "1,2,3,4,5" 540 1020)"
# Monday 8:00 (480), work starts 9:00 (540)
assert_eq "before work" "before_work" "$(determine_state 480 1 "1,2,3,4,5" 540 1020)"
# Monday 12:00 (720), work 9:00-17:00
assert_eq "during work" "during_work" "$(determine_state 720 1 "1,2,3,4,5" 540 1020)"
# Monday exactly 9:00 (540)
assert_eq "during work at start" "during_work" "$(determine_state 540 1 "1,2,3,4,5" 540 1020)"
# Monday 18:00 (1080), work ends 17:00
assert_eq "after work" "after_work" "$(determine_state 1080 1 "1,2,3,4,5" 540 1020)"
# Monday exactly 17:00 (1020)
assert_eq "after work at end" "after_work" "$(determine_state 1020 1 "1,2,3,4,5" 540 1020)"

# ============================================================
# countdown calculation tests
# ============================================================

echo "--- countdown ---"

calculate_countdown() {
  local state=$1 current_mins=$2 work_start_min=$3 work_end_min=$4 sleep_min=1440
  case "$state" in
    free_day|before_work|after_work) echo $((sleep_min - current_mins)) ;;
    during_work) echo $((work_end_min - current_mins)) ;;
  esac
}

assert_eq "free day countdown" "840" "$(calculate_countdown free_day 600 540 1020)"
assert_eq "before work countdown" "960" "$(calculate_countdown before_work 480 540 1020)"
assert_eq "during work countdown" "300" "$(calculate_countdown during_work 720 540 1020)"
assert_eq "after work countdown" "360" "$(calculate_countdown after_work 1080 540 1020)"

# ============================================================
# day of week conversion tests
# ============================================================

echo "--- day of week ---"

convert_wday() { [ "$1" = "0" ] && echo 7 || echo "$1"; }

assert_eq "sunday converts" "7" "$(convert_wday 0)"
assert_eq "monday stays" "1" "$(convert_wday 1)"
assert_eq "saturday stays" "6" "$(convert_wday 6)"

# ============================================================
# work days toggle tests
# ============================================================

echo "--- work days toggle ---"

toggle_work_day() {
  local work_days_str=$1 day=$2
  local found=false new_days=""
  IFS=',' read -ra days <<< "$work_days_str"
  for d in "${days[@]}"; do
    if [ "$d" = "$day" ]; then
      found=true
    else
      new_days="${new_days:+$new_days,}$d"
    fi
  done
  if [ "$found" = false ]; then
    new_days="$work_days_str,$day"
    new_days=$(echo "$new_days" | tr ',' '\n' | sort -n | tr '\n' ',' | sed 's/,$//')
  fi
  echo "$new_days"
}

assert_eq "remove day" "1,2,4,5" "$(toggle_work_day "1,2,3,4,5" 3)"
assert_eq "add day" "1,2,3,4,5" "$(toggle_work_day "1,2,4,5" 3)"
assert_eq "add maintains sort" "1,3,5" "$(toggle_work_day "1,5" 3)"

# ============================================================
# Results
# ============================================================

echo ""
echo "================================"
echo "$((PASS + FAIL)) tests, $PASS passed, $FAIL failed"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
