#!/bin/bash

# Script to fix fluttertoast plugin compatibility issues
# This script patches the fluttertoast plugin files to work with newer Flutter versions

# Find the fluttertoast plugin directory
FLUTTERTOAST_DIR=$(find ~/.pub-cache/hosted/pub.dev -name "fluttertoast-*" -type d | sort -V | tail -n 1)

if [ -z "$FLUTTERTOAST_DIR" ]; then
  echo "Fluttertoast plugin directory not found"
  exit 1
fi

echo "Fixing fluttertoast plugin in: $FLUTTERTOAST_DIR"

# Path to the kotlin files
PLUGIN_FILE="$FLUTTERTOAST_DIR/android/src/main/kotlin/io/github/ponnamkarthik/toast/fluttertoast/FlutterToastPlugin.kt"
HANDLER_FILE="$FLUTTERTOAST_DIR/android/src/main/kotlin/io/github/ponnamkarthik/toast/fluttertoast/MethodCallHandlerImpl.kt"

# Check if files exist
if [ ! -f "$PLUGIN_FILE" ] || [ ! -f "$HANDLER_FILE" ]; then
  echo "Plugin files not found"
  exit 1
fi

# Fix FlutterToastPlugin.kt
echo "Patching FlutterToastPlugin.kt..."
sed -i 's/import io.flutter.plugin.common.PluginRegistry.Registrar/import io.flutter.embedding.engine.plugins.FlutterPlugin/' "$PLUGIN_FILE"
sed -i 's/companion object {/companion object {/' "$PLUGIN_FILE"
sed -i '/fun registerWith(registrar: Registrar)/,/}/d' "$PLUGIN_FILE"

# Fix MethodCallHandlerImpl.kt
echo "Patching MethodCallHandlerImpl.kt..."
sed -i 's/import io.flutter.view.FlutterMain/import io.flutter.FlutterInjector/' "$HANDLER_FILE"
sed -i 's/FlutterMain.getLookupKeyForAsset/FlutterInjector.instance().flutterLoader().getLookupKeyForAsset/g' "$HANDLER_FILE"

echo "Fluttertoast plugin patched successfully"
