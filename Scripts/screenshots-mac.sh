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

SCREENSHOT_TMP="/tmp/listless-screenshots"
FRAMED_TMP="/tmp/listless-framed"
MARKETING_DIR="$(pwd)/Marketing"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Mac ASC canvas dimensions (16:10)
CANVAS_WIDTH=2880
CANVAS_HEIGHT=1800

CAPTIONS=(
  "Syncs via iCloud"
  "Dark Mode"
  "Natural Selection"
)

XCRESULT_DIR=$(mktemp -d)

# Run screenshot tests (attachments stored in xcresult bundle)
echo "==> Running macOS screenshot tests..."
xcodebuild test \
  -scheme "Listless macOS" \
  -destination "platform=macOS" \
  -only-testing:"Listless macOS UI Tests/ListlessMacScreenshots" \
  -resultBundlePath "${XCRESULT_DIR}/result.xcresult" \
  2>&1

# Extract attachments from xcresult bundle
echo "==> Extracting screenshots from xcresult..."
rm -rf "${SCREENSHOT_TMP}"
mkdir -p "${SCREENSHOT_TMP}"
xcrun xcresulttool export attachments \
  --path "${XCRESULT_DIR}/result.xcresult" \
  --output-path "${SCREENSHOT_TMP}"

# Rename attachments using manifest.json (attachment name -> file)
osascript -l JavaScript -e "
var manifest = JSON.parse($.NSString.alloc.initWithDataEncoding(
  $.NSData.dataWithContentsOfFile('${SCREENSHOT_TMP}/manifest.json'),
  $.NSUTF8StringEncoding).js);
var fm = $.NSFileManager.defaultManager;
manifest.forEach(function(entry) {
  (entry.attachments || []).forEach(function(att) {
    var exported = att.exportedFileName || '';
    var suggested = att.suggestedHumanReadableName || '';
    if (exported && suggested) {
      var name = suggested.replace(/_\d+_[A-F0-9-]+\.png$/, '');
      var src = '${SCREENSHOT_TMP}/' + exported;
      var dst = '${SCREENSHOT_TMP}/' + name + '.png';
      fm.moveItemAtPathToPathError(src, dst, null);
    }
  });
});"

rm -rf "${XCRESULT_DIR}"

if ! ls "${SCREENSHOT_TMP}"/*.png 1>/dev/null 2>&1; then
  echo "No screenshots found in ${SCREENSHOT_TMP}."
  exit 1
fi

mkdir -p "${MARKETING_DIR}"

if [ "$DO_COMPOSE" = true ]; then
  DESKTOP_TMP="/tmp/listless-desktop"
  mkdir -p "${DESKTOP_TMP}"
  mkdir -p "${FRAMED_TMP}"

  echo ""
  echo "Composing desktop images..."
  n=0
  for file in "${SCREENSHOT_TMP}"/0*.png; do
    swift "${SCRIPT_DIR}/screenshots-mac-desktop.swift" "$file" "${DESKTOP_TMP}/desktop_${n}.png" "$(pwd)/Marketing/sequoia-wallpaper.jpg"
    echo "  desktop_${n}.png"
    n=$((n + 1))
  done

  echo "Framing screenshots..."
  n=0
  for file in "${DESKTOP_TMP}"/desktop_*.png; do
    shortcuts run "Frame Screenshots" -i "$file" -o "${FRAMED_TMP}/framed_${n}.png"
    echo "  Framed screenshot ${n}"
    n=$((n + 1))
  done

  rm -rf "${DESKTOP_TMP}"

  echo "Composing final images..."
  n=0
  for file in "${FRAMED_TMP}"/framed_*.png; do
    caption="${CAPTIONS[$n]:-}"
    swift "${SCRIPT_DIR}/screenshots-ios-compose.swift" "$file" "${MARKETING_DIR}/mac_${n}.png" "$caption" "$CANVAS_WIDTH" "$CANVAS_HEIGHT"
    echo "  mac_${n}.png — ${caption}"
    n=$((n + 1))
  done

  rm -rf "${FRAMED_TMP}"
else
  OUTPUT_DIR="$(pwd)"
  echo ""
  n=0
  for file in "${SCREENSHOT_TMP}"/0*.png; do
    cp "$file" "${OUTPUT_DIR}/mac_${n}.png"
    n=$((n + 1))
  done
fi

rm -rf "${SCREENSHOT_TMP}"

if [ "$DO_COMPOSE" = true ]; then
  echo ""
  echo "Screenshots saved to ${MARKETING_DIR}/"
  ls -la "${MARKETING_DIR}"/mac_*.png
else
  echo ""
  echo "Screenshots saved to ${OUTPUT_DIR}/"
  ls -la "${OUTPUT_DIR}"/mac_*.png
fi
