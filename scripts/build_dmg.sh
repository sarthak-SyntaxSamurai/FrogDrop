#!/usr/bin/env bash
# FrogDrop DMG Builder Script
# Packages FrogDrop.app into a compact, snugly fitted Retina installer DMG with native multi-resolution TIFF.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$PROJECT_ROOT/FrogDrop.app"
BG_TIFF="$PROJECT_ROOT/assets/dmg/dmg_bg.tiff"
ICON_PNG="$PROJECT_ROOT/assets/branding/FrogDropIcon.png"
OUTPUT_DMG="$PROJECT_ROOT/FrogDrop.dmg"
TEMP_DMG_DIR="$PROJECT_ROOT/.tmp/dmg_source"

echo "🐸 Starting FrogDrop Retina DMG Packaging..."

# 1. Regenerate background TIFF
python3 "$SCRIPT_DIR/generate_dmg_bg.py"

# 2. Build release binary and update FrogDrop.app bundle
echo "🔨 Building latest FrogDrop release binary..."
cd "$PROJECT_ROOT"
swift build -c release
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$PROJECT_ROOT/.build/arm64-apple-macosx/release/FrogDrop" "$APP_PATH/Contents/MacOS/FrogDrop"
chmod +x "$APP_PATH/Contents/MacOS/FrogDrop"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 2.1.0" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 2.1.0" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
codesign --force --deep --sign - "$APP_PATH" 2>/dev/null || true

# 3. Clean previous build artifacts
rm -rf "$OUTPUT_DMG" "$TEMP_DMG_DIR"
mkdir -p "$TEMP_DMG_DIR"

# Copy FrogDrop.app into temporary staging directory
cp -R "$APP_PATH" "$TEMP_DMG_DIR/"

# 4. Locate create-dmg
CREATE_DMG_BIN="$(command -v create-dmg || echo "/opt/homebrew/bin/create-dmg")"

# 5. Use create-dmg to assemble the final disk image
# Window Size: 500 x 300
# Icon Size: 96
# FrogDrop.app position: 130 170
# Applications symlink position: 370 170
echo "📦 Packaging DMG with create-dmg..."
"$CREATE_DMG_BIN" \
  --volname "FrogDrop" \
  --volicon "$ICON_PNG" \
  --background "$BG_TIFF" \
  --window-pos 240 160 \
  --window-size 500 300 \
  --icon-size 96 \
  --text-size 12 \
  --icon "FrogDrop.app" 130 170 \
  --app-drop-link 370 170 \
  --hide-extension "FrogDrop.app" \
  --no-internet-enable \
  "$OUTPUT_DMG" \
  "$TEMP_DMG_DIR" || true

# 6. Clean up temporary staging directory
rm -rf "$TEMP_DMG_DIR"

if [ -f "$OUTPUT_DMG" ]; then
  echo "✅ FrogDrop.dmg created successfully at $OUTPUT_DMG"
  ls -lh "$OUTPUT_DMG"
else
  echo "❌ Error: DMG creation failed."
  exit 1
fi
