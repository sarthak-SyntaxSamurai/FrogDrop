#!/usr/bin/env bash

set -euo pipefail

# Usage:
#   build_post_localization_verify.sh xcode <build_path> <scheme> [configuration]
#   build_post_localization_verify.sh spm <package_path> [configuration]
#   build_post_localization_verify.sh <build_path> <scheme> [configuration]
#     (legacy Xcode-only form; build_path is .xcworkspace or .xcodeproj)

MODE="${1:-}"
CONFIGURATION="Debug"

run_spm_build() {
    local package_path="${1:-.}"
    local configuration="${2:-Debug}"

    if [ ! -f "$package_path/Package.swift" ]; then
        echo "::error::No Package.swift found at package_path='$package_path'"
        exit 1
    fi

    echo "Using build system: spm"
    echo "Using package path: $package_path"
    echo "Using configuration: $configuration"

    # Compile/type-safety gate only — skip style plugins that can mask regressions.
    export SWIFTLINT_DISABLE=YES
    export SWIFTLINT_SKIP_BUILD_PHASE=YES
    export DISABLE_SWIFTLINT=YES
    export SWIFTLINT_DISABLE=1

    local config_flag="debug"
    case "$(echo "$configuration" | tr '[:upper:]' '[:lower:]')" in
        release) config_flag="release" ;;
        *) config_flag="debug" ;;
    esac

    # Run from repo root so build_output_post_localization.log lands where the
    # workflow artifact upload expects it.
    swift build --package-path "$package_path" -c "$config_flag" 2>&1 \
        | tee build_output_post_localization.log
    local build_exit=${PIPESTATUS[0]}

    if [ "$build_exit" -eq 0 ]; then
        exit 0
    fi
    echo "swift build exited with code $build_exit; verification failed."
    exit "$build_exit"
}

run_xcode_build() {
    local build_path="${1:-}"
    local scheme="${2:-}"
    local configuration="${3:-Debug}"

    if [ -z "$build_path" ] || [ -z "$scheme" ]; then
        echo "Usage: build_post_localization_verify.sh xcode <build_path> <scheme> [configuration]"
        exit 1
    fi

    local build_type="project"
    if [[ "$build_path" == *.xcworkspace ]]; then
        build_type="workspace"
    fi

    xcodebuild_cmd() {
        local cmd_args=()
        if [ "$build_type" = "workspace" ]; then
            cmd_args+=(-workspace "$build_path")
        else
            cmd_args+=(-project "$build_path")
        fi
        cmd_args+=(-scheme "$scheme")
        cmd_args+=("$@")
        xcodebuild "${cmd_args[@]}"
    }

    local available_destinations
    available_destinations=$(xcodebuild_cmd -showdestinations 2>/dev/null || true)
    local destination=""
    if echo "$available_destinations" | grep -q "platform:macOS"; then
        destination="generic/platform=macOS"
    elif echo "$available_destinations" | grep -q "platform:iOS Simulator"; then
        destination="generic/platform=iOS Simulator"
    elif echo "$available_destinations" | grep -q "platform:iOS"; then
        destination="generic/platform=iOS"
    else
        destination="generic/platform=macOS"
    fi

    echo "Using build system: xcode"
    echo "Using build path: $build_path"
    echo "Using scheme: $scheme"
    echo "Using destination: $destination"

    export SWIFTLINT_DISABLE=YES
    export SWIFTLINT_SKIP_BUILD_PHASE=YES
    export DISABLE_SWIFTLINT=YES
    export SWIFTLINT_DISABLE=1

    if [ "$build_type" = "workspace" ]; then
        xcodebuild -workspace "$build_path" -scheme "$scheme" -resolvePackageDependencies || true
    else
        xcodebuild -project "$build_path" -scheme "$scheme" -resolvePackageDependencies || true
    fi

    xcodebuild_cmd \
        -configuration "$configuration" \
        -destination "$destination" \
        CODE_SIGNING_ALLOWED=NO \
        -skipPackagePluginValidation \
        build 2>&1 | tee build_output_post_localization.log

    local build_exit_code=${PIPESTATUS[0]}
    if [ "$build_exit_code" -eq 0 ]; then
        exit 0
    fi

    echo "xcodebuild exited with code $build_exit_code; checking whether failures are SwiftLint-plugin-only..."

    local failed_cmds
    failed_cmds=$(awk '
        /The following build commands failed:/ { in_block=1; next }
        in_block && /^\(/ { in_block=0; next }
        in_block && $0 ~ /^[[:space:]]+\S/ { gsub(/^[[:space:]]+/, "", $0); print }
    ' build_output_post_localization.log || true)

    if [ -n "$failed_cmds" ]; then
        local non_swiftlint_failed
        non_swiftlint_failed=$(printf "%s\n" "$failed_cmds" | grep -Ev "SwiftLint|Running SwiftLint" || true)
        if [ -z "$non_swiftlint_failed" ]; then
            echo "Only SwiftLint build-tool plugin failures detected; treating verification as pass."
            exit 0
        fi
    fi

    echo "Non-SwiftLint build failures detected; verification failed."
    exit "$build_exit_code"
}

case "$MODE" in
    spm)
        run_spm_build "${2:-.}" "${3:-Debug}"
        ;;
    xcode)
        run_xcode_build "${2:-}" "${3:-}" "${4:-Debug}"
        ;;
    *.xcworkspace|*.xcodeproj)
        # Legacy positional form: <build_path> <scheme> [configuration]
        run_xcode_build "$MODE" "${2:-}" "${3:-Debug}"
        ;;
    *)
        echo "Usage:"
        echo "  build_post_localization_verify.sh xcode <build_path> <scheme> [configuration]"
        echo "  build_post_localization_verify.sh spm <package_path> [configuration]"
        echo "  build_post_localization_verify.sh <build_path> <scheme> [configuration]"
        exit 1
        ;;
esac
