#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# --- Configuration ---
PUBSPEC_FILE="pubspec.yaml"
# Ensure we are in the flutter root
if [ ! -f "$PUBSPEC_FILE" ]; then
    echo "Error: $PUBSPEC_FILE not found. Please run this script from the Flutter project root (trading-app/)."
    exit 1
fi

echo "--- 🚀 Starting iOS Deployment ---"

# 1. Increment Version Number
echo "--- 🔢 Incrementing Version Number ---"
# Read current version
CURRENT_VERSION=$(grep "^version:" $PUBSPEC_FILE | awk '{print $2}')
echo "Current Version: $CURRENT_VERSION"

# Split into version and build number
VERSION_NAME=$(echo $CURRENT_VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

# Increment build number
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="$VERSION_NAME+$NEW_BUILD_NUMBER"

# Update pubspec.yaml
# Use sed slightly differently for macOS vs Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^version: .*/version: $NEW_VERSION/" $PUBSPEC_FILE
else
    sed -i "s/^version: .*/version: $NEW_VERSION/" $PUBSPEC_FILE
fi

echo "Updated Version: $NEW_VERSION"

# 2. Build iOS Archive
echo "--- 🔨 Building iOS Archive ---"
/Users/david/workspace/flutter/bin/flutter build ipa --export-options-plist=ios/Runner/ExportOptions.plist

echo "--- ✅ Build Successful ---"
echo "--- 📤 Uploading to App Store Connect... (This may take a while) ---"

# 3. Upload to App Store
# Note: This requires 'xcrun altool' or 'xcrun notarytool' and app-specific password authentication
# For modern Xcode 13+, 'flutter build ipa' often produces an .ipa that you can upload via 'xcrun altool'
# or use Transporter.
#
# To fully automate upload, you need to:
# 1. Create an API Key in App Store Connect (Users and Access > Keys)
# 2. Configure a private_keys directory or environment variables
#
# Alternatively, simpler method using username/password (app-specific password):
# xcrun altool --upload-app --type ios --file build/ios/ipa/trading_app.ipa --username "YOUR_APPLE_ID_EMAIL" --password "YOUR-APP-SPECIFIC-PASSWORD"
#
# For now, we will open the output folder so you can drag-and-drop to Transporter app (which is very reliable)
# or you can uncomment the altool line below if you configure it.

# Find the IPA file (ignoring the exact name)
IPA_PATH=$(find build/ios/ipa -name "*.ipa" | head -n 1)

if [ -f "$IPA_PATH" ]; then
    echo "IPA created at: $IPA_PATH"
    
    # Open Transporter app with the file (if possible) or just open the app
    if open -a Transporter "$IPA_PATH"; then
        echo "Opened Transporter with IPA file."
    else
        echo "Transporter app not found or could not open file. Opening folder instead."
        open build/ios/ipa/
    fi
    
    echo "PLEASE UPLOAD '$IPA_PATH' USING TRANSPORTER OR XCODE."
    echo "To fully automate upload, edit this script with your App Store Connect credentials."
else
    echo "Error: IPA file not found in build/ios/ipa/"
    exit 1
fi

echo "--- 🎉 Done! Version $NEW_VERSION ready for upload. ---"

