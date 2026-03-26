#!/bin/bash
set -e

# QuickTranslate DMG Build Script

PROJECT_DIR="/Users/sean/Documents/QuickTranslate"
PROJECT_FILE="$PROJECT_DIR/QuickTranslate.xcodeproj"
SCHEME="QuickTranslate"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"
APP_NAME="QuickTranslate"
DMG_NAME="QuickTranslate-1.0.dmg"
VOLUME_NAME="QuickTranslate"
TEMP_DMG="$DIST_DIR/temp_$DMG_NAME"
FINAL_DMG="$DIST_DIR/$DMG_NAME"
SIGNING_IDENTITY="Developer ID Application: SHINWOO KIM (489VU5V5M5)"

echo "========================================"
echo "  QuickTranslate DMG Build"
echo "========================================"

echo ""
echo "[1/6] Checking xcodebuild..."
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild not found. Please install Xcode."
    exit 1
fi
echo "  Found: $(xcodebuild -version | head -1)"

echo ""
echo "[2/6] Cleaning previous build artifacts..."
rm -rf "$BUILD_DIR"
rm -f "$FINAL_DMG"
rm -f "$TEMP_DMG"
mkdir -p "$DIST_DIR"
echo "  Done"

echo ""
echo "[3/6] Building app (Release)..."
xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    clean build \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    ENABLE_HARDENED_RUNTIME=YES \
    2>&1 | grep -E "^(Build|error:|warning:|note:|CompileSwift|Ld |Copy |=)" || true

APP_PATH=$(find "$BUILD_DIR" -name "$APP_NAME.app" -path "*/Release/*" | head -1)
if [ -z "$APP_PATH" ]; then
    echo "Error: Built app not found."
    exit 1
fi
echo "  Build complete: $APP_PATH"

echo ""
echo "[4/6] Signing app with: $SIGNING_IDENTITY"
codesign --force --deep --options runtime --sign "$SIGNING_IDENTITY" "$APP_PATH"
codesign --verify --verbose "$APP_PATH" 2>&1
echo "  Signing complete"

echo ""
echo "[5/6] Creating DMG..."

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

cp -R "$APP_PATH" "$TEMP_DIR/"
ln -s /Applications "$TEMP_DIR/Applications"

APP_SIZE_KB=$(du -sk "$APP_PATH" | cut -f1)
DMG_SIZE_KB=$((APP_SIZE_KB + 10240))

hdiutil create \
    -srcfolder "$TEMP_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,b=16" \
    -format UDRW \
    -size "${DMG_SIZE_KB}k" \
    "$TEMP_DMG" \
    -quiet

hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$FINAL_DMG" \
    -quiet

rm -f "$TEMP_DMG"

echo "  DMG created: $FINAL_DMG"

echo ""
echo "[6/6] Done!"
echo ""
echo "========================================"
echo "  DMG build successful!"
echo "  Location: $FINAL_DMG"
DMG_SIZE=$(du -sh "$FINAL_DMG" | cut -f1)
echo "  Size: $DMG_SIZE"
echo "  Signed with: $SIGNING_IDENTITY"
echo "========================================"
