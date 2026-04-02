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

MAJOR="${1:-26}"
RUNTIME=$(xcrun simctl list runtimes available \
  | grep "iOS ${MAJOR}\." \
  | sed 's/.*iOS \([0-9.]*\).*/\1/' \
  | sort -t. -k1,1n -k2,2n \
  | tail -1)

if [ -z "$RUNTIME" ]; then
  echo "No available iOS ${MAJOR}.x simulator runtime found." >&2
  exit 1
fi

# Prefer iPad Pro 13" for ASC screenshots (2064x2752)
DEVICE=$(xcrun simctl list devices available "iOS ${RUNTIME}" \
  | grep "iPad Pro 13" \
  | head -1 \
  | sed 's/^ *\(.*\) ([A-F0-9-]*).*/\1/')
if [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun simctl list devices available "iOS ${RUNTIME}" \
    | grep "iPad" \
    | head -1 \
    | sed 's/^ *\(.*\) ([A-F0-9-]*).*/\1/')
fi

if [ -z "$DEVICE" ]; then
  echo "No available iPad simulator found for iOS ${RUNTIME}." >&2
  exit 1
fi

echo "Using ${DEVICE}, iOS ${RUNTIME}"

# Boot simulator if needed
UDID=$(xcrun simctl list devices available "iOS ${RUNTIME}" \
  | grep "$DEVICE" \
  | head -1 \
  | sed 's/.*(\([A-F0-9-]*\)).*/\1/')

xcrun simctl boot "$UDID" 2>/dev/null || true

# Override status bar: 9:41, full signal, full battery
xcrun simctl status_bar "$UDID" override \
  --time "9:41" \
  --batteryState discharging \
  --batteryLevel 100 \
  --wifiBars 3 \
  --cellularBars 4 \
  --cellularMode active \
  --dataNetwork wifi

echo "Status bar overridden"

SCREENSHOT_TMP="/tmp/listless-screenshots"
FRAMED_TMP="/tmp/listless-framed"
MARKETING_DIR="$(pwd)/Marketing"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# iPad Pro 13" ASC canvas dimensions
CANVAS_WIDTH=2064
CANVAS_HEIGHT=2752

CAPTIONS=(
  "Syncs via iCloud"
  "Minimalist"
  "Gesture Based"
  "(Slightly) Customisable"
)

# Run screenshot tests (same iOS UI test target, different simulator)
xcodebuild test \
  -scheme "Listless iOS" \
  -destination "platform=iOS Simulator,name=${DEVICE},OS=${RUNTIME}" \
  -only-testing:"Listless iOS UI Tests/ListlessiOSScreenshots" \
  2>&1

# Clear status bar override (ignore errors if simulator already shut down)
xcrun simctl status_bar "$UDID" clear 2>/dev/null || true

if ! ls "${SCREENSHOT_TMP}"/*.png 1>/dev/null 2>&1; then
  echo "No screenshots found in ${SCREENSHOT_TMP}."
  exit 1
fi

mkdir -p "${MARKETING_DIR}"

if [ "$DO_COMPOSE" = true ]; then
  mkdir -p "${FRAMED_TMP}"

  echo ""
  echo "Framing screenshots..."
  n=0
  for file in "${SCREENSHOT_TMP}"/0*.png; do
    shortcuts run "Frame Screenshots" -i "$file" -o "${FRAMED_TMP}/framed_${n}.png"
    echo "  Framed screenshot ${n}"
    n=$((n + 1))
  done

  echo "Composing final images..."
  n=0
  for file in "${FRAMED_TMP}"/framed_*.png; do
    caption="${CAPTIONS[$n]:-}"
    swift "${SCRIPT_DIR}/screenshots-ios-compose.swift" "$file" "${MARKETING_DIR}/ipad_${n}.png" "$caption" "$CANVAS_WIDTH" "$CANVAS_HEIGHT"
    echo "  ipad_${n}.png — ${caption}"
    n=$((n + 1))
  done

  rm -rf "${FRAMED_TMP}"
else
  OUTPUT_DIR="$(pwd)"
  echo ""
  n=0
  for file in "${SCREENSHOT_TMP}"/0*.png; do
    cp "$file" "${OUTPUT_DIR}/ipad_${n}.png"
    n=$((n + 1))
  done
fi

rm -rf "${SCREENSHOT_TMP}"

if [ "$DO_COMPOSE" = true ]; then
  echo ""
  echo "Screenshots saved to ${MARKETING_DIR}/"
  ls -la "${MARKETING_DIR}"/ipad_*.png
else
  echo ""
  echo "Screenshots saved to ${OUTPUT_DIR}/"
  ls -la "${OUTPUT_DIR}"/ipad_*.png
fi
