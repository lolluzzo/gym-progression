#!/usr/bin/env bash
# Builds a release IPA on Linux with xlinux (https://github.com/cesardev31/xlinux), which
# compiles the app against the iOS SDK installed by xtool and runs Dart's macOS-only AOT
# compiler under Darling. The IPA is unsigned: xtool, Sideloadly or AltStore sign it.
# Usage: ./build-ios-linux.sh [--install]
#   --install  sign with your Apple ID and install on the connected iPhone (xtool install)
# Output: dist/gym-progression-v<version>-unsigned.ipa
set -euo pipefail
cd "$(dirname "$0")"

install=false
case "${1:-}" in
  "") ;;
  --install) install=true ;;
  *) echo "usage: $0 [--install]" >&2; exit 1 ;;
esac

if [[ "$(uname)" != "Linux" ]]; then
  echo "error: this script is for Linux; on macOS use ./build-ios.sh" >&2
  exit 1
fi

for tool in flutter xlinux xtool; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: $tool not found in PATH (setup: https://github.com/cesardev31/xlinux#installation)" >&2
    exit 1
  fi
done

version="$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' pubspec.yaml)"
ipa="dist/gym-progression-v${version}-unsigned.ipa"

# Start Darling's server first, detached from our output. If `flutter assemble` starts it
# (through gen_snapshot), the server inherits gen_snapshot's stdout/stderr pipes and keeps
# them open, so flutter waits forever. On a fresh setup xlinux installs Darling itself.
if command -v darling >/dev/null 2>&1; then
  DPREFIX="${XLINUX_DATA:-$HOME/.local/share/xlinux}/darling-prefix" darling shell true </dev/null >/dev/null 2>&1
fi

# Release build into build/ios-linux/ (runs `flutter pub get` itself).
xlinux build --project .

mkdir -p dist
cp build/ios-linux/gym_progression.ipa "$ipa"
echo "IPA ready: $ipa"

# Plain `xtool install`, not `xlinux build --install`: on a stuck install xlinux
# uninstalls the app to retry, which deletes the workouts stored on the phone.
if $install; then
  xtool install "$ipa"
fi
