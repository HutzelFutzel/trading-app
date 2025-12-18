# iOS Development Setup Guide

## 1. Prerequisites
- macOS machine with Xcode installed.
- Apple Developer Account (optional for simulator, required for physical device testing).
- Flutter SDK installed and configured.

## 2. Using the Simulator (iPhone 15 Pro Max)
We have pre-configured the project to use the **iPhone 15 Pro Max** simulator by default.

### Setup
Run the helper script to boot the simulator and open the project in Xcode:
```bash
./scripts/open_ios.sh
```

### Running the App
- **VS Code**: Select "Debug (iPhone 15 Pro Max)" from the Run and Debug sidebar and press Play (F5).
- **Terminal**: Run `flutter run -d 76FF6D93-BDB7-454F-A5B7-20963BF704BA`.

## 3. Physical Device Testing

### 1. Configure Signing
To run on a real iPhone, you need to sign the app.
1. Run `./scripts/open_ios.sh` to open the project in Xcode.
2. In Xcode, select the **Runner** project in the left navigator.
3. Select the **Runner** target in the main view.
4. Go to the **Signing & Capabilities** tab.
5. Under **Team**, select your Apple ID (Personal Team).
   - If no team is available, click "Add Account..." and log in with your Apple ID.
6. Ensure a unique **Bundle Identifier** is set (e.g., `com.yourname.tradingApp`).

### 2. Connect Your Device
1. Connect your iPhone to your Mac via USB.
2. Unlock your iPhone.
3. If prompted, tap "Trust This Computer" on your iPhone.

### 3. Run the App
- **VS Code**: Select "Release (Physical Device)" configuration.
- **Terminal**: Run `flutter run -d <your-device-id> --release`.
  - You can find your device ID by running `flutter devices`.

### 4. Trust the Developer App
After installing the app for the first time, it won't launch immediately due to security restrictions.
1. On your iPhone, go to **Settings > General > VPN & Device Management** (or **Profiles & Device Management**).
2. Tap on your Apple ID (Developer App).
3. Tap **Trust "Your Apple ID"**.
4. You can now launch the app from your home screen.

## Troubleshooting
- **"Untrusted Developer" Error**: Follow step 4 in "Physical Device Testing".
- **Signing Errors**: Ensure your Bundle ID is unique and your Team is correctly selected in Xcode.

