# Child Tracker - Setup Guide

## Overview
This is a Flutter app for real-time location tracking of children. A child (broadcaster) shares their location with a parent (monitor) in real-time with safety radius alerts.

## Fixed Issues
✅ **Real-time Location Tracking**: The main bug was that the parent only received a snapshot of their own location once per child update. This has been fixed by implementing a continuous location stream for the parent (`Geolocator.getPositionStream()`) that updates every 5 meters, ensuring live distance calculations.

✅ **Location History**: Added complete location history feature with timestamps and map navigation.

✅ **Speed Tracking**: Now shows child's movement speed in km/h for safety monitoring.

✅ **Improved UI**: Modern Material Design 3 interface with better visual hierarchy, colors, and user feedback.

## New Features Added
- 📍 **Real-time Distance Tracking**: Updates continuously as parent moves
- 📊 **Speed Monitoring**: Displays child's current movement speed
- 📜 **Location History**: View past locations with timestamps
- 🗺️ **Interactive Maps**: Visual representation of safe radius
- ⚠️ **Smart Alerts**: Visual warnings when child leaves safe zone
- 📊 **Statistics**: Track number of updates sent and last update time
- 🎨 **Enhanced UI**: Modern, intuitive interface with better feedback

## Prerequisites
Before running the app, ensure you have:

1. **Flutter SDK**: Install from https://flutter.dev/docs/get-started/install
2. **Android SDK** (for Android testing): Android 9 (API 28) or higher
3. **Xcode** (for iOS): Version 13.0 or higher
4. **Firebase Account**: Create one at https://firebase.google.com

## Firebase Setup (Required)

### Step 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add project"
3. Enter project name (e.g., "ChildTracker")
4. Follow the setup wizard
5. Create a Firestore database

### Step 2: Create Firestore Database
1. In Firebase Console → Firestore Database
2. Click "Create database"
3. Select location (closest to your region)
4. Start in **test mode** (for development) or set proper security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write for locations collection
    match /locations/{document=**} {
      allow read, write: if true;
    }
  }
}
```

### Step 3: Connect Firebase to Flutter App
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Run from project root: `flutterfire configure`
3. Select Android and iOS platforms
4. Select your Firebase project
5. This will automatically update `lib/firebase_options.dart`

## Google Maps Setup (Required)

### Step 1: Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project
3. Enable these APIs:
   - Maps SDK for Android
   - Maps SDK for iOS

### Step 2: Get API Keys

#### Android:
1. In Google Cloud Console → Credentials
2. Create API key
3. Add Android restriction: Add your app's SHA-1 fingerprint
4. Get SHA-1: Run `./gradlew signingReport` in `android/` directory
5. Add this key to `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY_HERE" />
```

#### iOS:
1. In Google Cloud Console → Credentials
2. Create API key with iOS restrictions
3. Add your iOS Bundle ID
4. Add to `ios/Runner/Info.plist`:
```xml
<key>com.google.ios.API_KEY</key>
<string>YOUR_API_KEY_HERE</string>
```

## Android Specific Setup

### Location Permissions
The app requires the following permissions (already in AndroidManifest.xml):
- `ACCESS_FINE_LOCATION` - Precise location
- `ACCESS_COARSE_LOCATION` - Approximate location  
- `ACCESS_BACKGROUND_LOCATION` - Location in background
- `FOREGROUND_SERVICE` - Required for background service
- `FOREGROUND_SERVICE_LOCATION` - Background location tracking
- `POST_NOTIFICATIONS` - Notifications while running

### Runtime Permissions
When the app runs on Android 6.0+, you must:
1. Grant location permissions when prompted
2. Select "**Allow all the time**" for background tracking to work
3. This is mandatory for child location sharing in the background

## Installation & Running

```bash
# Navigate to project directory
cd child_tracker

# Get dependencies
flutter pub get

# Run on emulator or device
flutter run

# Run in release mode (better performance)
flutter run --release
```

## How to Use

### Child Mode (Location Broadcaster):
1. Select "Child (Broadcaster)" on startup
2. Share the 6-digit pairing code with parent
3. Tap "Start Sharing" to begin broadcasting location
4. **Important**: Keep app open and screen on
5. Grant "Allow all the time" location permission
6. App will continuously send location to Firebase

### Parent Mode (Location Monitor):
1. Select "Parent (Monitor)" on startup
2. Enter child's 6-digit pairing code
3. Tap "Connect & Monitor"
4. View real-time distance and speed
5. Adjust safe radius with slider (25-500 meters)
6. View location on map
7. Check location history anytime
8. Get alerts when child is out of range

## Troubleshooting

### Location updates not showing:
- Ensure child has "Allow all the time" location permission
- Check if location services are enabled on device
- Verify Firebase Firestore is properly configured
- Check internet connection on both devices

### Google Maps not displaying:
- Verify API keys are correctly added
- Check Google Cloud APIs are enabled
- Ensure Maps SDK versions match in pubspec.yaml

### Firebase connection errors:
- Verify Firebase project ID in `firebase_options.dart`
- Check Firestore security rules
- Ensure device has internet access

### Background location not working:
- Android: App must have "Allow all the time" permission
- Battery saver mode may interfere - add app to whitelist
- Some devices have aggressive background process killing

## Security Recommendations

### For Production:
1. **Update Firestore Rules**:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /locations/{pairCode} {
      // Only allow if authenticated
      allow read, write: if request.auth != null;
    }
  }
}
```

2. **Enable Firebase Authentication**:
   - Add email/password or Google sign-in
   - Link locations to authenticated users

3. **Encrypt Sensitive Data**:
   - Consider encrypting location data at rest

4. **Rate Limiting**:
   - Limit API calls to prevent abuse

5. **Data Retention**:
   - Implement automatic deletion of old location history
   - Add GDPR compliance for EU users

## Technical Details

### Location Update Frequency:
- **Child**: Updates every 10 meters or 5 seconds (whichever comes first)
- **Parent**: Updates every 5 meters for accurate distance calculation
- **Firestore**: Real-time sync via Cloud Firestore snapshots

### Background Service:
- Android: Uses `flutter_background_service` for persistent tracking
- iOS: Uses significant location change monitoring
- Both update Firestore continuously

### Battery Optimization:
- High accuracy mode uses more battery
- Consider using balanced mode in production
- Background service uses ~2-5% battery per hour

## Dependencies

- **geolocator**: Location services
- **firebase_core**: Firebase initialization
- **cloud_firestore**: Database and real-time sync
- **google_maps_flutter**: Map display
- **flutter_background_service**: Background location tracking
- **permission_handler**: Runtime permissions
- **intl**: Date/time formatting

## Performance Tips

1. Use release mode for better performance: `flutter run --release`
2. Reduce location update frequency if battery is critical
3. Limit history queries to last 100 entries (default)
4. Consider clustering markers for many historical locations

## Support & Next Steps

### Recommended Enhancements:
- [ ] Add geofencing for automatic alerts
- [ ] Implement push notifications
- [ ] Add multiple child tracking
- [ ] Add family member accounts
- [ ] Implement SOS button
- [ ] Add battery status display
- [ ] Add travel route visualization
- [ ] Implement location-based reminders

### Testing:
1. Test with 2 devices (child & parent)
2. Verify location updates in different areas
3. Test with network disconnect/reconnect
4. Test background location while device is locked
5. Check battery consumption over time

---

**Last Updated**: December 2024
**Version**: 1.0.0
