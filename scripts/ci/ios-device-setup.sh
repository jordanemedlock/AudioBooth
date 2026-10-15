#!/usr/bin/env bash
# Ensures the iOS device (iphoneos) platform is installed for unsigned device builds.
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:?}"
SCHEME="${SCHEME:?}"

if ! xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" 2>/dev/null \
  | grep -q 'platform:iOS, id:dvtdevice-DVTiPhonePlaceholder'; then
  echo "iOS device platform missing; downloading iOS platform…"
  xcodebuild -downloadPlatform iOS
fi

if ! xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" 2>/dev/null \
  | grep -q 'platform:iOS, id:dvtdevice-DVTiPhonePlaceholder'; then
  echo "iOS device platform still unavailable." >&2
  xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" >&2 || true
  exit 1
fi

echo "iOS device platform is available."
