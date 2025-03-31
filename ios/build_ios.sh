#!/usr/bin/env bash
set -e

# Set up local properties
echo "Setting up Flutter project"
cd "$FCI_BUILD_DIR"

# Get Flutter dependencies
echo "Getting Flutter dependencies"
flutter pub get

# Find the sqflite_darwin plugin path
echo "Finding and patching sqflite_darwin plugin"
SQFLITE_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "sqflite_darwin-*" -type d | head -n 1)

if [ -n "$SQFLITE_PATH" ]; then
  echo "Found sqflite_darwin at: $SQFLITE_PATH"
  
  # Patch the source files to add the required SQLite flags
  SQFLITE_SOURCES="$SQFLITE_PATH/darwin/sqflite_darwin/Sources/sqflite_darwin"
  
  if [ -d "$SQFLITE_SOURCES" ]; then
    echo "Patching sqflite_darwin source files"
    
    # Add SQLite column metadata preprocessor definition to all .m files
    find "$SQFLITE_SOURCES" -name "*.m" -exec sed -i.bak '1s/^/#define SQLITE_ENABLE_COLUMN_METADATA 1\n/' {} \;
    
    # Copy our patch header to the sqflite_darwin directory
    cp "$FCI_BUILD_DIR/ios/sqflite_darwin_patch.h" "$SQFLITE_SOURCES/"
    
    # Add include for our patch header to all .m files
    find "$SQFLITE_SOURCES" -name "*.m" -exec sed -i.bak '2s/^/#import "sqflite_darwin_patch.h"\n/' {} \;
    
    echo "Patched sqflite_darwin source files successfully"
  else
    echo "Could not find sqflite_darwin source directory at: $SQFLITE_SOURCES"
  fi
else
  echo "Could not find sqflite_darwin plugin"
fi

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

# Apply additional fixes to Pods project
echo "Applying additional fixes to Pods project"
find . -name "sqflite_darwin.xcconfig" -exec sed -i.bak 's/-framework "Flutter"/-framework "Flutter" -DSQLITE_ENABLE_COLUMN_METADATA/g' {} \;

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
  -allowProvisioningUpdates \
  OTHER_CFLAGS="-DSQLITE_ENABLE_COLUMN_METADATA" \
  GCC_PREPROCESSOR_DEFINITIONS="SQLITE_ENABLE_COLUMN_METADATA=1 \$(inherited)"

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
