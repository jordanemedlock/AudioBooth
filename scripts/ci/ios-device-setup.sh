#!/usr/bin/env bash
# Ensures the iOS device (iphoneos) platform is installed for unsigned device builds.
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:?}"
SCHEME="${SCHEME:?}"

for platform in iOS watchOS; do
  if ! xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" 2>/dev/null \
    | grep -qi "platform:${platform}"; then
    echo "${platform} platform missing; downloading…"
    xcodebuild -downloadPlatform "$platform"
  fi
done

if ! xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" 2>/dev/null \
  | grep -q 'platform:iOS, id:dvtdevice-DVTiPhonePlaceholder'; then
  echo "iOS device platform still unavailable." >&2
  xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" >&2 || true
  exit 1
fi

echo "iOS device platform is available."
