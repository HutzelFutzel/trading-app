#!/bin/bash

echo "Checking for connected physical iPhone..."

# Path to local flutter SDK
FLUTTER_BIN="/Users/david/workspace/flutter/bin/flutter"

# Check if flutter exists
if [ ! -f "$FLUTTER_BIN" ]; then
    echo "Error: Flutter binary not found at $FLUTTER_BIN"
    exit 1
fi

# Find a connected physical device (not a simulator)
# filtering for 'ios' platform and excluding 'simulator'
DEVICE_ID=$("$FLUTTER_BIN" devices | grep "ios" | grep -v "simulator" | head -n 1 | awk -F '•' '{print $2}' | xargs)

if [ -z "$DEVICE_ID" ]; then
    echo "No physical iPhone found. Please connect your device and ensure it is unlocked."
    echo "Available devices:"
    "$FLUTTER_BIN" devices
    exit 1
fi

echo "Found physical iPhone with ID: $DEVICE_ID"
echo "Running app on device (Release mode)..."

# Run in release mode for better performance on physical device
"$FLUTTER_BIN" run -d "$DEVICE_ID" --release

