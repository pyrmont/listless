#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS="$REPO_ROOT/.asc/secrets.sh"

if [[ ! -f "$SECRETS" ]]; then
    echo "Error: $SECRETS not found. See .asc/secrets.sh.example for the required format."
    exit 1
fi

source "$SECRETS"

APP_ID="6759801710"
SCHEME="Listless macOS"
ARCHIVE_PATH="/tmp/Listless-mac-latest.xcarchive"
EXPORT_PATH="/tmp/Listless-mac-export"
EXPORT_PLIST="/tmp/Listless-mac-ExportOptions.plist"
PKG_PATH="$EXPORT_PATH/Listless.pkg"
SIGNING_DIR="$REPO_ROOT/.asc/macos-signing"
APP_P12="$SIGNING_DIR/app-headless.p12"
INSTALLER_P12="$SIGNING_DIR/installer-headless.p12"
TMP_KEYCHAIN="$REPO_ROOT/.asc/build.keychain-db"

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
security import "$APP_P12" -k "$TMP_KEYCHAIN" -P "$DIST_P12_PASS" \
    -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/productbuild
security import "$INSTALLER_P12" -k "$TMP_KEYCHAIN" -P "$DIST_P12_PASS" \
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
    -destination 'generic/platform=macOS' \
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
    <string>3rd Party Mac Developer Application</string>
    <key>installerSigningCertificate</key>
    <string>3rd Party Mac Developer Installer</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>net.inqk.listless</key>
        <string>Listless macOS Distribution</string>
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

echo "==> Exporting PKG..."
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST"

echo "==> Uploading to App Store Connect..."
mkdir -p "$REPO_ROOT/private_keys"
cp "$REPO_ROOT/.asc/AuthKey_${KEY_ID}.p8" "$REPO_ROOT/private_keys/"
xcrun iTMSTransporter \
    -m upload \
    -assetFile "$PKG_PATH" \
    -apiKey "$KEY_ID" \
    -apiIssuer "$ISSUER_ID" \
    -v informational
rm -f "$REPO_ROOT/private_keys/AuthKey_${KEY_ID}.p8"
rmdir "$REPO_ROOT/private_keys" 2>/dev/null || true

echo "==> Done!"
