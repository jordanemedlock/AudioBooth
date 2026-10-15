#!/usr/bin/env bash
# Ensures the iOS platform/simulator runtime is present and exports IOS_SIMULATOR_DESTINATION.
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:?}"
SCHEME="${SCHEME:?}"

if ! xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" 2>/dev/null \
  | grep -q 'platform:iOS Simulator'; then
  echo "iOS Simulator runtime missing; downloading iOS platform (this can take several minutes)…"
  xcodebuild -downloadPlatform iOS
fi

DEST=""
while IFS= read -r line; do
  if [[ "$line" == *"platform:iOS Simulator"* && "$line" == *"arch:arm64"* ]]; then
    id="$(sed -n 's/.*id:\([^,}]*\).*/\1/p' <<<"$line" | tr -d ' ')"
    if [ -n "$id" ]; then
      DEST="platform=iOS Simulator,id=${id}"
      break
    fi
  fi
done < <(xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" 2>/dev/null || true)

if [ -z "$DEST" ]; then
  echo "Could not resolve an iOS Simulator destination after platform install." >&2
  xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" >&2 || true
  exit 1
fi

echo "Using simulator destination: $DEST"
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "IOS_SIMULATOR_DESTINATION=$DEST" >>"$GITHUB_ENV"
fi
