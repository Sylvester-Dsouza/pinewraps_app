#!/usr/bin/env bash
set -e

# Set up local properties
echo "Setting up Flutter project"
cd "$FCI_BUILD_DIR"

# Get Flutter dependencies
echo "Getting Flutter dependencies"
flutter clean
flutter pub get

# Prepare iOS build environment
echo "Preparing iOS build environment"
cd ios

# Clean Pods to ensure fresh installation
echo "Cleaning Pods"
rm -rf Pods
rm -f Podfile.lock

# Install pods with special flags for sqflite_darwin
echo "Installing Pods"
pod install --repo-update

# Return to project root
cd ..

# Create a directory for the archive
mkdir -p "$FCI_BUILD_DIR/build/ios/archive"

# Build and archive with xcodebuild
echo "Building and archiving iOS app with xcodebuild"

# Use xcodebuild to build and archive in one step
xcodebuild clean archive \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$FCI_BUILD_DIR/build/ios/archive/Runner.xcarchive" \
  DEVELOPMENT_TEAM="4J9WXB52YV" \
  CODE_SIGN_STYLE="Automatic" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  -allowProvisioningUpdates

# Check if archive was created
if [ -d "$FCI_BUILD_DIR/build/ios/archive/Runner.xcarchive" ]; then
  echo "Archive created successfully at $FCI_BUILD_DIR/build/ios/archive/Runner.xcarchive"
  ls -la "$FCI_BUILD_DIR/build/ios/archive/Runner.xcarchive"
else
  echo "Failed to create archive at $FCI_BUILD_DIR/build/ios/archive/Runner.xcarchive"
  echo "Listing build directory contents:"
  find "$FCI_BUILD_DIR/build" -type d | sort
  exit 1
fi
