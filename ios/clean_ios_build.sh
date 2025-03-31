#!/bin/bash
# Script to clean iOS build environment before building

echo "Starting iOS build cleanup..."

# Clean Flutter project
echo "Cleaning Flutter project..."
cd "$(dirname "$0")/.."
flutter clean

# Remove CocoaPods artifacts
echo "Removing CocoaPods artifacts..."
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks

# Remove Flutter artifacts
echo "Removing Flutter artifacts..."
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
rm -rf ios/Flutter/App.framework

# Remove DerivedData
echo "Removing Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*Runner*

# Remove privacy bundles
echo "Removing privacy bundles..."
find . -name "*_privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true
find . -name "*-privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true
find . -name "*Privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Install pods
echo "Installing pods..."
cd ios
pod install --repo-update

echo "Cleanup complete! You can now build the iOS app."
