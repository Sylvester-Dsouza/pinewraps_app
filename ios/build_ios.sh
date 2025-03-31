#!/usr/bin/env bash
set -e

# Set up local properties
echo "Setting up Flutter project"
cd "$FCI_BUILD_DIR"

# Skip Flutter clean and pub get as they're already run in the prebuild script
echo "Skipping Flutter clean and pub get (already run in prebuild script)"

# Patch both sqflite and sqflite_darwin plugins
echo "Patching SQLite plugins..."

# Regular sqflite plugin
echo "Patching regular sqflite plugin..."
SQFLITE_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "sqflite-2.3.0" -type d | head -n 1)

if [ -n "$SQFLITE_PATH" ]; then
  echo "Found sqflite at: $SQFLITE_PATH"
  
  # Patch the source files to add the required SQLite flags
  SQFLITE_SOURCES="$SQFLITE_PATH/ios/Classes"
  
  if [ -d "$SQFLITE_SOURCES" ]; then
    echo "Patching sqflite source files"
    
    # Create patch header file
    cat > "$SQFLITE_SOURCES/sqflite_patch.h" << 'EOF'
#ifndef SQFLITE_PATCH_H
#define SQFLITE_PATCH_H

#define SQLITE_ENABLE_COLUMN_METADATA 1

#endif /* SQFLITE_PATCH_H */
EOF
    
    # Add SQLite column metadata preprocessor definition to all .m files
    for file in "$SQFLITE_SOURCES/SqfliteDatabase.m" "$SQFLITE_SOURCES/SqflitePlugin.m" "$SQFLITE_SOURCES/SqfliteOperation.m"; do
      if [ -f "$file" ]; then
        echo "Patching $file"
        echo "#define SQLITE_ENABLE_COLUMN_METADATA 1" > "$file.new"
        echo "#import \"sqflite_patch.h\"" >> "$file.new"
        cat "$file" >> "$file.new"
        mv "$file.new" "$file"
      else
        echo "File $file not found, skipping"
      fi
    done
    
    echo "Patched sqflite source files successfully"
  else
    echo "Could not find sqflite source directory at: $SQFLITE_SOURCES"
  fi
else
  echo "Could not find sqflite plugin"
fi

# Sqflite_darwin plugin
echo "Patching sqflite_darwin plugin..."
SQFLITE_DARWIN_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "sqflite_darwin-*" -type d | head -n 1)

if [ -n "$SQFLITE_DARWIN_PATH" ]; then
  echo "Found sqflite_darwin at: $SQFLITE_DARWIN_PATH"
  
  # Patch the source files to add the required SQLite flags
  SQFLITE_DARWIN_SOURCES="$SQFLITE_DARWIN_PATH/darwin/sqflite_darwin/Sources/sqflite_darwin"
  
  if [ -d "$SQFLITE_DARWIN_SOURCES" ]; then
    echo "Patching sqflite_darwin source files"
    
    # Create patch header file
    cat > "$SQFLITE_DARWIN_SOURCES/sqflite_darwin_patch.h" << 'EOF'
#ifndef SQFLITE_DARWIN_PATCH_H
#define SQFLITE_DARWIN_PATCH_H

#define SQLITE_ENABLE_COLUMN_METADATA 1

#endif /* SQFLITE_DARWIN_PATCH_H */
EOF
    
    # Add SQLite column metadata preprocessor definition to all .m files
    for file in "$SQFLITE_DARWIN_SOURCES/SqfliteDatabase.m" "$SQFLITE_DARWIN_SOURCES/SqflitePlugin.m" "$SQFLITE_DARWIN_SOURCES/SqfliteOperation.m"; do
      if [ -f "$file" ]; then
        echo "Patching $file"
        echo "#define SQLITE_ENABLE_COLUMN_METADATA 1" > "$file.new"
        echo "#import \"sqflite_darwin_patch.h\"" >> "$file.new"
        cat "$file" >> "$file.new"
        mv "$file.new" "$file"
      else
        echo "File $file not found, skipping"
      fi
    done
    
    echo "Patched sqflite_darwin source files successfully"
  else
    echo "Could not find sqflite_darwin source directory at: $SQFLITE_DARWIN_SOURCES"
  fi
else
  echo "Could not find sqflite_darwin plugin"
fi

# Patch open_file_ios plugin
echo "Checking for open_file_ios plugin..."
OPENFILE_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "open_file_ios-*" -type d | head -n 1)

if [ -n "$OPENFILE_PATH" ]; then
  echo "Found open_file_ios at: $OPENFILE_PATH"
  
  # Check if there are any issues with the plugin
  OPENFILE_SOURCES="$OPENFILE_PATH/ios/Classes"
  
  if [ -d "$OPENFILE_SOURCES" ]; then
    echo "Checking open_file_ios source files"
    
    # Fix any issues with OpenFilePlugin.m if needed
    if [ -f "$OPENFILE_SOURCES/OpenFilePlugin.m" ]; then
      echo "Found OpenFilePlugin.m, checking for issues..."
      
      # For now, we're just making sure the file is readable
      if [ ! -r "$OPENFILE_SOURCES/OpenFilePlugin.m" ]; then
        echo "OpenFilePlugin.m is not readable, fixing permissions..."
        chmod +r "$OPENFILE_SOURCES/OpenFilePlugin.m"
      fi
    else
      echo "OpenFilePlugin.m not found"
    fi
    
    echo "Checked open_file_ios source files"
  else
    echo "Could not find open_file_ios source directory at: $OPENFILE_SOURCES"
  fi
else
  echo "Could not find open_file_ios plugin"
fi

# Check for Swift plugins that might have issues
echo "Checking Swift plugins for potential issues..."
SWIFT_PLUGINS=("webview_flutter_wkwebview" "url_launcher_ios" "sign_in_with_apple")

for plugin in "${SWIFT_PLUGINS[@]}"; do
  PLUGIN_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "${plugin}-*" -type d | head -n 1)
  
  if [ -n "$PLUGIN_PATH" ]; then
    echo "Found $plugin at: $PLUGIN_PATH"
    
    # Check if there's a Swift module
    if [ -d "$PLUGIN_PATH/ios" ]; then
      echo "Checking $plugin iOS directory"
      
      # Make sure all Swift files have the correct permissions
      find "$PLUGIN_PATH/ios" -name "*.swift" -exec chmod +r {} \;
      
      echo "Fixed permissions for $plugin Swift files"
    fi
  else
    echo "Could not find $plugin plugin"
  fi
done

# Prepare iOS build environment
echo "Preparing iOS build environment"
cd ios

# Clean Pods to ensure fresh installation
echo "Cleaning Pods"
rm -rf Pods
rm -f Podfile.lock

# Install pods with special flags for sqflite and sqflite_darwin
echo "Installing Pods"
pod install --repo-update

# Check Swift version
echo "Swift version:"
xcrun swift --version

# Ensure Firebase frameworks are properly linked
echo "Checking Firebase frameworks..."
if [ -d "Pods/FirebaseCore" ]; then
  echo "FirebaseCore found in Pods"
else
  echo "WARNING: FirebaseCore not found in Pods"
fi

# Check for Swift plugins in Pods
echo "Checking Swift plugins in Pods..."
for plugin in "${SWIFT_PLUGINS[@]}"; do
  if [ -d "Pods/$plugin" ]; then
    echo "$plugin found in Pods"
  else
    echo "WARNING: $plugin not found in Pods"
  fi
done

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
  SWIFT_VERSION=5.0 \
  SWIFT_OBJC_BRIDGING_HEADER="Runner/Runner-Bridging-Header.h" \
  ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=YES \
  ENABLE_BITCODE=NO \
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
