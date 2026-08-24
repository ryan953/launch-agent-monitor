#!/bin/bash
# Installs the BGMonitor demo LaunchAgent: copies its script and a
# {{HOME}}/{{USER}}-substituted plist into the real LaunchAgents/Logs
# locations. Does NOT register it with launchd — open BGMonitor and click
# Register on it there, so the demo also exercises that button.
set -euo pipefail

LABEL="com.ryan953.bemonitor.demo.hello"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPT_DEST="$HOME/Library/Application Support/BGMonitor/demo/hello.sh"
PLIST_DEST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs/$LABEL"

mkdir -p "$(dirname "$SCRIPT_DEST")"
mkdir -p "$LOG_DIR"

cp "$DEMO_DIR/hello.sh" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"

sed \
	-e "s|{{HOME}}|$HOME|g" \
	-e "s|{{USER}}|$(whoami)|g" \
	"$DEMO_DIR/$LABEL.plist" > "$PLIST_DEST"

echo "Installed $LABEL"
echo "  script: $SCRIPT_DEST"
echo "  plist:  $PLIST_DEST"
echo "  logs:   $LOG_DIR"
echo
echo "Left unregistered — open BGMonitor and click Register on '$LABEL' to load it."
