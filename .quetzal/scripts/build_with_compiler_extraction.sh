#!/usr/bin/env bash

set -uo pipefail  # Remove -e to allow graceful error handling

# Accept BUILD_PATH (workspace or project for xcodebuild) and optionally XCODEPROJ_PATH (for Ruby scripts)
# Usage: build_with_compiler_extraction.sh <BUILD_PATH> <SCHEME> [CONFIGURATION] [XCODEPROJ_PATH]
BUILD_PATH="${1:-YourApp.xcodeproj}"
SCHEME="${2:-YourApp}"
CONFIGURATION="${3:-Debug}"
XCODEPROJ_PATH="${4:-}"

# Detect if BUILD_PATH is a workspace or project
BUILD_TYPE="project"
if echo "$BUILD_PATH" | grep -q "\.xcworkspace$"; then
  BUILD_TYPE="workspace"
  echo "✅ Build path is workspace: $BUILD_PATH"
  
  # Derive XCODEPROJ_PATH from workspace if not provided
  if [ -z "$XCODEPROJ_PATH" ]; then
    # If workspace is inside .xcodeproj (e.g., CodeEdit.xcodeproj/project.xcworkspace)
    if echo "$BUILD_PATH" | grep -q "\.xcodeproj/project\.xcworkspace$"; then
      XCODEPROJ_PATH=$(echo "$BUILD_PATH" | sed 's|/project\.xcworkspace$||')
      echo "✅ Derived project path from workspace: $XCODEPROJ_PATH"
    else
      # Standalone workspace - try to find associated .xcodeproj
      WORKSPACE_DIR=$(dirname "$BUILD_PATH")
      XCODEPROJ_PATH=$(find "$WORKSPACE_DIR" -maxdepth 2 -name "*.xcodeproj" -type d | head -n 1)
      if [ -n "$XCODEPROJ_PATH" ]; then
        echo "✅ Found associated project: $XCODEPROJ_PATH"
      else
        echo "⚠️  Could not find associated .xcodeproj for workspace"
        echo "   Ruby scripts may fail - please provide XCODEPROJ_PATH as 4th argument"
      fi
    fi
  fi
elif [ -d "$BUILD_PATH/project.xcworkspace" ]; then
  # Common pattern: workspace inside .xcodeproj
  BUILD_TYPE="workspace"
  WORKSPACE_PATH="$BUILD_PATH/project.xcworkspace"
  echo "✅ Found workspace inside project: $WORKSPACE_PATH"
  BUILD_PATH="$WORKSPACE_PATH"
  # XCODEPROJ_PATH is the parent .xcodeproj
  if [ -z "$XCODEPROJ_PATH" ]; then
    XCODEPROJ_PATH=$(dirname "$BUILD_PATH")
    echo "✅ Using project path: $XCODEPROJ_PATH"
  fi
elif [ -d "$BUILD_PATH" ] && [ -f "$BUILD_PATH/project.pbxproj" ]; then
  BUILD_TYPE="project"
  echo "✅ Build path is project: $BUILD_PATH"
  # If XCODEPROJ_PATH not provided, use BUILD_PATH
  if [ -z "$XCODEPROJ_PATH" ]; then
    XCODEPROJ_PATH="$BUILD_PATH"
    echo "✅ Using same path for project operations: $XCODEPROJ_PATH"
  fi
else
  echo "⚠️  Could not determine build type, assuming project"
  BUILD_TYPE="project"
  if [ -z "$XCODEPROJ_PATH" ]; then
    XCODEPROJ_PATH="$BUILD_PATH"
  fi
fi

# Verify XCODEPROJ_PATH exists and is a valid .xcodeproj
if [ -n "$XCODEPROJ_PATH" ] && [ ! -f "$XCODEPROJ_PATH/project.pbxproj" ]; then
  echo "⚠️  WARNING: XCODEPROJ_PATH '$XCODEPROJ_PATH' does not contain project.pbxproj"
  echo "   Ruby scripts that modify the project may fail"
fi

# Use isolated DerivedData if provided (prevents corruption from previous runs)
# This should be set by the workflow before calling this script
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-}"

# Helper function to build xcodebuild command with correct project/workspace flag
# Automatically includes -derivedDataPath if DERIVED_DATA_PATH is set
xcodebuild_cmd() {
  local cmd_args=()
  if [ "$BUILD_TYPE" = "workspace" ]; then
    cmd_args+=(-workspace "$BUILD_PATH")
  else
    cmd_args+=(-project "$BUILD_PATH")
  fi
  cmd_args+=(-scheme "$SCHEME")
  
  # Add derivedDataPath if provided (critical for avoiding corruption)
  if [ -n "$DERIVED_DATA_PATH" ]; then
    cmd_args+=(-derivedDataPath "$DERIVED_DATA_PATH")
  fi
  
  # Add all other arguments
  cmd_args+=("$@")
  
  xcodebuild "${cmd_args[@]}"
}

# Detect platform from build settings (use SUPPORTED_PLATFORMS - more reliable than PLATFORM_NAME)
echo "🔍 Detecting target platform from build settings..."
SUPPORTED_PLATFORMS=$(xcodebuild_cmd -showBuildSettings 2>/dev/null | awk -F"= " '/SUPPORTED_PLATFORMS/ {print $2; exit}' | xargs || echo "")

# Detect available destinations
echo "🔍 Detecting available build destinations..."
AVAILABLE_DESTINATIONS=$(xcodebuild_cmd -showdestinations 2>/dev/null || echo "")

# Choose destination based on supported platforms
DESTINATION=""
if echo "$SUPPORTED_PLATFORMS" | grep -qw "macosx"; then
  # macOS project - prefer macOS destination
  if echo "$AVAILABLE_DESTINATIONS" | grep -q "platform:macOS"; then
    DESTINATION="generic/platform=macOS"
    echo "✅ Detected macOS project (SUPPORTED_PLATFORMS: $SUPPORTED_PLATFORMS) - using macOS destination"
  else
    echo "⚠️  macOS project but no macOS destination available"
  fi
elif echo "$SUPPORTED_PLATFORMS" | grep -qwE "iphoneos|iphonesimulator"; then
  # iOS project - prefer iOS Simulator
  if echo "$AVAILABLE_DESTINATIONS" | grep -q "platform:iOS Simulator"; then
    DESTINATION="generic/platform=iOS Simulator"
    echo "✅ Detected iOS project (SUPPORTED_PLATFORMS: $SUPPORTED_PLATFORMS) - using iOS Simulator destination"
  elif echo "$AVAILABLE_DESTINATIONS" | grep -q "platform:iOS"; then
    DESTINATION="generic/platform=iOS"
    echo "✅ Detected iOS project (SUPPORTED_PLATFORMS: $SUPPORTED_PLATFORMS) - using iOS destination"
  fi
fi

# Fallback: if platform detection failed or destination not found, try available destinations
if [ -z "$DESTINATION" ]; then
  echo "⚠️  Platform detection failed or destination not found, trying available destinations..."
  # Prefer macOS first (most common for CI), then iOS Simulator
  if echo "$AVAILABLE_DESTINATIONS" | grep -q "platform:macOS"; then
    DESTINATION="generic/platform=macOS"
    echo "✅ Using macOS destination (fallback)"
  elif echo "$AVAILABLE_DESTINATIONS" | grep -q "platform:iOS Simulator"; then
    DESTINATION="generic/platform=iOS Simulator"
    echo "✅ Using iOS Simulator destination (fallback)"
  else
    # Last resort: try to extract first available platform
    FIRST_PLATFORM=$(echo "$AVAILABLE_DESTINATIONS" | grep -m 1 "platform:" | sed -E 's/.*platform:([^,}]+).*/\1/' | head -1 | xargs || echo "")
    if [ -n "$FIRST_PLATFORM" ]; then
      DESTINATION="generic/platform=$FIRST_PLATFORM"
      echo "✅ Using detected destination: $DESTINATION (fallback)"
    else
      # Final fallback: default to macOS
      DESTINATION="generic/platform=macOS"
      echo "⚠️  Could not detect destination, defaulting to macOS"
    fi
  fi
fi

echo "📍 Build destination: $DESTINATION"
if [ -n "$SUPPORTED_PLATFORMS" ]; then
  echo "   Supported platforms: $SUPPORTED_PLATFORMS"
fi

echo "🏗  Ensuring String Catalog exists..."
# Use XCODEPROJ_PATH for Ruby scripts (must be .xcodeproj, not workspace)
if [ -n "$XCODEPROJ_PATH" ]; then
  ./.quetzal/scripts/ensure_string_catalog.sh "$XCODEPROJ_PATH" "$SCHEME" || {
    echo "⚠️  Warning: Failed to ensure string catalog, continuing anyway..."
  }
else
  echo "⚠️  WARNING: XCODEPROJ_PATH not set - cannot ensure string catalog"
  echo "   Please provide .xcodeproj path as 4th argument when using workspace"
fi

# If file was recreated, ensure it's added to the project
# Use deterministic path - prefer ./Localizable.xcstrings or ./Resources/Localizable.xcstrings
# Exclude export directories to avoid picking wrong file
XCSTRINGS_FILE=""
if [ -f "./Localizable.xcstrings" ]; then
  XCSTRINGS_FILE="./Localizable.xcstrings"
elif [ -f "./Resources/Localizable.xcstrings" ]; then
  XCSTRINGS_FILE="./Resources/Localizable.xcstrings"
else
  # Fallback: search but exclude export directories
  XCSTRINGS_FILE=$(find . -name "Localizable.xcstrings" -type f \
    ! -path "./LocalizationsExport/*" \
    ! -path "./**/*.xcloc/*" \
    ! -path "./DerivedData/*" \
    | head -n 1)
fi
if [ -n "$XCSTRINGS_FILE" ] && [ -f "./.quetzal/scripts/add_xcstrings_to_project.rb" ] && [ -n "$XCODEPROJ_PATH" ]; then
  echo "🔄 Ensuring .xcstrings file is in Xcode project..."
  ruby ./.quetzal/scripts/add_xcstrings_to_project.rb "$XCODEPROJ_PATH" "$XCSTRINGS_FILE" "$SCHEME" 2>/dev/null || echo "⚠️  Note: File may already be in project"
elif [ -z "$XCODEPROJ_PATH" ]; then
  echo "⚠️  WARNING: XCODEPROJ_PATH not set - cannot add catalog to project"
  echo "   Catalog may not be populated by build if not in project"
fi

echo "🏗  Running unsigned build with compiler-based string extraction..."

# CRITICAL: Check initial catalog count BEFORE the build
# This allows us to detect if Xcode auto-merged strings during the build
INITIAL_CATALOG_COUNT=0
if [ -n "$XCSTRINGS_FILE" ] && [ -f "$XCSTRINGS_FILE" ] && command -v jq &> /dev/null; then
  INITIAL_CATALOG_COUNT=$(jq '.strings | length' "$XCSTRINGS_FILE" 2>/dev/null || echo "0")
  echo "📊 Pre-build catalog count: $INITIAL_CATALOG_COUNT strings"
  if [ "$INITIAL_CATALOG_COUNT" -gt 0 ]; then
    echo "💡 Catalog already contains $INITIAL_CATALOG_COUNT strings - will check for new strings after build"
  else
    echo "💡 Catalog is empty - will extract strings from build"
  fi
else
  echo "⚠️  Could not determine pre-build catalog count"
fi
echo ""

# Save build output to file for debugging
BUILD_LOG_RAW="build_output_raw.log"

# Disable SwiftLint and other plugins - we only need string extraction, not linting
export SWIFTLINT_DISABLE=YES
export SWIFTLINT_SKIP_BUILD_PHASE=YES
export DISABLE_SWIFTLINT=YES

# Run xcodebuild and capture raw log
echo "Starting build with string extraction..."
# Use -skipPackagePluginValidation to skip SwiftLint and other plugin validation
# Force a REAL build of the app target (not preview/link noise)
# Note: xcodebuild compiles files in parallel, so many files may compile successfully
# before hitting an error. Strings from successfully compiled files will be extracted.
xcodebuild_cmd \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_EMIT_LOC_STRINGS=YES \
  LOCALIZED_STRING_SWIFTUI_SUPPORT=YES \
  -skipPackagePluginValidation \
  build 2>&1 | tee "$BUILD_LOG_RAW"

BUILD_EXIT_CODE=${PIPESTATUS[0]}


if [ $BUILD_EXIT_CODE -eq 0 ]; then
  echo "Build completed successfully"
else
  echo "Build completed with exit code $BUILD_EXIT_CODE (continuing to merge strings from successfully compiled files)"
fi
BUILD_DIR=$(xcodebuild_cmd -showBuildSettings 2>/dev/null | grep -m 1 "BUILD_DIR" | sed 's/.*= *//' | xargs || echo "")
if [ -n "$BUILD_DIR" ]; then
  DERIVED_DATA_DIR=$(echo "$BUILD_DIR" | sed 's|/Build/Products.*||')
  INTERMEDIATES_DIR=$(echo "$BUILD_DIR" | sed 's|/Build/Products|/Build/Intermediates.noindex|')
  
  # Search for Localizable.strings in the expected location (*.lproj/Localizable.strings)
  BRIDGE_STRINGS=$(find "$DERIVED_DATA_DIR" -path '*/*.lproj/Localizable.strings' -type f 2>/dev/null | grep -v "/SourcePackages/" | grep -v "/Products/" | head -10 || echo "")
  
  if [ -n "$BRIDGE_STRINGS" ]; then
    BRIDGE_COUNT=$(echo "$BRIDGE_STRINGS" | wc -l | xargs)
    echo "Found $BRIDGE_COUNT Localizable.strings bridge artifact(s)"
  fi
else
  echo "⚠️  Could not determine DerivedData path for bridge artifact check"
fi
echo ""

# Check if strings were already merged into the catalog by Xcode
echo "🔍 Checking string catalog for merged strings..."

# Find the xcstrings file (deterministic - prefer Localizable.xcstrings, exclude exports)
# Note: XCSTRINGS_FILE should already be set from before the build, but verify it still exists
if [ -z "$XCSTRINGS_FILE" ] || [ ! -f "$XCSTRINGS_FILE" ]; then
  # Re-find if not set or missing
  if [ -f "./Localizable.xcstrings" ]; then
    XCSTRINGS_FILE="./Localizable.xcstrings"
  elif [ -f "./Resources/Localizable.xcstrings" ]; then
    XCSTRINGS_FILE="./Resources/Localizable.xcstrings"
  else
    # Fallback: search for Localizable.xcstrings specifically, excluding export directories
    # Fix: use * instead of ** for find (find doesn't support ** glob)
    XCSTRINGS_FILE=$(find . -name "Localizable.xcstrings" -type f \
      ! -path "*/LocalizationsExport/*" \
      ! -path "*/*.xcloc/*" \
      ! -path "./DerivedData/*" \
      | head -1)
  fi
fi

if [ -z "$XCSTRINGS_FILE" ] || [ ! -f "$XCSTRINGS_FILE" ]; then
  echo "⚠️  No .xcstrings file found"
  exit 1
fi

echo "📋 Found string catalog: $XCSTRINGS_FILE"

# Check if Xcode automatically merged strings during the build
# (INITIAL_CATALOG_COUNT was already set BEFORE the build)
CATALOG_COUNT=$INITIAL_CATALOG_COUNT
if command -v jq &> /dev/null; then
  CURRENT_COUNT=$(jq '.strings | length' "$XCSTRINGS_FILE" 2>/dev/null || echo "0")
  if [ "$CURRENT_COUNT" -gt "$INITIAL_CATALOG_COUNT" ]; then
    NEW_STRINGS=$((CURRENT_COUNT - INITIAL_CATALOG_COUNT))
    echo "✅ Xcode automatically merged $NEW_STRINGS new strings during build!"
    echo "✅ Catalog now contains $CURRENT_COUNT strings total (was $INITIAL_CATALOG_COUNT)"
    CATALOG_COUNT=$CURRENT_COUNT
  else
    echo "⚠️  No new strings were automatically merged by Xcode"
    echo "💡 Catalog still contains $CURRENT_COUNT strings (same as before build: $INITIAL_CATALOG_COUNT)"
    echo "💡 Will search DerivedData for emitted strings and merge manually..."
  fi
else
  echo "⚠️  jq not available - cannot check if Xcode auto-merged strings"
fi

# Always search for emitted strings and merge them (even if catalog already has some)
# This ensures we capture ALL strings emitted by the build, not just what Xcode auto-merged
echo ""
echo "🔄 Searching for compiler-emitted strings from the build..."

# Get DerivedData path from build settings
BUILD_DIR=$(xcodebuild_cmd -showBuildSettings 2>/dev/null | grep -m 1 "BUILD_DIR" | sed 's/.*= *//' | xargs || echo "")

if [ -n "$BUILD_DIR" ]; then
  # Convert BUILD_DIR to Intermediates path
  INTERMEDIATES_DIR=$(echo "$BUILD_DIR" | sed 's|/Build/Products|/Build/Intermediates.noindex|')
  
  # Search for compiler-emitted strings in specific locations
  # Collect ALL files (no limit) - this is what we'll actually process
  EMITTED_STRINGS_FILES=$(find "$INTERMEDIATES_DIR" \( -path "*/en.lproj/*.strings" -o -path "*/Objects-normal/*/*.strings" \) -type f 2>/dev/null | grep -v "/SourcePackages/" | grep -v "/Products/" | grep -v ".framework/" || echo "")
  
  # Search for .stringsdata files (newer binary format)
  # Search ALL of INTERMEDIATES_DIR, not just Objects-normal (broader search)
  EMITTED_STRINGSDATA_FILES=$(find "$INTERMEDIATES_DIR" -type f -name "*.stringsdata" 2>/dev/null | grep -v "/SourcePackages/" | grep -v "/Products/" | grep -v ".framework/" || echo "")
  
  # Combine .strings and .stringsdata files for merging
  ALL_EMITTED_FILES=""
  FILES_TO_MERGE=0
  
  # Count .strings files
  if [ -n "$EMITTED_STRINGS_FILES" ]; then
    STRING_COUNT=$(echo "$EMITTED_STRINGS_FILES" | wc -l | xargs)
    echo "Found $STRING_COUNT emitted .strings files"
    ALL_EMITTED_FILES="$EMITTED_STRINGS_FILES"
    FILES_TO_MERGE=$((FILES_TO_MERGE + STRING_COUNT))
  fi
  
  # Count .stringsdata files
  if [ -n "$EMITTED_STRINGSDATA_FILES" ]; then
    STRINGSDATA_COUNT=$(echo "$EMITTED_STRINGSDATA_FILES" | wc -l | xargs)
    echo "Found $STRINGSDATA_COUNT emitted .stringsdata files"
    if [ "$STRINGSDATA_COUNT" -eq 50 ]; then
      echo "WARNING: Exactly 50 files found - check for accidental truncation!"
    fi
    if [ -n "$ALL_EMITTED_FILES" ]; then
      ALL_EMITTED_FILES="$ALL_EMITTED_FILES"$'\n'"$EMITTED_STRINGSDATA_FILES"
    else
      ALL_EMITTED_FILES="$EMITTED_STRINGSDATA_FILES"
    fi
    FILES_TO_MERGE=$((FILES_TO_MERGE + STRINGSDATA_COUNT))
  fi
  
  if [ "$FILES_TO_MERGE" -gt 0 ]; then
    echo "Merging $FILES_TO_MERGE emitted file(s) into catalog..."
    
    # Process .stringsdata files using xcstringstool (Apple's official tool)
    if [ -n "$EMITTED_STRINGSDATA_FILES" ]; then
      # Validate XCSTRINGS_FILE exists before attempting sync
      if [ -z "$XCSTRINGS_FILE" ] || [ ! -f "$XCSTRINGS_FILE" ]; then
        echo "ERROR: XCSTRINGS_FILE missing or not found: '$XCSTRINGS_FILE'"
        echo "Falling back to exportLocalizations..."
      elif ! command -v xcrun >/dev/null 2>&1 || ! xcrun --find xcstringstool >/dev/null 2>&1; then
        echo "WARNING: xcstringstool not available, falling back to exportLocalizations..."
      else
        # Get initial string count from catalog
        INITIAL_STRING_COUNT=0
        if command -v jq >/dev/null 2>&1; then
          INITIAL_STRING_COUNT=$(jq '.strings | length' "$XCSTRINGS_FILE" 2>/dev/null || echo "0")
        fi
        
        # Collect all .stringsdata files and write to temp file (handles large lists safely)
        # Write full list to temp file to avoid command-line length limits
        STRINGSDATA_LIST=$(mktemp)
        STRINGSDATA_COUNT=0
        SAMPLE_FILES=()
        while IFS= read -r f; do
          [ -z "$f" ] && continue
          if [ -f "$f" ]; then
            echo "$f" >> "$STRINGSDATA_LIST"
            STRINGSDATA_COUNT=$((STRINGSDATA_COUNT + 1))
            # Collect first 3 files for upload to GCS
            if [ "${#SAMPLE_FILES[@]}" -lt 3 ]; then
              SAMPLE_FILES+=("$f")
            fi
          fi
        done <<< "$EMITTED_STRINGSDATA_FILES"
        
        if [ "$STRINGSDATA_COUNT" -eq 0 ]; then
          echo "No valid .stringsdata files found to sync"
          rm -f "$STRINGSDATA_LIST"
        else
          # Sync in chunks to avoid command-line length limits
          CHUNK_SIZE=100
          SYNCED_COUNT=0
          FAILED_COUNT=0
          
          echo "Syncing $STRINGSDATA_COUNT .stringsdata files (in chunks of $CHUNK_SIZE)..."
          
          # Read file list and process in chunks
          CHUNK_ARRAY=()
          CHUNK_NUM=0
          
          while IFS= read -r f; do
            [ -z "$f" ] && continue
            CHUNK_ARRAY+=("$f")
            
            # When chunk is full, sync it
            if [ "${#CHUNK_ARRAY[@]}" -ge "$CHUNK_SIZE" ]; then
              CHUNK_NUM=$((CHUNK_NUM + 1))
              
              if xcrun xcstringstool sync "$XCSTRINGS_FILE" \
                --skip-marking-strings-stale \
                --stringsdata "${CHUNK_ARRAY[@]}" 2>&1; then
                SYNCED_COUNT=$((SYNCED_COUNT + ${#CHUNK_ARRAY[@]}))
              else
                FAILED_COUNT=$((FAILED_COUNT + ${#CHUNK_ARRAY[@]}))
              fi
              
              # Clear chunk array for next batch
              CHUNK_ARRAY=()
            fi
          done < "$STRINGSDATA_LIST"
          
          # Sync remaining files in final chunk
          if [ "${#CHUNK_ARRAY[@]}" -gt 0 ]; then
            CHUNK_NUM=$((CHUNK_NUM + 1))
            
            if xcrun xcstringstool sync "$XCSTRINGS_FILE" \
              --skip-marking-strings-stale \
              --stringsdata "${CHUNK_ARRAY[@]}" 2>&1; then
              SYNCED_COUNT=$((SYNCED_COUNT + ${#CHUNK_ARRAY[@]}))
            else
              FAILED_COUNT=$((FAILED_COUNT + ${#CHUNK_ARRAY[@]}))
            fi
          fi
          
          rm -f "$STRINGSDATA_LIST"
          
          if [ "$SYNCED_COUNT" -gt 0 ]; then
            echo "Successfully synced $SYNCED_COUNT file(s)"
          fi
          if [ "$FAILED_COUNT" -gt 0 ]; then
            echo "WARNING: $FAILED_COUNT file(s) failed to sync"
          fi
          
          # Only proceed with format check if we synced at least some files
          if [ "$SYNCED_COUNT" -gt 0 ]; then
            # Format sanity check: verify catalog is valid JSON and countable
            if command -v python3 >/dev/null 2>&1; then
              python3 - "$XCSTRINGS_FILE" <<'PY'
import json
import sys
try:
    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        j = json.load(f)
    print("✅ xcstrings JSON is valid")
    print(f"✅ Catalog keys: {list(j.keys())}")
    string_count = len(j.get("strings", {}))
    print(f"✅ String count: {string_count}")
    sys.exit(0)
except json.JSONDecodeError as e:
    print(f"❌ Invalid JSON in catalog: {e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Error reading catalog: {e}")
    sys.exit(1)
PY
              FORMAT_CHECK_EXIT=$?
            else
              # Fallback to jq if Python not available
              if command -v jq >/dev/null 2>&1; then
                if jq empty "$XCSTRINGS_FILE" 2>/dev/null; then
                  echo "✅ xcstrings JSON is valid (jq check)"
                  FORMAT_CHECK_EXIT=0
                else
                  echo "❌ Invalid JSON in catalog (jq check failed)"
                  FORMAT_CHECK_EXIT=1
                fi
              else
                echo "⚠️  Cannot verify JSON format (neither python3 nor jq available)"
                FORMAT_CHECK_EXIT=0
              fi
            fi
            
            if [ "$FORMAT_CHECK_EXIT" -eq 0 ]; then
              # Get final string count
              FINAL_STRING_COUNT=0
              if command -v jq >/dev/null 2>&1; then
                FINAL_STRING_COUNT=$(jq '.strings | length' "$XCSTRINGS_FILE" 2>/dev/null || echo "0")
              elif command -v python3 >/dev/null 2>&1; then
                FINAL_STRING_COUNT=$(python3 -c "import json; print(len(json.load(open('$XCSTRINGS_FILE', 'r', encoding='utf-8')).get('strings', {})))" 2>/dev/null || echo "0")
              fi
              
              echo ""
              echo "📊 Sync results:"
              echo "   Started with: $INITIAL_STRING_COUNT strings"
              echo "   Now has: $FINAL_STRING_COUNT strings"
              
              if [ "$FINAL_STRING_COUNT" -gt "$INITIAL_STRING_COUNT" ]; then
                NEW_STRINGS=$((FINAL_STRING_COUNT - INITIAL_STRING_COUNT))
                echo "✅ Successfully added $NEW_STRINGS new strings from $STRINGSDATA_COUNT .stringsdata file(s)"
              elif [ "$FINAL_STRING_COUNT" -eq "$INITIAL_STRING_COUNT" ] && [ "$FINAL_STRING_COUNT" -gt 0 ]; then
                echo "ℹ️  Catalog has $FINAL_STRING_COUNT strings (no new strings added)"
                echo "   This is normal if strings were already in catalog or .stringsdata files contained duplicates"
              elif [ "$FINAL_STRING_COUNT" -lt "$INITIAL_STRING_COUNT" ]; then
                echo "⚠️  WARNING: Catalog lost strings (had $INITIAL_STRING_COUNT, now has $FINAL_STRING_COUNT)"
              else
                echo "ℹ️  Catalog is empty - this may be normal if .stringsdata files contained no localizable strings"
              fi
              
              # Show file info for debugging
              echo ""
              echo "📄 Catalog file info:"
              ls -lh "$XCSTRINGS_FILE" 2>/dev/null || echo "   (cannot stat file)"
              echo ""
              echo "📋 First 50 lines of catalog (for debugging):"
              head -50 "$XCSTRINGS_FILE" 2>/dev/null | sed 's/^/   /' || echo "   (cannot read file)"
            else
              echo "❌ Catalog format check failed - sync may have corrupted the file"
            fi
          else
            echo "❌ Sync failed"
            echo "⚠️  Falling back to exportLocalizations or Python script..."
          fi
        fi
      fi
    fi
    
    # Process .strings files using Python script (if available)
    # Note: This merges into the catalog, so it should not overwrite existing strings
    if [ -n "$EMITTED_STRINGS_FILES" ] && [ -f "./Scripts/merge_emitted_strings.py" ]; then
      echo ""
      echo "📦 Processing .strings files using Python script..."
      
      # Check catalog state before Python merge
      PRE_PYTHON_COUNT=0
      if command -v jq >/dev/null 2>&1 && [ -f "$XCSTRINGS_FILE" ]; then
        PRE_PYTHON_COUNT=$(jq '.strings | length' "$XCSTRINGS_FILE" 2>/dev/null || echo "0")
        echo "📊 Catalog has $PRE_PYTHON_COUNT strings before Python merge"
      fi
      
      python3 ./Scripts/merge_emitted_strings.py "$XCSTRINGS_FILE" "$INTERMEDIATES_DIR" 2>/dev/null || {
        echo "⚠️  Failed to merge .strings files via Python script (non-fatal)"
      }
      
      # Verify Python script didn't corrupt the catalog
      if command -v jq >/dev/null 2>&1 && [ -f "$XCSTRINGS_FILE" ]; then
        POST_PYTHON_COUNT=$(jq '.strings | length' "$XCSTRINGS_FILE" 2>/dev/null || echo "0")
        if [ "$POST_PYTHON_COUNT" -lt "$PRE_PYTHON_COUNT" ]; then
          echo "⚠️  WARNING: Python script reduced catalog from $PRE_PYTHON_COUNT to $POST_PYTHON_COUNT strings"
        fi
      fi
    fi
    
    # Final verification after all merge operations
    if [ -f "$XCSTRINGS_FILE" ] && command -v jq >/dev/null 2>&1; then
      FINAL_COUNT=$(jq '.strings | length' "$XCSTRINGS_FILE" 2>/dev/null || echo "0")
      if [ "$FINAL_COUNT" -gt "$INITIAL_CATALOG_COUNT" ]; then
        NEW_STRINGS=$((FINAL_COUNT - INITIAL_CATALOG_COUNT))
        echo "Successfully merged $NEW_STRINGS new strings (total: $FINAL_COUNT)"
      elif [ "$FINAL_COUNT" -gt 0 ]; then
        echo "Catalog contains $FINAL_COUNT strings"
      else
        echo "WARNING: Catalog is empty after merge operations"
      fi
    fi
  else
    # Try using xcodebuild -exportLocalizations as a fallback
    # Only if catalog is empty - don't overwrite existing strings
    CATALOG_HAS_STRINGS=0
    if [ -f "$XCSTRINGS_FILE" ] && command -v jq >/dev/null 2>&1; then
      CATALOG_STRING_COUNT=$(jq '.strings | length' "$XCSTRINGS_FILE" 2>/dev/null || echo "0")
      if [ "$CATALOG_STRING_COUNT" -gt 0 ]; then
        CATALOG_HAS_STRINGS=1
      fi
    fi
    
    if [ "$CATALOG_HAS_STRINGS" -eq 0 ]; then
      echo "Trying xcodebuild -exportLocalizations as fallback..."
      EXPORT_DIR="./LocalizationsExport"
      mkdir -p "$EXPORT_DIR"
    
    # Get DerivedData path from build settings to reuse existing build
    # BUILD_DIR is typically: /path/to/DerivedData/ProjectName-hash/Build/Products/Configuration
    # We want: /path/to/DerivedData/ProjectName-hash
    BUILD_DIR_SETTING=$(xcodebuild_cmd -showBuildSettings 2>/dev/null | grep -m 1 "^ *BUILD_DIR" | sed 's/.*= *//' | xargs || echo "")
    if [ -n "$BUILD_DIR_SETTING" ]; then
      # Strip /Build and everything after it to get DerivedData root
      DERIVED_DATA_PATH=$(echo "$BUILD_DIR_SETTING" | sed 's|/Build.*||' | xargs)
    else
      DERIVED_DATA_PATH=""
    fi
    
    # Build exportLocalizations command using array (safer than string eval)
    # CRITICAL: Use -workspace when BUILD_TYPE=workspace, -project when BUILD_TYPE=project
    # Never pass a .xcworkspace path to -project
    EXPORT_CMD=()
    if [ "$BUILD_TYPE" = "workspace" ]; then
      EXPORT_CMD=(xcodebuild -exportLocalizations -workspace "$BUILD_PATH")
    else
      EXPORT_CMD=(xcodebuild -exportLocalizations -project "$BUILD_PATH")
    fi
    EXPORT_CMD+=(-scheme "$SCHEME")
    EXPORT_CMD+=(-localizationPath "$EXPORT_DIR")
    EXPORT_CMD+=(-exportLanguage en)
    EXPORT_CMD+=(-skipPackagePluginValidation)
    
    # Use DERIVED_DATA_PATH from environment if set (from workflow)
    if [ -z "$DERIVED_DATA_PATH" ]; then
      # Fallback: try to get from build settings
      BUILD_DIR_SETTING=$(xcodebuild_cmd -showBuildSettings 2>/dev/null | grep -m 1 "^ *BUILD_DIR" | sed 's/.*= *//' | xargs || echo "")
      if [ -n "$BUILD_DIR_SETTING" ]; then
        DERIVED_DATA_PATH=$(echo "$BUILD_DIR_SETTING" | sed 's|/Build.*||' | xargs)
      fi
    fi
    
    if [ -n "$DERIVED_DATA_PATH" ]; then
      EXPORT_CMD+=(-derivedDataPath "$DERIVED_DATA_PATH")
      echo "📂 Using DerivedData: $DERIVED_DATA_PATH"
    fi
    
    echo "🔍 Running exportLocalizations command..."
    echo "   Full command: ${EXPORT_CMD[*]}"
    if "${EXPORT_CMD[@]}" 2>&1 | tee -a "$BUILD_LOG_RAW"; then
      echo "✅ exportLocalizations completed successfully"
      
      # Find the exported .xcloc file
      XCLOC_FILE=$(find "$EXPORT_DIR" -name "*.xcloc" -type d | head -1)
      if [ -n "$XCLOC_FILE" ] && [ -d "$XCLOC_FILE" ]; then
        echo "📦 Found exported localization catalog: $XCLOC_FILE"
        
        # The .xcloc contains .xliff files and potentially .xcstrings files
        # Check if there's an .xcstrings file inside (Xcode 15+ with string catalogs)
        XCSTRINGS_IN_XCLOC=$(find "$XCLOC_FILE" -name "*.xcstrings" -type f | head -1)
        
        if [ -n "$XCSTRINGS_IN_XCLOC" ] && [ -f "$XCSTRINGS_IN_XCLOC" ]; then
          echo "📋 Found .xcstrings file in export: $XCSTRINGS_IN_XCLOC"
          
          # Check if target catalog already has strings (shouldn't happen if we got here, but be safe)
          EXISTING_COUNT=0
          if [ -f "$XCSTRINGS_FILE" ] && command -v jq >/dev/null 2>&1; then
            EXISTING_COUNT=$(jq '.strings | length' "$XCSTRINGS_FILE" 2>/dev/null || echo "0")
          fi
          
          if [ "$EXISTING_COUNT" -gt 0 ]; then
            echo "⚠️  WARNING: Catalog already has $EXISTING_COUNT strings - not overwriting with export"
            echo "   Export file would have been: $XCSTRINGS_IN_XCLOC"
          else
            # Copy the exported .xcstrings (it should contain all strings from exportLocalizations)
            cp "$XCSTRINGS_IN_XCLOC" "$XCSTRINGS_FILE" && echo "✅ Copied exported .xcstrings file"
            
            # Verify copy succeeded
            if command -v jq &> /dev/null; then
              FINAL_COUNT=$(jq '.strings | length' "$XCSTRINGS_FILE" 2>/dev/null || echo "0")
              if [ "$FINAL_COUNT" -gt 0 ]; then
                echo "✅ Exported catalog contains $FINAL_COUNT strings"
                CATALOG_COUNT=$FINAL_COUNT
              fi
            fi
          fi
        else
          # Check for .xliff files (older format)
          XLIFF_FILE=$(find "$XCLOC_FILE" -name "*.xliff" -type f | head -1)
          if [ -n "$XLIFF_FILE" ] && [ -f "$XLIFF_FILE" ]; then
            echo "📋 Found .xliff file in export: $XLIFF_FILE"
            echo "✅ XLIFF file found - strings will be extracted directly from XLIFF for skip list"
            
            # Count strings in XLIFF file (for skip list generation, we'll parse it directly)
            if command -v python3 &> /dev/null; then
              XLIFF_COUNT=$(python3 -c "
import xml.etree.ElementTree as ET
import sys
try:
    tree = ET.parse('$XLIFF_FILE')
    root = tree.getroot()
    ns = ''
    if root.tag.startswith('{'):
        ns = root.tag.split('}')[0] + '}'
    trans_units = root.findall(f'.//{ns}trans-unit') if ns else root.findall('.//trans-unit')
    count = 0
    for trans_unit in trans_units:
        source_elem = trans_unit.find(f'{ns}source') if ns else trans_unit.find('source')
        if source_elem is not None:
            source_text = ''
            if source_elem.text:
                source_text = source_elem.text.strip()
            elif len(source_elem) > 0:
                source_text = ''.join(source_elem.itertext()).strip()
            if source_text:
                count += 1
    print(count)
except:
    print(0)
" 2>/dev/null || echo "0")
              
              if [ "$XLIFF_COUNT" -gt 0 ]; then
                echo "Found $XLIFF_COUNT strings in XLIFF file"
              fi
            fi
          fi
        fi
      fi
    fi
    else
      echo "   (Skipped - catalog already populated)"
    fi  # Close the "if [ "$CATALOG_HAS_STRINGS" -eq 0 ]" block
  fi  # Close the "if [ "$FILES_TO_MERGE" -gt 0 ]" else block
else
  echo "⚠️  Could not determine DerivedData path"
fi  # Close the "if [ -n "$BUILD_DIR" ]" block

# Final summary
if command -v jq &> /dev/null; then
  FINAL_COUNT=$(jq '.strings | length' "$XCSTRINGS_FILE" 2>/dev/null || echo "0")
  if [ "$FINAL_COUNT" -gt "$INITIAL_CATALOG_COUNT" ]; then
    NEW_STRINGS=$((FINAL_COUNT - INITIAL_CATALOG_COUNT))
    echo "Successfully extracted $NEW_STRINGS new strings (total: $FINAL_COUNT)"
  elif [ "$FINAL_COUNT" -gt 0 ]; then
    echo "Catalog contains $FINAL_COUNT strings"
  fi
fi

