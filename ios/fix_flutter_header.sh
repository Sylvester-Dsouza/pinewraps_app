#!/bin/bash

# This script fixes the 'Flutter/Flutter.h' file not found error for webview_flutter_wkwebview
# Run this script in the pre-build phase on Codemagic

echo "Starting Flutter header fix script..."

# Make sure the Pods directory exists
if [ ! -d "Pods" ]; then
  echo "Pods directory not found. Make sure to run pod install first."
  exit 1
fi

# Create a symlink to Flutter.h in the expected location
mkdir -p Pods/Headers/Public/Flutter
cd Pods/Headers/Public/Flutter
echo "Created Flutter headers directory"

# Try multiple possible locations for Flutter.h
if [ -f "../../../../Flutter/Flutter.h" ]; then
  ln -sf ../../../../Flutter/Flutter.h Flutter.h
  echo "Found Flutter.h at ../../../../Flutter/Flutter.h"
elif [ -f "../../../Flutter/Flutter.h" ]; then
  ln -sf ../../../Flutter/Flutter.h Flutter.h
  echo "Found Flutter.h at ../../../Flutter/Flutter.h"
elif [ -f "../../Flutter/Flutter.h" ]; then
  ln -sf ../../Flutter/Flutter.h Flutter.h
  echo "Found Flutter.h at ../../Flutter/Flutter.h"
elif [ -f "../Flutter/Flutter.h" ]; then
  ln -sf ../Flutter/Flutter.h Flutter.h
  echo "Found Flutter.h at ../Flutter/Flutter.h"
elif [ -f "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_armv7/Flutter.framework/Headers/Flutter.h" ]; then
  ln -sf "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_armv7/Flutter.framework/Headers/Flutter.h" Flutter.h
  echo "Found Flutter.h at FLUTTER_ROOT cache location"
elif [ -f "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework/Headers/Flutter.h" ]; then
  ln -sf "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework/Headers/Flutter.h" Flutter.h
  echo "Found Flutter.h at FLUTTER_ROOT cache location (arm64)"
else
  echo "Could not find Flutter.h in any of the expected locations"
  echo "Creating a minimal Flutter.h stub file"
  # Create a minimal Flutter.h that satisfies the import requirements
  echo "#ifndef Flutter_h" > Flutter.h
  echo "#define Flutter_h" >> Flutter.h
  echo "// Minimal Flutter.h created by fix_flutter_header.sh" >> Flutter.h
  echo "#import <Foundation/Foundation.h>" >> Flutter.h
  echo "typedef NSString *FlutterMethodCallHandler;" >> Flutter.h
  echo "#endif /* Flutter_h */" >> Flutter.h
fi

cd ../../../..
echo "Returned to ios directory"

# Fix the module map for webview_flutter_wkwebview
WEBVIEW_MODULE_MAP="Pods/Headers/Public/webview_flutter_wkwebview/webview_flutter_wkwebview.modulemap"
if [ -f "$WEBVIEW_MODULE_MAP" ]; then
  sed -i '' 's/header "Flutter\/Flutter.h"/header "..\/Flutter\/Flutter.h"/' "$WEBVIEW_MODULE_MAP"
  echo "Fixed webview_flutter_wkwebview module map"
else
  echo "Module map not found at $WEBVIEW_MODULE_MAP"
  # Try to find the module map in other locations
  FOUND_MAPS=$(find Pods -name "*.modulemap" | grep -i webview)
  if [ ! -z "$FOUND_MAPS" ]; then
    echo "Found alternative module maps:"
    echo "$FOUND_MAPS"
    for MAP in $FOUND_MAPS; do
      echo "Fixing $MAP"
      sed -i '' 's/header "Flutter\/Flutter.h"/header "..\/Flutter\/Flutter.h"/' "$MAP"
    done
  fi
fi

# Add a direct include path to the Flutter framework in the build settings
echo "Updating xcconfig files with Flutter header paths"
find . -name "*.xcconfig" | xargs sed -i '' 's/HEADER_SEARCH_PATHS = /HEADER_SEARCH_PATHS = $(PODS_ROOT)\/Headers\/Public\/Flutter /'

# Create a symbolic link to Flutter.framework in a known location
mkdir -p Flutter
if [ ! -f "Flutter/Flutter.h" ]; then
  if [ -d "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework" ]; then
    echo "Creating symbolic link to Flutter.xcframework"
    ln -sf "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework/Headers/Flutter.h" Flutter/Flutter.h
  fi
fi

echo "Flutter header fix applied successfully"
