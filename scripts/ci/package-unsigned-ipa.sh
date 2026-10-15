#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:?Usage: package-unsigned-ipa.sh /path/to/AudioBooth.app}"
OUT_DIR="${2:-.}"
IPA_NAME="${IPA_NAME:-AudioBooth-unsigned.ipa}"

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

mkdir -p "${STAGING}/Payload"
cp -R "$APP_PATH" "${STAGING}/Payload/"

(
  cd "$STAGING"
  zip -qr "${OUT_DIR}/${IPA_NAME}" Payload
)

echo "Created ${OUT_DIR}/${IPA_NAME}"
