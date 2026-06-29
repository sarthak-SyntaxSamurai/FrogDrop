#!/usr/bin/env bash
# FrogDrop Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/sarthak-SyntaxSamurai/FrogDrop/main/install.sh | bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${GREEN}🐸 FrogDrop Installer${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "❌ FrogDrop is macOS only."
  exit 1
fi

LATEST_URL="https://github.com/sarthak-SyntaxSamurai/FrogDrop/releases/latest/download/FrogDrop.dmg"
TEMP_DMG="/tmp/FrogDrop_install.dmg"
MOUNT_POINT="/tmp/FrogDropMount"
INSTALL_DIR="/Applications"

echo -e "${BLUE}⬇️  Downloading FrogDrop...${NC}"
curl -L --progress-bar "$LATEST_URL" -o "$TEMP_DMG"

echo -e "${BLUE}📦 Mounting disk image...${NC}"
hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_POINT" -quiet -nobrowse

echo -e "${BLUE}📋 Copying to Applications...${NC}"
if [ -d "$INSTALL_DIR/FrogDrop.app" ]; then
  rm -rf "$INSTALL_DIR/FrogDrop.app"
fi
cp -r "$MOUNT_POINT/FrogDrop.app" "$INSTALL_DIR/"

echo -e "${BLUE}🔓 Removing macOS quarantine flag...${NC}"
xattr -cr "$INSTALL_DIR/FrogDrop.app"

echo -e "${BLUE}💿 Cleaning up...${NC}"
hdiutil detach "$MOUNT_POINT" -quiet
rm -f "$TEMP_DMG"

echo ""
echo -e "${GREEN}✅ FrogDrop installed successfully!${NC}"
echo ""
echo -e "${YELLOW}🚀 Launch it from Spotlight: Cmd+Space → FrogDrop${NC}"
echo -e "${YELLOW}   Or open /Applications/FrogDrop.app${NC}"
echo ""
