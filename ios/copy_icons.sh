#!/bin/bash

# This script copies the required legacy icons to the built app bundle
# It should be run as a build phase in Xcode

# Get the path to the built app
APP_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"

# Copy the legacy icons to the app bundle
cp "${SRCROOT}/Runner/Icon-60@2x.png" "${APP_PATH}/Icon-60@2x.png"
cp "${SRCROOT}/Runner/Icon-76@2x.png" "${APP_PATH}/Icon-76@2x.png"
cp "${SRCROOT}/Runner/Icon-83.5@2x.png" "${APP_PATH}/Icon-83.5@2x.png"
cp "${SRCROOT}/Runner/Icon-120.png" "${APP_PATH}/Icon-120.png"
cp "${SRCROOT}/Runner/Icon-152.png" "${APP_PATH}/Icon-152.png"
cp "${SRCROOT}/Runner/Icon-167.png" "${APP_PATH}/Icon-167.png"
cp "${SRCROOT}/Runner/iTunesArtwork@2x.png" "${APP_PATH}/iTunesArtwork@2x.png"

echo "Legacy icons copied to app bundle"
