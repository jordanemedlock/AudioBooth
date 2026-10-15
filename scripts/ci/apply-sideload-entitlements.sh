#!/usr/bin/env bash
# Overwrites target entitlements with sideload-safe stubs for the unsigned IPA job only.
# Does not affect normal developer builds (run only in GitHub Actions).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="${ROOT}/AudioBooth/CI/SideloadEntitlements"

apply() {
  local rel="$1"
  cp "${SRC}/$(basename "$rel")" "${ROOT}/${rel}"
}

apply "AudioBooth/AudioBooth/AudioBooth.entitlements"
apply "AudioBooth/AudioBooth Watch App/AudioBooth Watch App.entitlements"
apply "AudioBooth/AudioBoothWidget/AudioBoothWidgetExtension.entitlements"
apply "AudioBooth/AudioBoothWatchWidget/AudioBoothWatchWidgetExtension.entitlements"

echo "Applied sideload-safe entitlements (IAP/NFC/iCloud/app groups/CarPlay/Wi‑Fi info removed)."
