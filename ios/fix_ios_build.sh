#!/bin/bash
# Script to fix iOS build issues including dependency resolution and privacy bundles

echo "Starting iOS build fix script..."

# Go to project root
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

echo "Project root: $PROJECT_ROOT"

# Fix pubspec.lock
echo "Fixing pubspec dependencies..."
if [ -f pubspec.lock ]; then
  echo "Backing up pubspec.lock"
  cp pubspec.lock pubspec.lock.backup
  rm pubspec.lock
fi

# Get dependencies with fallback mechanisms
echo "Getting Flutter dependencies..."
flutter pub get -v || {
  echo "Flutter pub get failed, trying with --no-precompile"
  flutter pub get --no-precompile || {
    echo "Still failing, trying with downgrade"
    flutter pub downgrade || {
      echo "All attempts to get dependencies failed"
      # Restore backup if all attempts fail
      if [ -f pubspec.lock.backup ]; then
        echo "Restoring pubspec.lock from backup"
        cp pubspec.lock.backup pubspec.lock
      fi
    }
  }
}

# Clean iOS build artifacts
echo "Cleaning iOS build artifacts..."
cd ios
rm -rf Pods
rm -rf Podfile.lock
rm -rf .symlinks
rm -rf Flutter/Flutter.framework
rm -rf Flutter/Flutter.podspec
rm -rf Flutter/App.framework
rm -rf build

# Ensure Generated.xcconfig exists
echo "Ensuring Generated.xcconfig exists..."
mkdir -p Flutter
if [ ! -f Flutter/Generated.xcconfig ]; then
  echo "Creating Generated.xcconfig..."
  FLUTTER_ROOT_PATH=$(which flutter | xargs dirname | xargs dirname)
  echo "Flutter root path: $FLUTTER_ROOT_PATH"
  
  cat > Flutter/Generated.xcconfig << EOF
FLUTTER_ROOT=$FLUTTER_ROOT_PATH
FLUTTER_APPLICATION_PATH=$PROJECT_ROOT
COCOAPODS_PARALLEL_CODE_SIGN=true
FLUTTER_TARGET=lib/main.dart
FLUTTER_BUILD_DIR=build
FLUTTER_BUILD_NAME=1.0.0
FLUTTER_BUILD_NUMBER=1
EXCLUDED_ARCHS[sdk=iphonesimulator*]=i386 arm64
DART_OBFUSCATION=false
TRACK_WIDGET_CREATION=true
TREE_SHAKE_ICONS=false
PACKAGE_CONFIG=$PROJECT_ROOT/.dart_tool/package_config.json
EOF
fi

# Remove privacy bundles
echo "Removing privacy bundles..."
find . -name "*_privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true
find . -name "*-privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true
find . -name "*Privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true

# Fix Swift plugin permissions
echo "Fixing Swift plugin permissions..."
PLUGINS_DIR="$HOME/.pub-cache/hosted/pub.dev"

# Fix webview_flutter_wkwebview
WEBVIEW_PATH=$(find $PLUGINS_DIR -name "webview_flutter_wkwebview-*" -type d 2>/dev/null | head -n 1)
if [ -n "$WEBVIEW_PATH" ]; then
  echo "Found webview_flutter_wkwebview at: $WEBVIEW_PATH"
  WEBVIEW_IOS_DIR="$WEBVIEW_PATH/ios"
  if [ -d "$WEBVIEW_IOS_DIR" ]; then
    echo "Fixing permissions for webview_flutter_wkwebview Swift files"
    find "$WEBVIEW_IOS_DIR" -name "*.swift" -exec chmod 644 {} \; 2>/dev/null || true
  fi
else
  echo "Could not find webview_flutter_wkwebview plugin"
fi

# Fix url_launcher_ios
URL_LAUNCHER_PATH=$(find $PLUGINS_DIR -name "url_launcher_ios-*" -type d 2>/dev/null | head -n 1)
if [ -n "$URL_LAUNCHER_PATH" ]; then
  echo "Found url_launcher_ios at: $URL_LAUNCHER_PATH"
  URL_LAUNCHER_IOS_DIR="$URL_LAUNCHER_PATH/ios"
  if [ -d "$URL_LAUNCHER_IOS_DIR" ]; then
    echo "Fixing permissions for url_launcher_ios Swift files"
    find "$URL_LAUNCHER_IOS_DIR" -name "*.swift" -exec chmod 644 {} \; 2>/dev/null || true
  fi
else
  echo "Could not find url_launcher_ios plugin"
fi

# Fix sign_in_with_apple
SIGN_IN_APPLE_PATH=$(find $PLUGINS_DIR -name "sign_in_with_apple-*" -type d 2>/dev/null | head -n 1)
if [ -n "$SIGN_IN_APPLE_PATH" ]; then
  echo "Found sign_in_with_apple at: $SIGN_IN_APPLE_PATH"
  SIGN_IN_APPLE_IOS_DIR="$SIGN_IN_APPLE_PATH/ios"
  if [ -d "$SIGN_IN_APPLE_IOS_DIR" ]; then
    echo "Fixing permissions for sign_in_with_apple Swift files"
    find "$SIGN_IN_APPLE_IOS_DIR" -name "*.swift" -exec chmod 644 {} \; 2>/dev/null || true
  fi
else
  echo "Could not find sign_in_with_apple plugin"
fi

# Install pods with fallback mechanisms
echo "Installing pods..."
pod repo update
pod install --repo-update || {
  echo "Pod install failed, trying with --verbose"
  pod install --verbose --repo-update || {
    echo "Still failing, trying with basic configuration"
    echo "Creating a simplified temporary Podfile"
    cp Podfile Podfile.backup
    cat > Podfile << EOF
platform :ios, '12.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), '$(which flutter | xargs dirname | xargs dirname)')

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks! :linkage => :static
  use_modular_headers!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end
EOF
    pod install --verbose --repo-update || {
      echo "All pod install attempts failed"
      # Restore original Podfile
      mv Podfile.backup Podfile
      exit 1
    }
    # Restore original Podfile
    mv Podfile.backup Podfile
  }
}

# Remove privacy bundles after pod install
echo "Removing privacy bundles after pod install..."
find . -name "*_privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true
find . -name "*-privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true
find . -name "*Privacy.bundle" -type d -exec rm -rf {} \; 2>/dev/null || true

echo "iOS build fix script completed!"
echo "You can now try building your iOS app with: flutter build ios --release"
