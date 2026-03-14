#!/bin/bash
set -euo pipefail

xcodebuild test \
  -scheme "Listless iOS" \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  -only-testing:"Listless iOS UI Tests" \
  2>&1
