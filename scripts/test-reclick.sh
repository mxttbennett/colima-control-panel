#!/usr/bin/env bash
# Checks the re-click-to-deselect behavior against a real NSTableView. It needs a desktop session and moves the pointer briefly.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT

swiftc -o "$build/harness" "$root/scripts/reclick-harness/main.swift" "$root/Sources/ColimaCtrl/Views/ReclickDeselect.swift"
"$build/harness"
