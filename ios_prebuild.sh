#!/bin/bash
set -e

echo "Running iOS prebuild script..."

# Navigate to project directory
cd $FCI_BUILD_DIR/pinewraps_app

# Uncomment sign_in_with_apple for iOS build
sed -i '' 's/^  # sign_in_with_apple: \^5.0.0$/  sign_in_with_apple: \^5.0.0/' pubspec.yaml

# Clean Flutter cache
echo "Cleaning Flutter cache..."
flutter clean

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Fix iOS build issues
echo "Fixing iOS build environment..."
cd ios

# Update CocoaPods repos
echo "Updating CocoaPods repositories..."
pod repo update

# Install pods with repo update
echo "Installing pods with repo update..."
pod install --repo-update

# Create Flutter symlinks to fix header issues
echo "Creating Flutter framework symlinks..."
mkdir -p Pods/Flutter/Flutter.framework/Headers
ln -sf ../../../Flutter/engine/Flutter.framework/Headers/Flutter.h Pods/Flutter/Flutter.framework/Headers/Flutter.h

# Fix webview_flutter_wkwebview issues
echo "Fixing webview_flutter_wkwebview issues..."
WEBVIEW_POD_DIR=$(find . -type d -name "webview_flutter_wkwebview" | head -n 1)
if [ -n "$WEBVIEW_POD_DIR" ]; then
  echo "Found webview_flutter_wkwebview at $WEBVIEW_POD_DIR"
  mkdir -p $WEBVIEW_POD_DIR/Sources/webview_flutter_wkwebview/include/webview_flutter_wkwebview
  ln -sf ../../../../../Flutter/engine/Flutter.framework/Headers/Flutter.h $WEBVIEW_POD_DIR/Sources/webview_flutter_wkwebview/include/webview_flutter_wkwebview/Flutter.h
fi

# Fix sqflite_darwin issues
echo "Fixing sqflite_darwin issues..."
SQFLITE_POD_DIR=$(find . -type d -name "sqflite_darwin" | head -n 1)
if [ -n "$SQFLITE_POD_DIR" ]; then
  echo "Found sqflite_darwin at $SQFLITE_POD_DIR"
  mkdir -p $SQFLITE_POD_DIR/Sources/sqflite_darwin/include/sqflite_darwin
  ln -sf ../../../../../Flutter/engine/Flutter.framework/Headers/Flutter.h $SQFLITE_POD_DIR/Sources/sqflite_darwin/include/sqflite_darwin/Flutter.h
fi

# Fix any other potential Flutter.h issues by creating symlinks in all plugin directories
echo "Creating Flutter.h symlinks in all plugin directories..."
find . -type d -name "Sources" | while read sources_dir; do
  include_dir="$sources_dir/$(basename $(dirname $sources_dir))/include/$(basename $(dirname $sources_dir))"
  if [ -d "$include_dir" ]; then
    echo "Creating symlink in $include_dir"
    mkdir -p "$include_dir"
    ln -sf ../../../../../Flutter/engine/Flutter.framework/Headers/Flutter.h "$include_dir/Flutter.h"
  fi
done

# Return to project root
cd ..

echo "iOS prebuild script completed successfully"
