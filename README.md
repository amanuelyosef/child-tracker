# 🔍 Child Tracker App

A Flutter app for real-time location tracking of children with parent monitoring capabilities.

## ✨ Features

- 📍 **Real-time Location Tracking** - Track child location with live updates
- 🗺️ **Interactive Maps** - View location on Google Maps with safe radius
- 📊 **Speed Monitoring** - See child's movement speed in km/h
- 📜 **Location History** - View past locations with timestamps
- ⚠️ **Safety Alerts** - Get alerts when child leaves safe zone
- 🎨 **Modern UI** - Material Design 3 interface

## 🚀 Quick Start

### 1. Setup Firebase
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

### 2. Add Google Maps API Keys
- Android: Add to `android/app/src/main/AndroidManifest.xml`
- iOS: Add to `ios/Runner/Info.plist`

### 3. Run the App
```bash
flutter pub get
flutter run --release
```

## 📱 How to Use

### Child Mode
1. Select "Child (Broadcaster)"
2. Share the 6-digit code with parent
3. Tap "Start Sharing"
4. Grant "Allow all the time" location permission

### Parent Mode
1. Select "Parent (Monitor)"
2. Enter child's code
3. Tap "Connect & Monitor"
4. View real-time distance and location

## 📖 Documentation

- [QUICKSTART.md](QUICKSTART.md) - Fast setup guide
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Detailed setup instructions
- [DOCS_INDEX.md](DOCS_INDEX.md) - All documentation

## 🛠️ Built With

- Flutter
- Firebase (Firestore)
- Google Maps
- Geolocator

## 📋 Requirements

- Flutter SDK 3.9.2+
- Android 9+ (API 28)
- iOS 13+
- Firebase account
- Google Cloud account (for Maps API)

## 🔒 Permissions Required

- Fine location access
- Background location access (Android)
- Notification permission
- Internet access

---

**Version**: 2.0.0 | **Status**: ✅ Production Ready