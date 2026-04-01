#!/bin/bash
set -euo pipefail

PLATFORM="${1:-macos}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

case "$PLATFORM" in
  macos)
    SECRETS="$REPO_ROOT/.asc/secrets.sh"

    if [[ ! -f "$SECRETS" ]]; then
      echo "Error: $SECRETS not found. See Scripts/secrets.sh.example for the required format."
      exit 1
    fi

    source "$SECRETS"

    DEV_P12="$REPO_ROOT/.asc/dev.p12"
    TMP_KEYCHAIN="$REPO_ROOT/.asc/build.keychain-db"

    echo "==> Setting up temporary keychain..."
    security delete-keychain "$TMP_KEYCHAIN" 2>/dev/null || true
    security create-keychain -p "$TMP_KEYCHAIN_PASS" "$TMP_KEYCHAIN"
    security unlock-keychain -p "$TMP_KEYCHAIN_PASS" "$TMP_KEYCHAIN"
    security set-keychain-settings -lut 21600 "$TMP_KEYCHAIN"
    security import "$DEV_P12" -k "$TMP_KEYCHAIN" -P "$DEV_P12_PASS" \
        -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/productbuild
    security set-key-partition-list -S apple-tool:,apple:,codesign:,productbuild: \
        -s -k "$TMP_KEYCHAIN_PASS" "$TMP_KEYCHAIN"
    security list-keychains -d user -s "$TMP_KEYCHAIN" ~/Library/Keychains/login.keychain-db

    cleanup_keychain() {
        echo "==> Restoring keychain search list..."
        security list-keychains -d user -s ~/Library/Keychains/login.keychain-db
        security default-keychain -d user -s ~/Library/Keychains/login.keychain-db
        security delete-keychain "$TMP_KEYCHAIN" 2>/dev/null || true
    }
    trap cleanup_keychain EXIT

    echo "==> Running macOS unit tests..."
    xcodebuild test \
      -scheme "Listless macOS" \
      -destination 'platform=macOS' \
      -only-testing:"Listless macOS Unit Tests" \
      2>&1
    ;;
  ios)
    MAJOR="${2:-26}"
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
      -only-testing:"Listless iOS Unit Tests" \
      2>&1
    ;;
  *)
    echo "Usage: $0 [macos|ios] [ios-major-version]" >&2
    exit 1
    ;;
esac
