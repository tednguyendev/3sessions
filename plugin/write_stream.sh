#!/bin/bash
# Simple write - streamable plugin will detect change and refresh
FILE="$1"
CONTENT="$2"
printf '%s' "$CONTENT" > "$FILE"
