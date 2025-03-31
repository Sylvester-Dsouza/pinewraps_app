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

# Fix all privacy bundles issues
echo "Fixing privacy bundles issues..."

# Method 1: Find and remove all privacy bundles
echo "Removing all privacy bundles..."
find Pods -name "*_privacy.bundle" -o -name "*-privacy.bundle" -o -name "*Privacy.bundle" -o -name "*.bundle" | grep -i privacy | while read bundle; do
  echo "Removing bundle: $bundle"
  rm -rf "$bundle"
done

# Method 2: Modify the Pods project directly to handle all privacy bundles
echo "Modifying Pods.xcodeproj to handle all privacy bundles"
ruby -e '
require "xcodeproj"
project_path = "Pods/Pods.xcodeproj"
project = Xcodeproj::Project.open(project_path)

# Find all privacy bundle targets
privacy_targets = project.targets.select do |t| 
  t.name.end_with?("_privacy") || 
  t.name.end_with?("-privacy") || 
  t.name.end_with?("Privacy") || 
  t.name.include?("privacy")
end

puts "Found #{privacy_targets.length} privacy bundle targets"

privacy_targets.each do |target|
  puts "Configuring target: #{target.name}"
  target.build_configurations.each do |config|
    config.build_settings["EXCLUDED_SOURCE_FILE_NAMES"] = "*"
    config.build_settings["SKIP_INSTALL"] = "YES"
    config.build_settings["CODE_SIGNING_ALLOWED"] = "NO"
    config.build_settings["CODE_SIGNING_REQUIRED"] = "NO"
    config.build_settings["CODE_SIGN_IDENTITY"] = ""
    config.build_settings["EXPANDED_CODE_SIGN_IDENTITY"] = ""
    config.build_settings["ENABLE_BITCODE"] = "NO"
    config.build_settings["WRAPPER_EXTENSION"] = "bundle"
    config.build_settings["MACH_O_TYPE"] = "mh_bundle"
  end
end

project.save
puts "Modified target configurations"
' || echo "Failed to modify Pods.xcodeproj"

# Method 3: Remove all privacy bundles from build phases
echo "Removing privacy bundles from build phases"
find Pods -name "*.xcconfig" -type f | xargs grep -l "privacy.bundle" | while read config_file; do
  echo "Fixing config file: $config_file"
  sed -i.bak 's/[^ ]*privacy[^ ]*\.bundle//g' "$config_file"
done

# Method 4: Create empty Info.plist files for all privacy bundles
echo "Creating Info.plist files for all privacy bundles"
find Pods -name "*_privacy.bundle" -o -name "*-privacy.bundle" -o -name "*Privacy.bundle" -o -name "*.bundle" | grep -i privacy | while read bundle; do
  if [ ! -f "$bundle/Info.plist" ]; then
    echo "Creating Info.plist for $bundle"
    mkdir -p "$bundle"
    cat > "$bundle/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleIdentifier</key>
	<string>org.cocoapods.privacy-bundle</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>privacy</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>NSPrincipalClass</key>
	<string></string>
</dict>
</plist>
EOF
  fi
done

# Reinstall pods after modifications
echo "Reinstalling pods after modifications"
pod install

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
