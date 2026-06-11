#!/bin/bash
# Builds a Release Lumio.app and packages it into dist/Lumio-<version>.dmg.
set -euo pipefail

cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || { echo "error: xcodegen not installed" >&2; exit 1; }

xcodegen generate

DERIVED=$(mktemp -d /tmp/lumio-build.XXXXXX)
trap 'rm -rf "$DERIVED"' EXIT

xcodebuild \
    -project Lumio.xcodeproj \
    -scheme Lumio \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    build

APP="$DERIVED/Build/Products/Release/Lumio.app"
[ -d "$APP" ] || { echo "error: build output not found" >&2; exit 1; }

VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)
DMG="dist/Lumio-$VERSION.dmg"

mkdir -p dist
rm -f "$DMG"

STAGING=$(mktemp -d /tmp/lumio-dmg.XXXXXX)
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "Lumio $VERSION" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG"
rm -rf "$STAGING"

echo "Created $DMG"
echo "note: for public distribution, codesign with a Developer ID and notarize:"
echo "  codesign --deep --force --options runtime --sign 'Developer ID Application: ...' <app>"
echo "  xcrun notarytool submit $DMG --keychain-profile <profile> --wait"
