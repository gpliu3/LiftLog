#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/GPLift.xcodeproj}"
SCHEME="${SCHEME:-GPLift}"
TEAM_ID="${TEAM_ID:-TPWZ9R3L98}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/releases}"

API_KEY_ID="${API_KEY_ID:-}"
API_ISSUER_ID="${API_ISSUER_ID:-}"
P8_PATH="${P8_PATH:-}"
ALLOW_DIRTY="${ALLOW_DIRTY:-0}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release_testflight.sh --api-key <KEY_ID> --issuer <ISSUER_ID> [--p8 <path>] [--allow-dirty]

Environment alternatives:
  API_KEY_ID, API_ISSUER_ID, P8_PATH, ALLOW_DIRTY=1

Notes:
  - Script flow: archive -> export ipa -> validate -> upload -> wait delivery status
  - Validation failure stops upload, which avoids many failed-upload notification emails.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-key)
      API_KEY_ID="$2"
      shift 2
      ;;
    --issuer)
      API_ISSUER_ID="$2"
      shift 2
      ;;
    --p8)
      P8_PATH="$2"
      shift 2
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$API_KEY_ID" || -z "$API_ISSUER_ID" ]]; then
  echo "Missing API credentials: --api-key and --issuer are required." >&2
  exit 1
fi

if [[ -z "$P8_PATH" ]]; then
  P8_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8"
fi

if [[ ! -f "$P8_PATH" ]]; then
  echo "Missing p8 file: $P8_PATH" >&2
  echo "Pass --p8 <path> or place AuthKey_${API_KEY_ID}.p8 under ~/.appstoreconnect/private_keys/" >&2
  exit 1
fi

if [[ "$ALLOW_DIRTY" != "1" ]]; then
  if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
    echo "Working tree is dirty. Commit/stash first, or use --allow-dirty." >&2
    exit 1
  fi
fi

for tool in xcodebuild xcrun sed awk; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing required tool: $tool" >&2; exit 1; }
done

mkdir -p "$BUILD_DIR"
export API_PRIVATE_KEYS_DIR
API_PRIVATE_KEYS_DIR="$(dirname "$P8_PATH")"

SETTINGS="$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -showBuildSettings 2>/dev/null)"
MARKETING_VERSION="$(printf "%s\n" "$SETTINGS" | awk -F' = ' '/MARKETING_VERSION = /{print $2; exit}')"
BUILD_NUMBER="$(printf "%s\n" "$SETTINGS" | awk -F' = ' '/CURRENT_PROJECT_VERSION = /{print $2; exit}')"

if [[ -z "$MARKETING_VERSION" || -z "$BUILD_NUMBER" ]]; then
  echo "Failed to read MARKETING_VERSION/CURRENT_PROJECT_VERSION from build settings." >&2
  exit 1
fi

ARCHIVE_PATH="$BUILD_DIR/${SCHEME}-${MARKETING_VERSION}-${BUILD_NUMBER}.xcarchive"
EXPORT_PATH="$BUILD_DIR/export-${BUILD_NUMBER}"
IPA_PATH="$EXPORT_PATH/${SCHEME}.ipa"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions-TestFlight.plist"

echo "==> Releasing $SCHEME version $MARKETING_VERSION ($BUILD_NUMBER)"
echo "==> Archive path: $ARCHIVE_PATH"

cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>destination</key>
  <string>export</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
  <key>uploadSymbols</key>
  <true/>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
</dict>
</plist>
PLIST

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

echo "==> Step 1/5: Archive"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive

echo "==> Step 2/5: Export IPA"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

if [[ ! -f "$IPA_PATH" ]]; then
  echo "IPA not found after export: $IPA_PATH" >&2
  exit 1
fi

echo "==> Step 3/5: Validate (upload is blocked if validation fails)"
xcrun altool \
  --validate-app \
  --file "$IPA_PATH" \
  --type ios \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$API_ISSUER_ID"

echo "==> Step 4/5: Upload to TestFlight"
UPLOAD_OUTPUT="$(
  xcrun altool \
    --upload-app \
    --file "$IPA_PATH" \
    --type ios \
    --apiKey "$API_KEY_ID" \
    --apiIssuer "$API_ISSUER_ID" 2>&1
)"
printf "%s\n" "$UPLOAD_OUTPUT"

DELIVERY_ID="$(printf "%s\n" "$UPLOAD_OUTPUT" | sed -n 's/.*Delivery UUID: \([a-fA-F0-9-]\+\).*/\1/p' | head -n1)"
if [[ -z "$DELIVERY_ID" ]]; then
  echo "Upload completed but Delivery UUID was not found in output." >&2
  exit 1
fi

echo "==> Step 5/5: Wait delivery status"
xcrun altool \
  --build-status \
  --delivery-id "$DELIVERY_ID" \
  --wait \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$API_ISSUER_ID" \
  --output-format json

echo "==> Done. Uploaded version $MARKETING_VERSION ($BUILD_NUMBER). Delivery UUID: $DELIVERY_ID"
