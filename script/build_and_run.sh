#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
root="$PWD"
app_name="Jot"
product="MarginJot"
bundle_id="com.scratchpadexperiment.marginjot"
bundle="$root/$app_name.app"
install_dir="${MARGIN_JOT_INSTALL_DIR:-/Applications}"
installed="$install_dir/$app_name.app"
mode="${1:-run}"

case "$mode" in
    run|--build|--build-only|--verify|--debug|--logs|--telemetry) ;;
    *) echo "Usage: $0 [--build|--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac

swift_flags=()
if [[ -n "${CODEX_SESSION_ID:-}" ]]; then
    # The workspace already runs in a sandbox. SwiftPM cannot start a nested one.
    swift_flags+=(--disable-sandbox --manifest-cache local)
    swift_flags+=(--cache-path .build/cache --config-path .build/config --security-path .build/security)
fi

swift build "${swift_flags[@]}"
resources="$bundle/Contents/Resources"
mkdir -p "$bundle/Contents/MacOS" "$resources"
if ! xcrun actool "$root/Assets/MarginJot.icon" \
    --compile "$resources" --platform macosx \
    --minimum-deployment-target 14.0 --app-icon MarginJot \
    --output-partial-info-plist "$root/.build/icon-info.plist" >"$root/.build/icon-build.log" 2>&1; then
    echo "Native icon compiler unavailable. Packaging the classic icon instead." >&2
    rm -f "$resources/Assets.car"
    swift "$root/script/render_classic_icon.swift" \
        "$root/Assets/PorcelainGlassIcon.png" "$resources/MarginJot.icns"
fi
cp "$(swift build "${swift_flags[@]}" --show-bin-path)/$product" "$bundle/Contents/MacOS/$product"
cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$app_name</string>
    <key>CFBundleDisplayName</key><string>$app_name</string>
    <key>CFBundleIdentifier</key><string>$bundle_id</string>
    <key>CFBundleExecutable</key><string>$product</string>
    <key>CFBundleIconFile</key><string>MarginJot</string>
    <key>CFBundleIconName</key><string>MarginJot</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST
/usr/bin/codesign --force --sign - "$bundle"
/usr/bin/codesign --verify --strict "$bundle"
echo "Bundle ready at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

if [[ "$mode" == "--build-only" ]]; then
    exit 0
fi

if [[ ! -w "$install_dir" ]]; then
    echo "Built $bundle, but this session cannot update $install_dir." >&2
    exit 1
fi

replaced="$installed"
legacy="$install_dir/Margin Jot.app"
if [[ ! -e "$installed" && ! -L "$installed" && ( -e "$legacy" || -L "$legacy" ) ]]; then
    replaced="$legacy"
fi

if [[ -e "$replaced" || -L "$replaced" ]]; then
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$replaced/Contents/Info.plist" 2>/dev/null || true)"
    if [[ -L "$replaced" || "$existing_id" != "$bundle_id" ]]; then
        echo "The app at $replaced has an unexpected bundle identifier or is a symbolic link." >&2
        exit 1
    fi
fi

staging="$(mktemp -d "$install_dir/.margin-jot.XXXXXX")"
staged="$staging/$app_name.app"
previous="$staging/Previous.app"
trap 'if [[ ! -e "$previous" ]]; then /bin/rm -rf "$staging"; fi' EXIT
/usr/bin/ditto "$bundle" "$staged"
/usr/bin/codesign --verify --strict "$staged"
if [[ -e "$replaced" ]]; then
    /bin/mv "$replaced" "$previous"
fi
if ! /bin/mv "$staged" "$installed"; then
    if [[ -e "$previous" ]]; then
        /bin/mv "$previous" "$replaced" || echo "Previous build is at $previous." >&2
    fi
    exit 1
fi
if [[ -e "$previous" ]]; then
    /bin/rm -rf "$previous"
fi
echo "Installed $installed"

if [[ "$mode" != "--build" && "$mode" != "--debug" ]]; then
    /usr/bin/pkill -x "$product" >/dev/null 2>&1 || true
fi

case "$mode" in
    --build) ;;
    run) /usr/bin/open "$installed" ;;
    --verify)
        /usr/bin/open "$installed"
        sleep 1
        /usr/bin/pgrep -x "$product"
        ;;
    --debug)
        /usr/bin/lldb -- "$installed/Contents/MacOS/$product"
        ;;
    --logs)
        /usr/bin/open "$installed"
        /usr/bin/log stream --info --style compact --predicate "process == \"$product\""
        ;;
    --telemetry)
        /usr/bin/open "$installed"
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$bundle_id\""
        ;;
esac
