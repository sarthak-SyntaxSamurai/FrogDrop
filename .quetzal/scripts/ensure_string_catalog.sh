#!/usr/bin/env bash

set -euo pipefail

# Usage:
#   ./.quetzal/scripts/ensure_string_catalog.sh [project_path] [target_name]

PROJECT_PATH="${1:-}"
TARGET_NAME="${2:-}"

# Find first .xcodeproj if not provided
if [ -z "$PROJECT_PATH" ]; then
    PROJECT_PATH=$(find . -name "*.xcodeproj" -type d | head -n 1)
    if [ -z "$PROJECT_PATH" ]; then
        echo "❌ No .xcodeproj found"
        exit 1
    fi
fi

# Check if ANY .xcstrings already exist in the repo
XCSTRINGS_FILES=$(find . -name "*.xcstrings" -type f 2>/dev/null || true)

if [ -n "$XCSTRINGS_FILES" ]; then
    echo "✅ Found existing String Catalog(s):"
    VALID_FOUND=0
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        echo "  - $file"
                # Validate each file (JSON check - Xcode format)
                if [ -f "$file" ]; then
                    FILE_SIZE=$(wc -c < "$file" | xargs)
                    INVALID=0
                    
                    # Check file size
                    if [ "$FILE_SIZE" -lt 50 ]; then
                        echo "    ⚠️  File is too small ($FILE_SIZE bytes), will be recreated"
                        INVALID=1
                    # Validate format - check if it's valid JSON (Xcode format)
                    elif ! python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
                        echo "    ⚠️  File is not valid JSON, will be recreated"
                        INVALID=1
                    fi
            
            if [ "$INVALID" -eq 1 ]; then
                rm -f "$file" && echo "    🗑️  Removed invalid file: $file"
            else
                VALID_FOUND=1
            fi
        fi
    done <<< "$XCSTRINGS_FILES"
    
    # If we found at least one valid file, exit
    if [ "$VALID_FOUND" -eq 1 ]; then
        echo "✅ Valid String Catalog(s) found, using existing file(s)"
    exit 0
    else
        echo "ℹ️  Existing files were invalid and removed, will create new one..."
    fi
fi

echo "ℹ️ No .xcstrings found. Creating a new Localizable.xcstrings..."

# Decide where to put the file - try common locations
LOCATIONS=(
    "Resources/Localizable.xcstrings"
    "Localizable.xcstrings"
    "$(dirname "$PROJECT_PATH")/Resources/Localizable.xcstrings"
)

XCSTRINGS_PATH=""
for location in "${LOCATIONS[@]}"; do
    if [ -d "$(dirname "$location")" ] || [ "$(dirname "$location")" = "." ]; then
        XCSTRINGS_PATH="$location"
        break
    fi
done

# Default to Resources/ if directory exists, otherwise root
if [ -z "$XCSTRINGS_PATH" ]; then
    if [ -d "Resources" ]; then
        XCSTRINGS_PATH="Resources/Localizable.xcstrings"
    else
        XCSTRINGS_PATH="Localizable.xcstrings"
    fi
fi

# Ensure directory exists
mkdir -p "$(dirname "$XCSTRINGS_PATH")"

# Create minimal valid String Catalog in JSON format (as Xcode expects)
# Xcode creates .xcstrings files as JSON, not XML plist
# This matches the format Xcode uses when creating a new String Catalog
if [ ! -f "$XCSTRINGS_PATH" ]; then
    # Create file matching Xcode's exact template format
    # Xcode creates .xcstrings files with this exact structure and formatting
    # Using printf to ensure ASCII encoding (us-ascii) without BOM, matching Xcode's output
    printf '%s\n' \
      '{' \
      '  "sourceLanguage" : "en",' \
      '  "strings" : {' \
      '' \
      '  },' \
      '  "version" : "1.1"' \
      '}' > "$XCSTRINGS_PATH"
    
    # Validate the created file
    echo "🔍 Validating created file..."
    
    # Check file encoding (should be us-ascii, matching Xcode)
    if command -v file &> /dev/null; then
        ENCODING=$(file -b --mime-encoding "$XCSTRINGS_PATH" 2>/dev/null || echo "unknown")
        echo "  File encoding: $ENCODING"
        if [ "$ENCODING" != "us-ascii" ] && [ "$ENCODING" != "ascii" ]; then
            echo "  ⚠️  Warning: File encoding is $ENCODING, expected us-ascii (like Xcode creates)"
        fi
    fi
    
    # Check JSON validity
    if python3 -c "import json; json.load(open('$XCSTRINGS_PATH'))" 2>/dev/null; then
        echo "✅ File is valid JSON"
    else
        echo "❌ File is NOT valid JSON!"
        cat "$XCSTRINGS_PATH"
        exit 1
    fi
    
    # Note: plutil -lint may fail on JSON files, but that's expected and not a problem
    # Xcode string catalogs are JSON format, not XML plist
    # The file type in the Xcode project (not the file format) determines how it's processed
    
    echo "✅ Created $XCSTRINGS_PATH in JSON format (Xcode-compatible)"
else
    echo "ℹ️ $XCSTRINGS_PATH already exists"
    # Ensure it's valid JSON (Xcode format)
    if python3 -c "import json; json.load(open('$XCSTRINGS_PATH'))" 2>/dev/null; then
        echo "✅ Existing file is valid JSON"
        
        # Note: plutil -lint may fail on JSON files, but that's expected and not a problem
        # Xcode string catalogs are JSON format, not XML plist
    else
        echo "⚠️  Existing file is not valid JSON, recreating..."
        # Recreate with Xcode's exact template format (ASCII encoding)
        printf '%s\n' \
          '{' \
          '  "sourceLanguage" : "en",' \
          '  "strings" : {' \
          '' \
          '  },' \
          '  "version" : "1.1"' \
          '}' > "$XCSTRINGS_PATH"
        
        # Validate recreated file
        if python3 -c "import json; json.load(open('$XCSTRINGS_PATH'))" 2>/dev/null; then
            echo "✅ Recreated file is valid JSON"
        else
            echo "❌ Recreated file is still invalid!"
            exit 1
        fi
    fi
fi

echo "✅ String catalog ready at: $XCSTRINGS_PATH"
echo "ℹ️ Note: You may need to add this file to your Xcode project manually,"
echo "   or Xcode will auto-detect it when you build with SWIFT_EMIT_LOC_STRINGS=YES"

