#!/usr/bin/env bash
set -e

# Set up local properties
echo "Setting up Flutter project"
cd "$FCI_BUILD_DIR"

# Get Flutter dependencies
echo "Getting Flutter dependencies"
flutter clean
flutter pub get

# Find and patch the sqflite_darwin plugin
echo "Finding and patching sqflite_darwin plugin"
SQFLITE_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "sqflite_darwin-*" -type d | head -n 1)

if [ -n "$SQFLITE_PATH" ]; then
  echo "Found sqflite_darwin at: $SQFLITE_PATH"
  
  # Patch the source files to add the required SQLite flags
  SQFLITE_SOURCES="$SQFLITE_PATH/darwin/sqflite_darwin/Sources/sqflite_darwin"
  
  if [ -d "$SQFLITE_SOURCES" ]; then
    echo "Patching sqflite_darwin source files"
    
    # Create a backup of original files
    mkdir -p "$SQFLITE_SOURCES/backup"
    cp "$SQFLITE_SOURCES/SqfliteDatabase.m" "$SQFLITE_SOURCES/backup/"
    cp "$SQFLITE_SOURCES/SqflitePlugin.m" "$SQFLITE_SOURCES/backup/"
    cp "$SQFLITE_SOURCES/SqfliteOperation.m" "$SQFLITE_SOURCES/backup/"
    
    # Copy our patch header to the sqflite_darwin directory
    cp "$FCI_BUILD_DIR/ios/sqflite_darwin_patch.h" "$SQFLITE_SOURCES/"
    
    # Add SQLite column metadata preprocessor definition to all .m files
    for file in "$SQFLITE_SOURCES/SqfliteDatabase.m" "$SQFLITE_SOURCES/SqflitePlugin.m" "$SQFLITE_SOURCES/SqfliteOperation.m"; do
      echo "#define SQLITE_ENABLE_COLUMN_METADATA 1" > "$file.new"
      echo "#import \"sqflite_darwin_patch.h\"" >> "$file.new"
      cat "$file" >> "$file.new"
      mv "$file.new" "$file"
    done
    
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
  OTHER_CFLAGS="-DSQLITE_ENABLE_COLUMN_METADATA" \
  GCC_PREPROCESSOR_DEFINITIONS="SQLITE_ENABLE_COLUMN_METADATA=1 \$(inherited)" \
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
