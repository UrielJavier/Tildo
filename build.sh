#!/bin/bash
set -euo pipefail

# Build EchoWrite.app for arm64 (Apple Silicon native)
# This script compiles, packages, and signs the app with microphone entitlements.

APP_NAME="Tildo"
BUNDLE_ID="com.urieljavier.Tildo"
BUILD_DIR=".build/arm64-apple-macosx/release"
APP_DIR="${APP_NAME}.app"
ENTITLEMENTS="Tildo.entitlements"

echo "==> Building for arm64 (release)..."
arch -arm64 swift build -c release --arch arm64

echo "==> Packaging ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Frameworks"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/VoiceToText" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
cp "Sources/VoiceToText/Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"

# Copy app icon
cp "icon/Tildo.icns" "${APP_DIR}/Contents/Resources/"

# Copy image resources
cp "Sources/VoiceToText/Resources/github-mark.png" "${APP_DIR}/Contents/Resources/"
cp "Sources/VoiceToText/Resources/github-mark-white.png" "${APP_DIR}/Contents/Resources/"

# Copy localizations
cp -R "Sources/VoiceToText/Resources/en.lproj" "${APP_DIR}/Contents/Resources/"
cp -R "Sources/VoiceToText/Resources/es.lproj" "${APP_DIR}/Contents/Resources/"

# Copy whisper framework
cp -R "Frameworks/whisper.xcframework/macos-arm64_x86_64/whisper.framework" "${APP_DIR}/Contents/Frameworks/"

# Fix rpath for the framework
install_name_tool -add_rpath "@executable_path/../Frameworks" "${APP_DIR}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

SIGN_IDENTITY="EchoWrite Dev"
# Stable designated requirement: bundle ID + certificate leaf hash (NOT CDHash).
# The cert hash is stable across builds — TCC persists the permission.
CERT_HASH="2A28BCB506A43FC5820049EAAD1D83EE64B081F8"
REQS_FILE="$(mktemp /tmp/req.XXXXXX)"
printf 'designated => identifier "%s" and certificate leaf = H"%s"' "${BUNDLE_ID}" "${CERT_HASH}" > "${REQS_FILE}"

echo "==> Signing with certificate '${SIGN_IDENTITY}'..."
codesign --force --sign "${SIGN_IDENTITY}" "${APP_DIR}/Contents/Frameworks/whisper.framework"
codesign --force --sign "${SIGN_IDENTITY}" --entitlements "${ENTITLEMENTS}" \
  -r "${REQS_FILE}" "${APP_DIR}"
rm -f "${REQS_FILE}"

echo "==> Verifying..."
codesign -dvvv "${APP_DIR}" 2>&1 | grep -E "Signature|Identifier|CDHash|Authority"
codesign -d --entitlements - "${APP_DIR}" 2>&1 | head -20

echo ""
echo "==> Done! Run with: open ${APP_DIR}"
echo ""
echo "==> Note: Accessibility permission persists across builds (cert-hash based requirement)."
echo "    First build under com.urieljavier.Tildo: grant permission once in System Settings > Accessibility."
