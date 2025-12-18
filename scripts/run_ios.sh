#!/bin/bash

# Default Target: iPhone 15 Pro Max
DEFAULT_UUID="063845CA-47D4-4A94-9F0C-7972DA4B438C"

echo "Checking for running iOS simulators..."

# Check if any simulator is booted
# We grep for "(Booted)" and extract the UUID
BOOTED_DEVICE_UUID=$(xcrun simctl list devices | grep "(Booted)" | grep -oE '[0-9A-F-]{36}' | head -n 1)

if [ -n "$BOOTED_DEVICE_UUID" ]; then
    echo "Found running simulator with UUID: $BOOTED_DEVICE_UUID"
    TARGET_UUID="$BOOTED_DEVICE_UUID"
else
    echo "No simulator running. Booting iPhone 15 Pro Max ($DEFAULT_UUID)..."
    xcrun simctl boot "$DEFAULT_UUID"
    
    echo "Opening Simulator app..."
    open -a Simulator
    
    # Wait a moment for it to initialize (optional, but good practice)
    echo "Waiting for simulator to initialize..."
    xcrun simctl bootstatus "$DEFAULT_UUID"
    
    TARGET_UUID="$DEFAULT_UUID"
fi

echo "Running Flutter app on device: $TARGET_UUID"

# Path to local flutter SDK
FLUTTER_BIN="/Users/david/workspace/flutter/bin/flutter"

if [ -f "$FLUTTER_BIN" ]; then
    "$FLUTTER_BIN" run -d "$TARGET_UUID"
else
    echo "Error: Flutter binary not found at $FLUTTER_BIN"
    echo "Attempting to use system flutter..."
    flutter run -d "$TARGET_UUID"
fi

