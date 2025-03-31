#!/bin/bash
# Script to fix privacy bundle issues in iOS build

echo "Starting iOS build fix script..."

# Clean up any existing build artifacts
echo "Cleaning up build artifacts..."
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf build/ios
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.podspec
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/App.framework

# Remove privacy bundles
echo "Removing privacy bundles..."
find . -name "*_privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true
find . -name "*-privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true
find . -name "*Privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true

# Ensure Flutter environment is set up
echo "Setting up Flutter environment..."
flutter clean
flutter pub get

# Patch problematic plugins
echo "Patching plugins..."
FLUTTER_ROOT=$(which flutter | xargs dirname | xargs dirname)
echo "Flutter root: $FLUTTER_ROOT"

# Create Flutter/Generated.xcconfig if it doesn't exist
mkdir -p ios/Flutter
if [ ! -f ios/Flutter/Generated.xcconfig ]; then
  echo "Creating Generated.xcconfig..."
  cat > ios/Flutter/Generated.xcconfig << EOF
FLUTTER_ROOT=$FLUTTER_ROOT
FLUTTER_APPLICATION_PATH=$(pwd)
COCOAPODS_PARALLEL_CODE_SIGN=true
FLUTTER_TARGET=lib/main.dart
FLUTTER_BUILD_DIR=build
FLUTTER_BUILD_NAME=1.0.0
FLUTTER_BUILD_NUMBER=1
EXCLUDED_ARCHS[sdk=iphonesimulator*]=i386 arm64
DART_OBFUSCATION=false
TRACK_WIDGET_CREATION=true
TREE_SHAKE_ICONS=false
PACKAGE_CONFIG=$(pwd)/.dart_tool/package_config.json
EOF
fi

# Fix CocoaPods
echo "Setting up CocoaPods..."
cd ios
pod repo update
pod install --verbose
cd ..

# Build Flutter iOS
echo "Building Flutter iOS..."
flutter build ios --release --no-codesign

# Final cleanup of privacy bundles
echo "Final cleanup of privacy bundles..."
cd ios
find . -name "*_privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true
find . -name "*-privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true
find . -name "*Privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true

echo "iOS build fix script completed!"
