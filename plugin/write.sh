#!/bin/bash
FILE="$1"
CONTENT="$2"

# Write and ensure complete
printf '%s' "$CONTENT" > "$FILE"
sync

# Wait for menu to fully close
sleep 0.05

# Single, deliberate refresh
open -g "swiftbar://refreshallplugins"

exit 0
