#!/usr/bin/env bash
# Builds the app, zips it for a GitHub release, and prints the checksum a Homebrew cask needs.
# Set CODESIGN_IDENTITY to sign with a Developer ID, and NOTARY_PROFILE (a notarytool keychain profile) to notarize.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/scripts/build-app.sh"

app="$root/build/Colima Control Panel.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
zip="$root/build/ColimaControlPanel-$version.zip"

if [ -n "${NOTARY_PROFILE:-}" ]; then
  [ -n "${CODESIGN_IDENTITY:-}" ] || { echo "NOTARY_PROFILE needs CODESIGN_IDENTITY" >&2; exit 1; }
  ditto -c -k --keepParent "$app" "$zip"
  xcrun notarytool submit "$zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$app"
fi

rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
echo "zip:    $zip"
echo "sha256: $(shasum -a 256 "$zip" | cut -d' ' -f1)"
