# Trading App

A Flutter application for trading strategy management.

## Getting Started

This project is a starting point for a Flutter application.

### iOS Development
For instructions on setting up the environment for iOS (Simulator & Physical Device), please read [SETUP_IOS.md](SETUP_IOS.md).

### Quick Start (Simulator)
```bash
./scripts/open_ios.sh
flutter run
```

## Configuration & Environments

The app supports different environments for development (local backend) and production (live backend).

### Configuration Files
- `assets/config/app_config_dev.json`: Points to local Firebase Emulator (`http://127.0.0.1:5001/...`).
- `assets/config/app_config_prod.json`: Points to live Firebase Functions (`https://us-central1-...`).

### Running the App

**Development Mode (Default)**
Connects to the local backend.
```bash
flutter run
# OR explicitly
flutter run --dart-define=ENV=dev
```

**Production Mode**
Connects to the live backend.
```bash
flutter run --dart-define=ENV=prod
# OR run in release mode
flutter run --release
```

## Backend Connection

Ensure the backend is running before starting the app in development mode:

```bash
# In ../trading-backend/
yarn start
```

## Useful Resources

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
