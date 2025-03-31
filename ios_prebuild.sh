#!/bin/bash
set -e

echo "Running iOS prebuild script..."

# Uncomment sign_in_with_apple for iOS build
sed -i '' 's/^  # sign_in_with_apple: \^5.0.0$/  sign_in_with_apple: \^5.0.0/' pubspec.yaml

# Skip Flutter clean and pub get as they're already run in the main build script
echo "Skipping Flutter clean and pub get (already run in main script)"

# Fix iOS build issues
echo "Fixing iOS build environment..."

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
SQFLITE_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "sqflite_darwin-*" -type d | head -n 1)

if [ -n "$SQFLITE_PATH" ]; then
  echo "Found sqflite_darwin at: $SQFLITE_PATH"
  
  # Patch the source files to add the required SQLite flags
  SQFLITE_SOURCES="$SQFLITE_PATH/darwin/sqflite_darwin/Sources/sqflite_darwin"
  
  if [ -d "$SQFLITE_SOURCES" ]; then
    echo "Patching sqflite_darwin source files"
    
    # Create patch header file
    echo "#ifndef SQFLITE_DARWIN_PATCH_H" > "$SQFLITE_SOURCES/sqflite_darwin_patch.h"
    echo "#define SQFLITE_DARWIN_PATCH_H" >> "$SQFLITE_SOURCES/sqflite_darwin_patch.h"
    echo "" >> "$SQFLITE_SOURCES/sqflite_darwin_patch.h"
    echo "#define SQLITE_ENABLE_COLUMN_METADATA 1" >> "$SQFLITE_SOURCES/sqflite_darwin_patch.h"
    echo "" >> "$SQFLITE_SOURCES/sqflite_darwin_patch.h"
    echo "#endif /* SQFLITE_DARWIN_PATCH_H */" >> "$SQFLITE_SOURCES/sqflite_darwin_patch.h"
    
    # Add SQLite column metadata preprocessor definition to all .m files
    for file in "$SQFLITE_SOURCES/SqfliteDatabase.m" "$SQFLITE_SOURCES/SqflitePlugin.m" "$SQFLITE_SOURCES/SqfliteOperation.m"; do
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
    echo "Could not find sqflite_darwin source directory at: $SQFLITE_SOURCES"
  fi
else
  echo "Could not find sqflite_darwin plugin"
fi

# Return to the project root
cd ..

echo "iOS prebuild script completed successfully"
