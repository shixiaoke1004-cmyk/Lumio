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

# Re-sign ad-hoc for distribution: the build is signed with the local
# "Lumio Self-Signed" cert, which other machines don't trust — combined with
# hardened runtime this makes dyld reject the embedded framework there
# ("different Team IDs"). Ad-hoc signatures need no trust chain, and dropping
# --options runtime disables library validation entirely.
codesign --force --deep --sign - "$STAGING/Lumio.app"
codesign --verify --deep --strict "$STAGING/Lumio.app"

hdiutil create \
    -volname "Lumio $VERSION" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG"
rm -rf "$STAGING"

echo "Created $DMG"
echo "note: the app is ad-hoc signed; on other machines, right-click > Open the"
echo "      first time to bypass Gatekeeper."
echo "note: for public distribution, codesign with a Developer ID and notarize:"
echo "  codesign --deep --force --options runtime --sign 'Developer ID Application: ...' <app>"
echo "  xcrun notarytool submit $DMG --keychain-profile <profile> --wait"
