#!/bin/bash

# Boot the iPhone 15 Pro Max simulator
echo "Booting iPhone 15 Pro Max..."
xcrun simctl boot "76FF6D93-BDB7-454F-A5B7-20963BF704BA"

# Open the Simulator app
open -a Simulator

# Open the iOS project in Xcode for signing configuration
echo "Opening iOS project in Xcode..."
open ios/Runner.xcworkspace

