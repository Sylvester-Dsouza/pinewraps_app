#!/bin/bash
set -e

echo "Running iOS prebuild script..."

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

# Navigate to iOS directory
cd ios

# Install pods
echo "Installing CocoaPods dependencies..."
pod install

# Fix webview_flutter_wkwebview symlink issue
echo "Fixing webview_flutter_wkwebview issues..."
WEBVIEW_DIR="./Pods/Target Support Files/webview_flutter_wkwebview"
if [ -d "$WEBVIEW_DIR" ]; then
  echo "Found webview_flutter_wkwebview at $WEBVIEW_DIR"
  
  # Create the directory structure if it doesn't exist
  mkdir -p "./Pods/webview_flutter_wkwebview/Sources/webview_flutter_wkwebview/include/webview_flutter_wkwebview"
  
  # Create an empty Flutter.h file if it doesn't exist
  touch "./Pods/webview_flutter_wkwebview/Sources/webview_flutter_wkwebview/include/webview_flutter_wkwebview/Flutter.h"
  
  echo "Created missing Flutter.h file for webview_flutter_wkwebview"
else
  echo "webview_flutter_wkwebview directory not found, skipping fix"
fi

# Return to the project root
cd ..

echo "iOS prebuild script completed successfully"
