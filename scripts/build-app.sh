#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD_ARGS=(-c release --disable-sandbox --scratch-path .build)
if [[ "${1:-}" == "--universal" && $# -eq 1 ]]; then
  BUILD_ARGS=(-c release --disable-sandbox --scratch-path .build-universal --arch arm64 --arch x86_64)
elif [[ $# -ne 0 ]]; then
  print -u2 "Usage: $0 [--universal]"
  exit 2
fi
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build "${BUILD_ARGS[@]}"
BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
BUILD_ID="$(uuidgen)"
TARGET_APP="$PWD/dist/LyricFloat.app"
APP="$PWD/dist/.LyricFloat-build-$BUILD_ID.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/LyricFloat" "$APP/Contents/MacOS/LyricFloat"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R BrowserExtension "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LyricFloat</string>
<key>CFBundleIdentifier</key><string>com.ecbn.lyricfloat</string>
<key>CFBundleName</key><string>LyricFloat</string>
<key>CFBundleDisplayName</key><string>LyricFloat</string>
<key>CFBundleVersion</key><string>6</string>
<key>CFBundleShortVersionString</key><string>1.0.5</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppleEventsUsageDescription</key><string>LyricFloat reads song information and playback timing from Music or Spotify to keep your lyrics in sync, and lets you pause or seek.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
# Never overwrite or re-sign a running executable in place.
if [[ -d "$TARGET_APP" ]]; then
  mv "$TARGET_APP" "$PWD/dist/.LyricFloat-previous-$BUILD_ID.app"
fi
mv "$APP" "$TARGET_APP"
print "Built $TARGET_APP"
