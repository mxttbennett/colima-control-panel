#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/Colima Control Panel.app"
version="$(git -C "$root" describe --tags --always 2>/dev/null || echo 0.1.0)"
version="${version#v}"

cd "$root"
swift build -c release
bin="$(swift build -c release --show-bin-path)/ColimaCtrl"
watcher="$(swift build -c release --show-bin-path)/ColimaCtrlWatcher"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/ColimaCtrl"
cp "$watcher" "$app/Contents/MacOS/ColimaCtrlWatcher"
mkdir -p "$app/Contents/Library/LaunchAgents"
cp "$root/Resources/dev.mxttbennett.colima-ctrl.watcher.plist" "$app/Contents/Library/LaunchAgents/"

icons="$(mktemp -d)"
xcrun actool "$root/Resources/AppIcon.icon" --compile "$icons" --platform macosx --target-device mac \
  --minimum-deployment-target 26.0 --app-icon AppIcon --output-partial-info-plist "$icons/partial.plist" >/dev/null
cp "$icons/Assets.car" "$icons/AppIcon.icns" "$app/Contents/Resources/"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.mxttbennett.colima-ctrl</string>
  <key>CFBundleName</key><string>Colima Control Panel</string>
  <key>CFBundleDisplayName</key><string>Colima Control Panel</string>
  <key>CFBundleExecutable</key><string>ColimaCtrl</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><false/>
</dict>
</plist>
PLIST

# CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" signs for distribution; without it the app is ad-hoc signed.
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$app/Contents/MacOS/ColimaCtrlWatcher" >/dev/null
  codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$app" >/dev/null
else
  codesign --force --sign - "$app/Contents/MacOS/ColimaCtrlWatcher" >/dev/null
  codesign --force --sign - "$app" >/dev/null
fi
echo "built $app"
