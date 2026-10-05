#!/usr/bin/env bash
# Builds the Xcode archive and an unsigned IPA for sideloading (AltStore / Sideloadly),
# which re-sign it with the installer's Apple ID.
# Output: build/ios/archive/Runner.xcarchive and dist/gym-progression-v<version>-unsigned.ipa
set -euo pipefail
cd "$(dirname "$0")"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "error: iOS builds require macOS with Xcode." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found in PATH" >&2
  exit 1
fi

version="$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' pubspec.yaml)"
ipa="dist/gym-progression-v${version}-unsigned.ipa"
app="build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app"

flutter pub get
flutter build ipa --release --no-codesign

# An IPA is a zip with the .app inside a top-level Payload/ folder.
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
mkdir "$staging/Payload"
cp -R "$app" "$staging/Payload/"

mkdir -p dist
rm -f "$ipa"
(cd "$staging" && zip -qry - Payload) > "$ipa"
echo "Archive ready: build/ios/archive/Runner.xcarchive"
echo "IPA ready: $ipa"
