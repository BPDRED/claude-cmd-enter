#!/bin/bash
# Builds the app, copies it to ~/Applications, makes it start at login, and starts it.
# It changes only two things on this Mac:
#   ~/Applications/ClaudeCmdEnter.app
#   ~/Library/LaunchAgents/local.claudecmdenter.plist   (the "start at login" file)
set -euo pipefail
cd "$(dirname "$0")"

NAME="ClaudeCmdEnter"
LABEL="local.claudecmdenter"
APP="$HOME/Applications/$NAME.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

./build.sh

# Stop an older copy if one is running, and wait until it is really gone.
launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
pkill -x "$NAME" 2>/dev/null || true
while launchctl print "gui/$UID/$LABEL" >/dev/null 2>&1; do sleep 0.2; done

# Copy the app.
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
rm -rf "$APP"
cp -R "build/$NAME.app" "$APP"
# Tell macOS about the new copy, so Finder and System Settings show the new
# icon instead of an old cached one.
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" || true

# Start-at-login file. RunAtLoad = start at login. There is no KeepAlive,
# so "Quit" in the menu really quits (until the next login).
# ProcessType Interactive = macOS must not slow the helper down (keys stay instant).
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP/Contents/MacOS/$NAME</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>AssociatedBundleIdentifiers</key>
    <array>
        <string>$LABEL</string>
    </array>
</dict>
</plist>
EOF

# Start it now (and at every login from now on).
launchctl bootstrap "gui/$UID" "$PLIST"

echo
echo "Installed: $APP"
echo "Starts at login: $PLIST"
echo
echo "LAST STEP (only you can do it):"
echo "  System Settings > Privacy & Security > Accessibility > turn ON 'ClaudeCmdEnter'."
echo "  Open that page with:"
echo "  open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'"
