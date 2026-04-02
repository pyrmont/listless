#!/bin/bash
set -euo pipefail

DO_COMPOSE=false
while getopts "c" opt; do
  case $opt in
    c) DO_COMPOSE=true ;;
    *) ;;
  esac
done
shift $((OPTIND - 1))

MAJOR="${1:-11}"
RUNTIME=$(xcrun simctl list runtimes available \
  | grep "watchOS ${MAJOR}\." \
  | sed 's/.*watchOS \([0-9.]*\).*/\1/' \
  | sort -t. -k1,1n -k2,2n \
  | tail -1)

if [ -z "$RUNTIME" ]; then
  echo "No available watchOS ${MAJOR}.x simulator runtime found." >&2
  exit 1
fi

DEVICE=$(xcrun simctl list devices available "watchOS ${RUNTIME}" \
  | grep "Apple Watch" \
  | head -1 \
  | sed 's/^ *\(.*\) ([A-F0-9-]*).*/\1/')

if [ -z "$DEVICE" ]; then
  echo "No available Apple Watch simulator found for watchOS ${RUNTIME}." >&2
  exit 1
fi

echo "Using ${DEVICE}, watchOS ${RUNTIME}"

# Boot simulator if needed
UDID=$(xcrun simctl list devices available "watchOS ${RUNTIME}" \
  | grep "$DEVICE" \
  | head -1 \
  | sed 's/.*(\([A-F0-9-]*\)).*/\1/')

xcrun simctl boot "$UDID" 2>/dev/null || true

SCREENSHOT_TMP="/tmp/listless-screenshots"
FRAMED_TMP="/tmp/listless-framed"
MARKETING_DIR="$(pwd)/Marketing"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CAPTION="Get Up and Do"

# Run screenshot tests (writes to SCREENSHOT_TMP)
xcodebuild test \
  -scheme "Listless watchOS" \
  -destination "platform=watchOS Simulator,name=${DEVICE},OS=${RUNTIME}" \
  -only-testing:"Listless watchOS UI Tests/ListlessWatchScreenshots" \
  2>&1

if ! ls "${SCREENSHOT_TMP}"/*.png 1>/dev/null 2>&1; then
  echo "No screenshots found in ${SCREENSHOT_TMP}."
  exit 1
fi

mkdir -p "${MARKETING_DIR}"

if [ "$DO_COMPOSE" = true ]; then
  mkdir -p "${FRAMED_TMP}"

  echo ""
  echo "Framing screenshot..."
  file="${SCREENSHOT_TMP}/01-items.png"
  shortcuts run "Frame Screenshots" -i "$file" -o "${FRAMED_TMP}/framed_0.png"
  echo "  Framed screenshot"

  echo "Composing final image..."
  swift "${SCRIPT_DIR}/screenshots-ios-compose.swift" "${FRAMED_TMP}/framed_0.png" "${MARKETING_DIR}/watch_0.png" "$CAPTION" 422 514
  echo "  watch_0.png — ${CAPTION}"

  rm -rf "${FRAMED_TMP}"
else
  OUTPUT_DIR="$(pwd)"
  echo ""
  cp "${SCREENSHOT_TMP}/01-items.png" "${OUTPUT_DIR}/watch_0.png"
fi

rm -rf "${SCREENSHOT_TMP}"

if [ "$DO_COMPOSE" = true ]; then
  echo ""
  echo "Screenshots saved to ${MARKETING_DIR}/"
  ls -la "${MARKETING_DIR}"/watch_*.png
else
  echo ""
  echo "Screenshots saved to ${OUTPUT_DIR}/"
  ls -la "${OUTPUT_DIR}"/watch_*.png
fi
