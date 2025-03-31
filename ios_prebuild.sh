#!/bin/bash
set -e

echo "Running iOS prebuild script..."

# Uncomment sign_in_with_apple for iOS build
sed -i '' 's/^  # sign_in_with_apple: \^5.0.0$/  sign_in_with_apple: \^5.0.0/' pubspec.yaml

# We need to run flutter pub get to generate the Flutter/Generated.xcconfig file
echo "Running flutter pub get to generate necessary config files..."
flutter pub get

# Fix iOS build issues
echo "Fixing iOS build environment..."

# Create patch header file
echo "Creating SQLite patch header file..."
cat > "ios/sqflite_patch.h" << 'EOF'
#ifndef SQFLITE_PATCH_H
#define SQFLITE_PATCH_H

#define SQLITE_ENABLE_COLUMN_METADATA 1

#endif /* SQFLITE_PATCH_H */
EOF

# Patch regular sqflite plugin
echo "Patching regular sqflite plugin..."
SQFLITE_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "sqflite-2.3.0" -type d | head -n 1)

if [ -n "$SQFLITE_PATH" ]; then
  echo "Found sqflite at: $SQFLITE_PATH"
  
  # Patch the source files to add the required SQLite flags
  SQFLITE_SOURCES="$SQFLITE_PATH/ios/Classes"
  
  if [ -d "$SQFLITE_SOURCES" ]; then
    echo "Patching sqflite source files"
    
    # Copy our patch header to the sqflite directory
    cp "ios/sqflite_patch.h" "$SQFLITE_SOURCES/"
    
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

# Patch open_file_ios plugin to fix potential issues
echo "Checking for open_file_ios plugin..."
OPENFILE_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "open_file_ios-*" -type d | head -n 1)

if [ -n "$OPENFILE_PATH" ]; then
  echo "Found open_file_ios at: $OPENFILE_PATH"
  
  # Check if there are any issues with the plugin
  OPENFILE_SOURCES="$OPENFILE_PATH/ios/Classes"
  
  if [ -d "$OPENFILE_SOURCES" ]; then
    echo "Checking open_file_ios source files"
    
    # Add any necessary fixes for open_file_ios here
    # For now, we're just checking if the files exist
    
    echo "Checked open_file_ios source files"
  else
    echo "Could not find open_file_ios source directory at: $OPENFILE_SOURCES"
  fi
else
  echo "Could not find open_file_ios plugin"
fi

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

# Patch sqflite_darwin if needed
echo "Checking for sqflite_darwin plugin..."
SQFLITE_DARWIN_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "sqflite_darwin-*" -type d | head -n 1)

if [ -n "$SQFLITE_DARWIN_PATH" ]; then
  echo "Found sqflite_darwin at: $SQFLITE_DARWIN_PATH"
  
  # Patch the source files to add the required SQLite flags
  SQFLITE_DARWIN_SOURCES="$SQFLITE_DARWIN_PATH/darwin/sqflite_darwin/Sources/sqflite_darwin"
  
  if [ -d "$SQFLITE_DARWIN_SOURCES" ]; then
    echo "Patching sqflite_darwin source files"
    
    # Create patch header file
    echo "#ifndef SQFLITE_DARWIN_PATCH_H" > "$SQFLITE_DARWIN_SOURCES/sqflite_darwin_patch.h"
    echo "#define SQFLITE_DARWIN_PATCH_H" >> "$SQFLITE_DARWIN_SOURCES/sqflite_darwin_patch.h"
    echo "" >> "$SQFLITE_DARWIN_SOURCES/sqflite_darwin_patch.h"
    echo "#define SQLITE_ENABLE_COLUMN_METADATA 1" >> "$SQFLITE_DARWIN_SOURCES/sqflite_darwin_patch.h"
    echo "" >> "$SQFLITE_DARWIN_SOURCES/sqflite_darwin_patch.h"
    echo "#endif /* SQFLITE_DARWIN_PATCH_H */" >> "$SQFLITE_DARWIN_SOURCES/sqflite_darwin_patch.h"
    
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

# Return to the project root
cd ..

echo "iOS prebuild script completed successfully"
