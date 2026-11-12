#!/bin/bash
# Builds build/ClaudeCmdEnter.app as a universal app (Intel + Apple Silicon).
# Needs only Apple's Command Line Tools (swiftc, lipo, codesign). No Xcode.
set -euo pipefail
cd "$(dirname "$0")"

NAME="ClaudeCmdEnter"
APP="build/$NAME.app"

rm -rf build
mkdir -p "$APP/Contents/MacOS"

# 1. Compile once for each kind of Mac.
for ARCH in x86_64 arm64; do
    echo "Compiling for $ARCH..."
    swiftc -O -target "$ARCH-apple-macos12" -o "build/$NAME-$ARCH" main.swift
done

# 2. Join the two into one universal program.
lipo -create "build/$NAME-x86_64" "build/$NAME-arm64" -output "$APP/Contents/MacOS/$NAME"
rm "build/$NAME-x86_64" "build/$NAME-arm64"

# 3. Add the Info.plist and sign locally ("ad-hoc": no Apple account, no network).
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo
lipo -info "$APP/Contents/MacOS/$NAME"
echo "Built: $APP"
