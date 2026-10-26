#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/Colima Ctrl.app"
version="$(git -C "$root" describe --tags --always 2>/dev/null || echo 0.1.0)"

cd "$root"
swift build -c release
bin="$(swift build -c release --show-bin-path)/ColimaCtrl"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/ColimaCtrl"

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
  <key>CFBundleName</key><string>Colima Ctrl</string>
  <key>CFBundleDisplayName</key><string>Colima Ctrl</string>
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

codesign --force --sign - "$app" >/dev/null
echo "built $app"
