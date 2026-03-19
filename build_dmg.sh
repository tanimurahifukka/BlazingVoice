#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$PROJECT_DIR/BlazingVoice.xcodeproj"
SCHEME="BlazingVoice"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="BlazingVoice"
DMG_NAME="BlazingVoice"
VERSION=$(defaults read "$PROJECT_DIR/BlazingVoice/Resources/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")

echo "=== BlazingVoice DMG Builder ==="
echo "Version: $VERSION"

# Clean build
echo ">>> Cleaning..."
rm -rf "$BUILD_DIR"

# Build for Release
echo ">>> Building Release..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    2>&1 | tail -5

# Find the built app
ARCHIVE_APP="$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app"
if [ ! -d "$ARCHIVE_APP" ]; then
    echo "ERROR: Archive app not found at $ARCHIVE_APP"
    echo "Trying DerivedData..."
    ARCHIVE_APP=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME.app" -path "*/Release/*" | head -1)
    if [ -z "$ARCHIVE_APP" ] || [ ! -d "$ARCHIVE_APP" ]; then
        echo "ERROR: Could not find built app"
        exit 1
    fi
fi
echo ">>> Found app: $ARCHIVE_APP"

# Create DMG staging
DMG_STAGE="$BUILD_DIR/dmg_stage"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"

# Copy app
cp -R "$ARCHIVE_APP" "$DMG_STAGE/"

# Add Applications symlink
ln -s /Applications "$DMG_STAGE/Applications"

# Create DMG
DMG_OUTPUT="$PROJECT_DIR/$DMG_NAME-$VERSION.dmg"
rm -f "$DMG_OUTPUT"

echo ">>> Creating DMG..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT"

# Cleanup
rm -rf "$BUILD_DIR"

echo ""
echo "=== Done! ==="
echo "DMG: $DMG_OUTPUT"
echo "Size: $(du -h "$DMG_OUTPUT" | cut -f1)"
