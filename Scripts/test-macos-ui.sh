#!/bin/bash
set -euo pipefail

xcodebuild test \
  -scheme "Listless macOS" \
  -destination 'platform=macOS' \
  -only-testing:"Listless macOS UI Tests" \
  2>&1
