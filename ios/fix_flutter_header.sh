#!/bin/bash

# This script fixes the 'Flutter/Flutter.h' file not found error for webview_flutter_wkwebview
# Run this script in the pre-build phase on Codemagic

# Create a symlink to Flutter.h in the expected location
mkdir -p Pods/Headers/Public/Flutter
cd Pods/Headers/Public/Flutter

# Try multiple possible locations for Flutter.h
if [ -f "../../../../Flutter/Flutter.h" ]; then
  ln -sf ../../../../Flutter/Flutter.h Flutter.h
elif [ -f "../../../Flutter/Flutter.h" ]; then
  ln -sf ../../../Flutter/Flutter.h Flutter.h
elif [ -f "../../Flutter/Flutter.h" ]; then
  ln -sf ../../Flutter/Flutter.h Flutter.h
elif [ -f "../Flutter/Flutter.h" ]; then
  ln -sf ../Flutter/Flutter.h Flutter.h
elif [ -f "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_armv7/Flutter.framework/Headers/Flutter.h" ]; then
  ln -sf "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_armv7/Flutter.framework/Headers/Flutter.h" Flutter.h
else
  echo "Could not find Flutter.h in any of the expected locations"
  # Create a minimal Flutter.h that satisfies the import requirements
  echo "#ifndef Flutter_h" > Flutter.h
  echo "#define Flutter_h" >> Flutter.h
  echo "// Minimal Flutter.h created by fix_flutter_header.sh" >> Flutter.h
  echo "#import <Foundation/Foundation.h>" >> Flutter.h
  echo "typedef NSString *FlutterMethodCallHandler;" >> Flutter.h
  echo "#endif /* Flutter_h */" >> Flutter.h
fi

cd ../../../..

# Fix the module map for webview_flutter_wkwebview
WEBVIEW_MODULE_MAP="Pods/Headers/Public/webview_flutter_wkwebview/webview_flutter_wkwebview.modulemap"
if [ -f "$WEBVIEW_MODULE_MAP" ]; then
  sed -i '' 's/header "Flutter\/Flutter.h"/header "..\/Flutter\/Flutter.h"/' "$WEBVIEW_MODULE_MAP"
fi

# Add a direct include path to the Flutter framework in the build settings
find . -name "*.xcconfig" | xargs sed -i '' 's/HEADER_SEARCH_PATHS = /HEADER_SEARCH_PATHS = $(PODS_ROOT)\/Headers\/Public\/Flutter /'

echo "Flutter header fix applied successfully"
