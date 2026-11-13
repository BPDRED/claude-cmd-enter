#!/bin/bash
# Builds build/ClaudeCmdEnter.app as a universal app (Intel + Apple Silicon).
# Needs only Apple's Command Line Tools (swiftc, lipo, codesign). No Xcode.
set -euo pipefail
cd "$(dirname "$0")"

NAME="ClaudeCmdEnter"
APP="build/$NAME.app"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 1. Compile once for each kind of Mac.
for ARCH in x86_64 arm64; do
    echo "Compiling for $ARCH..."
    swiftc -O -target "$ARCH-apple-macos12" -o "build/$NAME-$ARCH" Sources/*.swift
done

# 2. Join the two into one universal program.
lipo -create "build/$NAME-x86_64" "build/$NAME-arm64" -output "$APP/Contents/MacOS/$NAME"
rm "build/$NAME-x86_64" "build/$NAME-arm64"

# 3. Draw the app icon (tools/make_icon.swift) and pack it into AppIcon.icns.
echo "Drawing the app icon..."
swift tools/make_icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf build/AppIcon.iconset

# 4. Add the Info.plist and sign locally ("ad-hoc": no Apple account, no network).
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo
lipo -info "$APP/Contents/MacOS/$NAME"
echo "Built: $APP"
