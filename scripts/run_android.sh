#!/bin/bash

# Configuration
EMULATOR_NAME="Medium_Phone_API_35"
EMULATOR_DEVICE="pixel_6_pro" # Closest available generic definition usually available
EMULATOR_API="android-35" # Latest stable API
EMULATOR_ABI="google_apis;arm64-v8a" # For Apple Silicon Macs

echo "Checking for existing emulator: $EMULATOR_NAME..."

# Check if emulator exists
# We drop -q to avoid broken pipe issues with flutter stdout
if ! ../flutter/bin/flutter emulators | grep "$EMULATOR_NAME" > /dev/null; then
    echo "Creating new emulator: $EMULATOR_NAME..."
    
    # We need avdmanager which comes with Android SDK cmdline-tools
    # Assuming standard macOS Android SDK location or accessible via path
    # If not in path, we try to locate it.
    ANDROID_HOME=${ANDROID_HOME:-$HOME/Library/Android/sdk}
    AVDMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
    
    if [ ! -f "$AVDMANAGER" ]; then
        # Try finding it elsewhere or warn user
        echo "⚠️  avdmanager not found at standard location. Using 'flutter emulators --create' generic..."
        ../flutter/bin/flutter emulators --create --name "$EMULATOR_NAME"
    else
        # Download system image if needed (this might require user interaction for licenses, so mostly best effort)
        # echo "y" | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "system-images;${EMULATOR_API};${EMULATOR_ABI}"
        
        # Create specific AVD
        echo "no" | "$AVDMANAGER" create avd -n "$EMULATOR_NAME" -k "system-images;${EMULATOR_API};${EMULATOR_ABI}" -d "$EMULATOR_DEVICE" --force
    fi
fi

echo "Launching emulator..."
../flutter/bin/flutter emulators --launch "$EMULATOR_NAME" 2>/dev/null &

# Wait for emulator to boot
echo "Waiting for emulator to boot..."
# Simple wait loop checking for device connectivity
count=0
# We check if the emulator is listed in 'flutter devices' using machine output for reliability
while ! ../flutter/bin/flutter devices --machine | jq -e '.[] | select(.id | startswith("emulator-"))' > /dev/null && [ $count -lt 60 ]; do
    sleep 2
    count=$((count+1))
    echo -n "."
done
echo ""

# Get the first emulator ID found
EMULATOR_ID=$(../flutter/bin/flutter devices --machine | jq -r '.[] | select(.id | startswith("emulator-")) | .id' | head -n 1)

if [ ! -z "$EMULATOR_ID" ]; then
    echo "Emulator started ($EMULATOR_ID). Running app..."
    ../flutter/bin/flutter run -d "$EMULATOR_ID"
else
    # Fallback to whatever emulator started (sometimes ID differs from name in list)
    echo "Target specific emulator ID not found, trying any connected emulator..."
    ../flutter/bin/flutter run
fi
