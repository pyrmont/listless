#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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

echo "==> Running macOS UI tests..."
xcodebuild test \
  -scheme "Listless macOS" \
  -destination 'platform=macOS' \
  -only-testing:"Listless macOS UI Tests" \
  2>&1
