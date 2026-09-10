#!/usr/bin/env bash
# build_ipa.sh — Builds TamaNDI.xcarchive and exports the production .ipa package.
# Run this script on a Mac with Xcode 16+ installed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

PROJECT_NAME="TamaNDI"
SCHEME_NAME="TamaNDI"
CONFIGURATION="Release"
BUILD_DIR="${ROOT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/ipa"
EXPORT_OPTIONS="${ROOT_DIR}/ExportOptions.plist"

echo "========================================================"
echo "          TamaNDI — iOS IPA Build Pipeline              "
echo "========================================================"
echo "Root directory:  ${ROOT_DIR}"
echo "Build directory: ${BUILD_DIR}"
echo "Scheme:          ${SCHEME_NAME}"
echo "Configuration:   ${CONFIGURATION}"
echo "========================================================"

# Step 1: Ensure Xcode project exists
if [ ! -d "${PROJECT_NAME}.xcodeproj" ]; then
    echo "[1/4] Generating Xcode project with XcodeGen..."
    if command -v xcodegen &> /dev/null; then
        xcodegen generate
    else
        echo "Error: XcodeGen is not installed."
        echo "Install it via Homebrew: brew install xcodegen"
        exit 1
    fi
else
    echo "[1/4] Using existing ${PROJECT_NAME}.xcodeproj..."
fi

# Step 2: Clean build artifacts
echo "[2/4] Cleaning build artifacts..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Step 3: Build archive
echo "[3/4] Creating Xcode Archive (generic/platform=iOS)..."
xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME_NAME}" \
    -configuration "${CONFIGURATION}" \
    -destination 'generic/platform=iOS' \
    -archivePath "${ARCHIVE_PATH}" \
    -allowProvisioningUpdates \
    CODE_SIGNING_ALLOWED=YES \
    COMPILER_INDEX_STORE_ENABLE=NO

if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo "Error: Failed to produce archive at ${ARCHIVE_PATH}"
    exit 1
fi

echo "Archive created successfully at: ${ARCHIVE_PATH}"

# Step 4: Export IPA
echo "[4/4] Exporting IPA from archive..."
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -exportPath "${EXPORT_PATH}" \
    -allowProvisioningUpdates

# Step 5: Verify output
IPA_FILE=$(find "${EXPORT_PATH}" -maxdepth 1 -name "*.ipa" | head -n 1)

if [ -n "${IPA_FILE}" ] && [ -f "${IPA_FILE}" ]; then
    FILE_SIZE=$(du -h "${IPA_FILE}" | cut -f1)
    echo ""
    echo "========================================================"
    echo " SUCCESS! IPA generated successfully:"
    echo " Path: ${IPA_FILE}"
    echo " Size: ${FILE_SIZE}"
    echo "========================================================"
    echo ""
    echo "You can install this IPA onto an iPhone using:"
    echo "1. Apple Configurator 2"
    echo "2. Xcode -> Window -> Devices and Simulators"
    echo "3. Sideloadly / AltStore"
    echo "4. ios-deploy: ios-deploy --bundle \"${IPA_FILE}\""
else
    echo "Error: IPA export finished but no .ipa file was found in ${EXPORT_PATH}."
    exit 1
fi
