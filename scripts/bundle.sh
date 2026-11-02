#!/usr/bin/env bash
# Builds Looper with SwiftPM and assembles a signed Looper.app bundle (no Xcode project involved).
#
# Usage: scripts/bundle.sh [--release] [--version <version>] [--identity <codesign identity>] [--output <dir>]
#
# Debug bundles are named Looper-Debug.app and use the `.debug` bundle id, matching the values compiled into
# debug builds (see Sources/Common/appMetadata.swift). Signing with a stable identity keeps the Accessibility
# permission across rebuilds; `-` signs ad hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

configuration=debug
version="0.0.0-SNAPSHOT"
identity="${LOOPER_CODESIGN_IDENTITY:-Looper Development}"
output=.build/bundle
while test $# -gt 0; do
    case $1 in
        --release) configuration=release; shift ;;
        --version) version="$2"; shift 2 ;;
        --identity) identity="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        *) echo "Unknown option $1" > /dev/stderr; exit 1 ;;
    esac
done

min_macos=$(sed -nE 's/.*platforms: \[\.macOS\("([0-9.]+)"\)\].*/\1/p' Package.swift)
if test -z "$min_macos"; then
    echo "Can't read the minimum macOS version from Package.swift" > /dev/stderr
    exit 1
fi

if test $configuration = release; then
    name=Looper
    bundle_id=com.mariovagomarzal.looper
    swift_flags=(-c release -Xswiftc -warnings-as-errors)
else
    name=Looper-Debug
    bundle_id=com.mariovagomarzal.looper.debug
    swift_flags=(-c debug)
fi

swift build "${swift_flags[@]}" --product LooperApp
swift build "${swift_flags[@]}" --product looper
bin_path=$(swift build "${swift_flags[@]}" --show-bin-path)

app="$output/$name.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

cp "$bin_path/LooperApp" "$app/Contents/MacOS/$name"
cp resources/default-config.toml "$app/Contents/Resources/"

# Compiles the asset catalog into Assets.car and AppIcon.icns.
partial_plist=$(mktemp)
xcrun actool resources/Assets.xcassets \
    --compile "$app/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target "$min_macos" \
    --app-icon AppIcon \
    --output-partial-info-plist "$partial_plist" \
    --output-format human-readable-text \
    --notices --warnings --errors > /dev/null
rm -f "$partial_plist"

cat > "$app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$name</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$bundle_id</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$name</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$version</string>
    <key>CFBundleVersion</key>
    <string>$version</string>
    <key>LSMinimumSystemVersion</key>
    <string>$min_macos</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
plutil -lint -s "$app/Contents/Info.plist"

codesign --force --sign "$identity" "$app"
codesign --verify --strict "$app"

cp "$bin_path/looper" "$output/looper"
codesign --force --sign "$identity" "$output/looper"

echo "$app"
