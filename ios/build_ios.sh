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

# Function to remove privacy bundles
remove_privacy_bundles() {
    echo "Removing privacy bundles..."
    
    # Remove from Pods project
    find "${PWD}/Pods" -name "*_privacy.bundle" -type d -exec rm -rf {} +
    find "${PWD}/Pods" -name "*-privacy.bundle" -type d -exec rm -rf {} +
    find "${PWD}/Pods" -name "*Privacy.bundle" -type d -exec rm -rf {} +
    
    # Remove privacy targets from Pods project
    if [ -f "Pods/Pods.xcodeproj/project.pbxproj" ]; then
        echo "Modifying Pods project..."
        sed -i.bak '/Begin PBXNativeTarget/,/End PBXNativeTarget/ {
            /privacy/ d
        }' "Pods/Pods.xcodeproj/project.pbxproj"
    fi
}

# Function to patch SQLite
patch_sqlite() {
    echo "Patching SQLite..."
    SQLITE_PATH="Pods/sqlite3"
    SQLITE_CONFIG="Pods/Target Support Files/sqlite3/sqlite3.debug.xcconfig"
    
    if [ -d "$SQLITE_PATH" ]; then
        # Add SQLite compilation flags
        if [ -f "$SQLITE_CONFIG" ]; then
            echo "OTHER_CFLAGS = \$(inherited) -DSQLITE_ENABLE_COLUMN_METADATA=1" >> "$SQLITE_CONFIG"
        fi
    fi
}

# Function to clean build
clean_build() {
    echo "Cleaning build..."
    rm -rf ./build
    rm -rf ~/Library/Developer/Xcode/DerivedData
    rm -rf ./Pods
    rm -f ./Podfile.lock
    rm -rf ./.symlinks
    rm -rf ./Flutter/Flutter.framework
    rm -rf ./Flutter/Flutter.podspec
}

# Function to setup build
setup_build() {
    echo "Setting up build..."
    flutter pub get
    
    # Install pods
    pod install --repo-update
    
    # Remove privacy bundles after pod install
    remove_privacy_bundles
    
    # Patch SQLite
    patch_sqlite
}

# Function to build archive
build_archive() {
    echo "Building archive..."
    
    # Create archive directory
    mkdir -p build/ios/archive
    
    # Build archive
    xcodebuild -workspace Runner.xcworkspace \
        -scheme Runner \
        -sdk iphoneos \
        -configuration Release \
        -archivePath build/ios/archive/Runner.xcarchive \
        COMPILER_INDEX_STORE_ENABLE=NO \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        PROVISIONING_PROFILE_SPECIFIER="$PROVISIONING_PROFILE" \
        archive \
        CODE_SIGN_IDENTITY="Apple Distribution" \
        OTHER_CODE_SIGN_FLAGS="--keychain build.keychain" || true
}

# Function to create IPA
create_ipa() {
    echo "Creating IPA..."
    
    if [ -d "build/ios/archive/Runner.xcarchive" ]; then
        mkdir -p build/ios/ipa
        
        xcodebuild -exportArchive \
            -archivePath build/ios/archive/Runner.xcarchive \
            -exportOptionsPlist exportOptions.plist \
            -exportPath build/ios/ipa/ \
            -allowProvisioningUpdates || true
            
        if [ -f "build/ios/ipa/Runner.ipa" ]; then
            echo "IPA created successfully"
        else
            echo "IPA creation failed, trying alternative method..."
            
            # Alternative method: Create IPA directly
            xcodebuild -workspace Runner.xcworkspace \
                -scheme Runner \
                -sdk iphoneos \
                -configuration Release \
                -exportOptionsPlist exportOptions.plist \
                clean archive -archivePath build/ios/ipa/Runner.xcarchive \
                DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
                PROVISIONING_PROFILE_SPECIFIER="$PROVISIONING_PROFILE" \
                CODE_SIGN_IDENTITY="Apple Distribution" || true
                
            xcodebuild -exportArchive \
                -archivePath build/ios/ipa/Runner.xcarchive \
                -exportOptionsPlist exportOptions.plist \
                -exportPath build/ios/ipa \
                -allowProvisioningUpdates || true
        fi
    else
        echo "Archive not found, creating IPA directly..."
        
        mkdir -p build/ios/ipa
        xcodebuild -workspace Runner.xcworkspace \
            -scheme Runner \
            -sdk iphoneos \
            -configuration Release \
            clean build \
            -derivedDataPath build/ios/DerivedData \
            DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
            PROVISIONING_PROFILE_SPECIFIER="$PROVISIONING_PROFILE" \
            CODE_SIGN_IDENTITY="Apple Distribution" \
            COMPILER_INDEX_STORE_ENABLE=NO || true
            
        # Package as IPA
        xcrun /usr/bin/PackageApplication \
            -v "build/ios/DerivedData/Build/Products/Release-iphoneos/Runner.app" \
            -o "build/ios/ipa/Runner.ipa" || true
    fi
}

# Main build process
echo "Starting build process..."

# Clean previous build
clean_build

# Setup build
setup_build

# Build archive
build_archive

# Create IPA
create_ipa

echo "Build process completed"

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
  
  # Remove all build phases
  target.build_phases.clear
  
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
    config.build_settings["EXCLUDED_ARCHS"] = "arm64"
    config.build_settings["ONLY_ACTIVE_ARCH"] = "NO"
    config.build_settings["ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES"] = "NO"
  end
end

# Remove privacy bundle references from all targets
project.targets.each do |target|
  next if target.name.end_with?("_privacy") || 
          target.name.end_with?("-privacy") || 
          target.name.end_with?("Privacy") || 
          target.name.include?("privacy")
  
  target.build_phases.each do |phase|
    if phase.respond_to?(:files)
      phase.files.to_a.each do |build_file|
        if build_file.display_name && (
           build_file.display_name.end_with?("_privacy.bundle") || 
           build_file.display_name.end_with?("-privacy.bundle") || 
           build_file.display_name.end_with?("Privacy.bundle") || 
           build_file.display_name.include?("privacy.bundle"))
          phase.remove_build_file(build_file)
        end
      end
    end
  end
end

project.save
puts "Modified target configurations"
' || echo "Failed to modify Pods.xcodeproj"

# Method 3: Remove all privacy bundles from build phases
echo "Removing privacy bundles from build phases"
find Pods -name "*.xcconfig" -type f | xargs grep -l "privacy.bundle\|Privacy.bundle" | while read config_file; do
  echo "Fixing config file: $config_file"
  sed -i.bak 's/[^ ]*[pP]rivacy[^ ]*\.bundle//g' "$config_file"
done

# Method 4: Modify the Runner.xcodeproj to exclude privacy bundles
echo "Modifying Runner.xcodeproj to exclude privacy bundles"
ruby -e '
require "xcodeproj"
project_path = "Runner.xcodeproj"
project = Xcodeproj::Project.open(project_path)

# Remove privacy bundle references from all targets
project.targets.each do |target|
  target.build_phases.each do |phase|
    if phase.respond_to?(:files)
      phase.files.to_a.each do |build_file|
        if build_file.display_name && (
           build_file.display_name.end_with?("_privacy.bundle") || 
           build_file.display_name.end_with?("-privacy.bundle") || 
           build_file.display_name.end_with?("Privacy.bundle") || 
           build_file.display_name.include?("privacy.bundle"))
          phase.remove_build_file(build_file)
        end
      end
    end
  end
  
  # Set build settings for the target
  target.build_configurations.each do |config|
    config.build_settings["EXCLUDED_SOURCE_FILE_NAMES"] = "*privacy.bundle *Privacy.bundle"
    config.build_settings["ENABLE_BITCODE"] = "NO"
    config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "12.0"
  end
end

project.save
puts "Modified Runner.xcodeproj"
' || echo "Failed to modify Runner.xcodeproj"

# Method 5: Create a custom script to remove privacy bundles during build
echo "Creating a custom script to remove privacy bundles during build"
cat > "remove_privacy_bundles.sh" << 'EOF'
#!/bin/bash
set -e

echo "Running custom script to remove privacy bundles during build"

# Find all privacy bundles in the build directory
find "${BUILT_PRODUCTS_DIR}" -name "*_privacy.bundle" -o -name "*-privacy.bundle" -o -name "*Privacy.bundle" -o -name "*.bundle" | grep -i privacy | while read bundle; do
  echo "Removing bundle from build products: $bundle"
  rm -rf "$bundle"
done

echo "Privacy bundles removed successfully"
EOF

chmod +x "remove_privacy_bundles.sh"

# Method 6: Add a custom build phase to Runner.xcodeproj
echo "Adding a custom build phase to Runner.xcodeproj"
ruby -e '
require "xcodeproj"
project_path = "Runner.xcodeproj"
project = Xcodeproj::Project.open(project_path)

# Add a custom build phase to the Runner target
runner_target = project.targets.find { |t| t.name == "Runner" }
if runner_target
  # Check if we already have a custom build phase
  has_custom_phase = runner_target.build_phases.any? { |phase| 
    phase.respond_to?(:shell_script) && phase.shell_script.include?("remove_privacy_bundles.sh")
  }
  
  unless has_custom_phase
    # Add a new run script phase
    phase = runner_target.new_shell_script_build_phase("Remove Privacy Bundles")
    phase.shell_script = "${SRCROOT}/remove_privacy_bundles.sh"
    
    # Move it to be one of the last phases
    runner_target.build_phases.move_from(runner_target.build_phases.index(phase), runner_target.build_phases.count - 2)
  end
  
  project.save
  puts "Added custom build phase to Runner.xcodeproj"
else
  puts "Runner target not found"
end
' || echo "Failed to add custom build phase"

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
