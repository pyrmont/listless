#!/bin/bash
set -euo pipefail

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

DEVICE=$(xcrun simctl list devices available "iOS ${RUNTIME}" \
  | grep "iPhone" \
  | head -1 \
  | sed 's/^ *\(.*\) ([A-F0-9-]*).*/\1/')

if [ -z "$DEVICE" ]; then
  echo "No available iPhone simulator found for iOS ${RUNTIME}." >&2
  exit 1
fi

echo "Using ${DEVICE}, iOS ${RUNTIME}"

xcodebuild test \
  -scheme "Listless iOS" \
  -destination "platform=iOS Simulator,name=${DEVICE},OS=${RUNTIME}" \
  -only-testing:"Listless iOS UI Tests" \
  2>&1
