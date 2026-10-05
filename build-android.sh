#!/usr/bin/env bash
# Builds a release-signed APK for sideloading / GitHub Releases.
# Output: dist/gym-progression-v<version>.apk
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found in PATH" >&2
  exit 1
fi

if [[ ! -f android/key.properties ]]; then
  echo "error: android/key.properties not found." >&2
  echo "A release keystore is required, otherwise updates won't install over previous versions." >&2
  echo "See DEPLOY_PLAN.md -> 'Android signing'." >&2
  exit 1
fi

version="$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' pubspec.yaml)"
apk="dist/gym-progression-v${version}.apk"

flutter pub get
flutter build apk --release

mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk "$apk"
echo "APK ready: $apk"
