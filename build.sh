#!/bin/bash
set -euo pipefail

# Build EchoWrite.app for arm64 (Apple Silicon native)
# This script compiles, packages, and signs the app with microphone entitlements.

APP_NAME="EchoWrite"
BUNDLE_ID="com.urieljavier.EchoWrite"
BUILD_DIR=".build/arm64-apple-macosx/release"
APP_DIR="${APP_NAME}.app"
ENTITLEMENTS="EchoWrite.entitlements"

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

# Copy whisper framework
cp -R "Frameworks/whisper.xcframework/macos-arm64_x86_64/whisper.framework" "${APP_DIR}/Contents/Frameworks/"

# Fix rpath for the framework
install_name_tool -add_rpath "@executable_path/../Frameworks" "${APP_DIR}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

SIGN_IDENTITY="EchoWrite Dev"

echo "==> Signing with certificate '${SIGN_IDENTITY}'..."
# Sign the framework first
codesign --force --sign "${SIGN_IDENTITY}" "${APP_DIR}/Contents/Frameworks/whisper.framework"
# Sign the app with entitlements
codesign --force --sign "${SIGN_IDENTITY}" --entitlements "${ENTITLEMENTS}" "${APP_DIR}"

echo "==> Verifying..."
codesign -dvvv "${APP_DIR}" 2>&1 | grep -E "Signature|Identifier|CDHash|Authority"
codesign -d --entitlements - "${APP_DIR}" 2>&1 | head -20

echo ""
echo "==> Done! Run with: open ${APP_DIR}"
