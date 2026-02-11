#!/bin/bash
# Builds YT Mac Player as a signed, notarized .app bundle and packages it into a DMG.
# Prerequisites: Developer ID certificate installed, notarytool credentials stored as "notarytool".
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="YT Mac Player"
BUNDLE_NAME="$APP_NAME.app"
BUILD_DIR="$PROJECT_DIR/.build/release"
DIST_DIR="$PROJECT_DIR/dist"
DMG_NAME="YT-Mac-Player"
SIGN_IDENTITY="Developer ID Application: Santiago Alonso Alexandre (QAMM2A6WRQ)"

echo "=== Building release binary ==="
cd "$PROJECT_DIR"
swift build -c release 2>&1

echo ""
echo "=== Creating app bundle ==="
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/$BUNDLE_NAME/Contents/MacOS"
mkdir -p "$DIST_DIR/$BUNDLE_NAME/Contents/Resources"

# Copy the binary
cp "$BUILD_DIR/YTMacPlayer" "$DIST_DIR/$BUNDLE_NAME/Contents/MacOS/"

# Copy Info.plist
cp "$PROJECT_DIR/Info.plist" "$DIST_DIR/$BUNDLE_NAME/Contents/"

# Copy the icon
cp "$PROJECT_DIR/AppIcon.icns" "$DIST_DIR/$BUNDLE_NAME/Contents/Resources/"

echo "  App bundle created at: $DIST_DIR/$BUNDLE_NAME"

echo ""
echo "=== Code signing app bundle ==="
codesign --deep --force --options runtime \
    --sign "$SIGN_IDENTITY" \
    "$DIST_DIR/$BUNDLE_NAME"
echo "  App signed successfully"

# Verify the signature
codesign --verify --verbose "$DIST_DIR/$BUNDLE_NAME"
echo "  Signature verified"

echo ""
echo "=== Creating DMG ==="
# Remove old DMG if it exists
rm -f "$DIST_DIR/$DMG_NAME.dmg"

# Create a temporary folder for the DMG contents
DMG_TEMP="$DIST_DIR/dmg-temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy app into the temp folder
cp -R "$DIST_DIR/$BUNDLE_NAME" "$DMG_TEMP/"

# Create a symlink to /Applications for easy drag-install
ln -s /Applications "$DMG_TEMP/Applications"

# Create the DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DIST_DIR/$DMG_NAME.dmg" 2>&1

# Clean up temp folder
rm -rf "$DMG_TEMP"

echo ""
echo "=== Signing DMG ==="
codesign --force --sign "$SIGN_IDENTITY" "$DIST_DIR/$DMG_NAME.dmg"
echo "  DMG signed successfully"

echo ""
echo "=== Notarizing DMG ==="
echo "  Submitting to Apple notary service (this may take a few minutes)..."
xcrun notarytool submit "$DIST_DIR/$DMG_NAME.dmg" \
    --keychain-profile "notarytool" \
    --wait
echo "  Notarization complete"

echo ""
echo "=== Stapling notarization ticket ==="
xcrun stapler staple "$DIST_DIR/$DMG_NAME.dmg"
echo "  Ticket stapled"

echo ""
echo "=== Done ==="
echo "  DMG: $DIST_DIR/$DMG_NAME.dmg (signed + notarized)"
echo "  App: $DIST_DIR/$BUNDLE_NAME (signed)"
echo ""
echo "To install: open the DMG and drag 'YT Mac Player' to Applications."
echo ""
echo "Verify with:"
echo "  codesign --verify --verbose \"$DIST_DIR/$BUNDLE_NAME\""
echo "  spctl --assess --verbose \"$DIST_DIR/$BUNDLE_NAME\""
