#!/bin/bash
set -e

APP_NAME="OptionTab"
BUILD_DIR=".build/release"
APP_BUNDLE="$HOME/Applications/$APP_NAME.app"

echo "==> Building (this needs Xcode Command Line Tools: xcode-select --install)..."
swift build -c release

echo "==> Packaging as $APP_BUNDLE ..."
mkdir -p "$HOME/Applications"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

echo "==> Ad-hoc code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Done."
echo ""
echo "Launching $APP_NAME..."
open "$APP_BUNDLE"

echo ""
echo "IMPORTANT — first launch only:"
echo "  macOS will ask for Accessibility permission."
echo "  Go to System Settings > Privacy & Security > Accessibility,"
echo "  enable OptionTab, then quit and relaunch it from ~/Applications."
echo ""
echo "Usage: hold Option, tap Tab to cycle forward (Shift+Tab back),"
echo "release Option to switch, Esc to cancel."
