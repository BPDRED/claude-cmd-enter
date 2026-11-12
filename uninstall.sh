#!/bin/bash
# Removes the helper: stops it, deletes the start-at-login file and the app.
# It touches nothing else. Claude itself is never changed.
set -euo pipefail

NAME="ClaudeCmdEnter"
LABEL="local.claudecmdenter"
APP="$HOME/Applications/$NAME.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
pkill -x "$NAME" 2>/dev/null || true

rm -f "$PLIST"
rm -rf "$APP"

echo "Removed: $APP"
echo "Removed: $PLIST"
echo
echo "Optional clean-up (see INSTALL.md, 'Uninstall'):"
echo "  tccutil reset Accessibility $LABEL     # forget the permission"
echo "  defaults delete $LABEL                 # forget the On/Off setting"
