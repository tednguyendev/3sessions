#!/bin/bash
set -e

INSTALL_DIR="$HOME/.3sessions"
PLUGIN_DIR="$HOME/Library/Application Support/SwiftBar/Plugins"

# Clone or update
if [ -d "$INSTALL_DIR" ]; then
  echo "Updating 3sessions..."
  cd "$INSTALL_DIR" && git pull
else
  echo "Installing 3sessions..."
  git clone https://github.com/tednguyendev/3sessions.git "$INSTALL_DIR"
fi

# Symlink plugin
mkdir -p "$PLUGIN_DIR"
ln -sf "$INSTALL_DIR/plugin/3sessions.1m.sh" "$PLUGIN_DIR/3sessions.1m.sh"

echo "Done! Start SwiftBar if it's not running: open -a SwiftBar"
