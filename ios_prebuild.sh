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

# Return to project root
cd ..

echo "iOS prebuild script completed successfully"
