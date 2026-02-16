#!/bin/bash
set -e

INSTALL_DIR="$HOME/.3sessions"
PLUGIN_DIR="$HOME/Library/Application Support/SwiftBar/Plugins"
BASE_URL="https://raw.githubusercontent.com/tednguyendev/3sessions/main/plugin"

mkdir -p "$INSTALL_DIR"
mkdir -p "$PLUGIN_DIR"

echo "Installing 3sessions..."
curl -sL "$BASE_URL/3sessions.1m.sh" -o "$INSTALL_DIR/3sessions.1m.sh"
curl -sL "$BASE_URL/write.sh" -o "$INSTALL_DIR/write.sh"
chmod +x "$INSTALL_DIR/3sessions.1m.sh" "$INSTALL_DIR/write.sh"

ln -sf "$INSTALL_DIR/3sessions.1m.sh" "$PLUGIN_DIR/3sessions.1m.sh"

echo "Done! Start SwiftBar if it's not running: open -a SwiftBar"
