#!/bin/bash

echo "Starting Flutter Web App..."

# Path to local flutter SDK
FLUTTER_BIN="/Users/david/workspace/flutter/bin/flutter"

if [ ! -f "$FLUTTER_BIN" ]; then
    echo "Error: Flutter binary not found at $FLUTTER_BIN"
    exit 1
fi

# Run specifically on Chrome
echo "Launching Chrome..."
"$FLUTTER_BIN" run -d chrome

