#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS="$REPO_ROOT/.asc/secrets.sh"

if [[ ! -f "$SECRETS" ]]; then
    echo "Error: $SECRETS not found. See .asc/secrets.sh.example for the required format."
    exit 1
fi

source "$SECRETS"

SCHEME="Listless iOS"
ARCHIVE_PATH="/tmp/Listless-latest.xcarchive"
EXPORT_PATH="/tmp/Listless-export"
EXPORT_PLIST="/tmp/Listless-ExportOptions.plist"
IPA_PATH="$EXPORT_PATH/Listless iOS.ipa"
DIST_P12="$REPO_ROOT/.asc/ios-signing/dist-headless.p12"
TMP_KEYCHAIN="$REPO_ROOT/.asc/build.keychain-db"

CHECK_ONLY=false
if [[ "${1:-}" == "--check" ]]; then
    CHECK_ONLY=true
fi

cd "$REPO_ROOT"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Error: Git repository is dirty. Commit or stash changes before publishing."
    exit 1
fi

echo "==> Setting up temporary keychain..."
security delete-keychain "$TMP_KEYCHAIN" 2>/dev/null || true
security create-keychain -p "$TMP_KEYCHAIN_PASS" "$TMP_KEYCHAIN"
security unlock-keychain -p "$TMP_KEYCHAIN_PASS" "$TMP_KEYCHAIN"
security set-keychain-settings -lut 21600 "$TMP_KEYCHAIN"
security import "$DIST_P12" -k "$TMP_KEYCHAIN" -P "$DIST_P12_PASS" \
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

echo "==> Archiving $SCHEME..."
xcodebuild \
    -scheme "$SCHEME" \
    -project Listless.xcodeproj \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    archive

echo "==> Writing export options..."
cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingCertificate</key>
    <string>iPhone Distribution</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>net.inqk.listless</key>
        <string>Listless iOS Distribution</string>
        <key>net.inqk.listless.watchos</key>
        <string>Listless watchOS Distribution</string>
    </dict>
    <key>destination</key>
    <string>export</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
PLIST

echo "==> Exporting IPA..."
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST"

echo "==> Checking entitlements in exported IPA..."
CHECK_DIR="/tmp/Listless-ipa-check"
rm -rf "$CHECK_DIR"
unzip -q "$IPA_PATH" -d "$CHECK_DIR"
codesign -d --entitlements - "$CHECK_DIR/Payload/Listless iOS.app"
rm -rf "$CHECK_DIR"

if $CHECK_ONLY; then
    echo "==> Check complete. Skipping upload."
    exit 0
fi

echo "==> Uploading to App Store Connect..."
mkdir -p "$REPO_ROOT/private_keys"
cp "$REPO_ROOT/.asc/AuthKey_${KEY_ID}.p8" "$REPO_ROOT/private_keys/"
xcrun iTMSTransporter \
    -m upload \
    -assetFile "$IPA_PATH" \
    -apiKey "$KEY_ID" \
    -apiIssuer "$ISSUER_ID" \
    -v informational
rm -f "$REPO_ROOT/private_keys/AuthKey_${KEY_ID}.p8"
rmdir "$REPO_ROOT/private_keys" 2>/dev/null || true

echo "==> Done!"
