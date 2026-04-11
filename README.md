# 🧒 Children Tracker

<div align="center">

![Children Tracker Banner](assets/app_logo.png)

### *Stay close. Stay safe.*

[![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%2B%20Auth-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey?style=for-the-badge&logo=android&logoColor=white)](https://flutter.dev/multi-platform)

**A real-time GPS family safety app built with Flutter & Firebase**

[Features](#-features) • [Screenshots](#-screenshots) • [Architecture](#-architecture) • [Getting Started](#-getting-started) • [Contributing](#-contributing)

</div>

---

## 📖 Table of Contents

- [About the Project](#-about-the-project)
- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Architecture](#-architecture)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Firebase Setup](#1-firebase-setup)
  - [Google Maps Setup](#2-google-maps-setup)
  - [Running the App](#3-running-the-app)
- [Core Flows](#-core-flows)
- [Data Model](#-data-model)
- [Configuration](#-configuration)
- [Known Limitations](#-known-limitations)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🌟 About the Project

**Children Tracker** is a cross-platform Flutter mobile application designed to give parents peace of mind by allowing them to monitor the real-time GPS location of their children — safely, privately, and with the child's consent built right into the app.

Unlike generic tracking tools, Children Tracker is built with a **dual-role design**: the experience for a parent and the experience for a child are entirely different, purpose-built screens — not just the same UI with different permissions.

> 💡 Children can **toggle tracking off** at any time from their own device, ensuring the app respects their autonomy while keeping families connected.

---

## ✨ Features

### 👨‍👩‍👧 For Parents
| Feature | Description |
|---|---|
| 📍 **Live Location Tracking** | See your child's real-time GPS position on an interactive Google Map |
| 🔴 **Safe Radius Alerts** | Set a geofence perimeter (25–500 m, default 100 m) and get notified if your child goes outside it |
| 🗺️ **Location History** | Browse a timeline of your child's last 100 recorded locations |
| 💬 **Message Inbox** | Receive messages from your child with unread badge indicators |
| 👶 **Multi-Child Support** | Link and monitor multiple children from a single parent account |
| 📏 **Live Metrics** | View real-time distance and speed calculations |

### 🧒 For Children
| Feature | Description |
|---|---|
| 🔢 **Simple Pairing** | Pair with a parent using a permanent 6-digit code — no QR scanning needed |
| ▶️ **Start / Stop Tracking** | Full control to start or stop broadcasting location at any time |
| 📤 **Message Parent** | Send quick messages or use built-in message templates to contact a parent |
| 🔒 **Privacy First** | Tracking is always opt-in and can be paused instantly |

### ⚙️ System Features
- 🔋 **Background Location Sharing** — Tracking persists even when the app is minimized (Android Foreground Service + iOS Background Mode)
- 🗓️ **Smart History Saving** — Location saved every 50 m of movement to minimize noise and cost
- 🧠 **Geocoding Cache** — Reverse geocoding results cached in memory to avoid redundant API calls
- 📵 **Offline Resilience** — Background service continues attempting uploads independently

---

## 🛠️ Tech Stack

| Category | Technology |
|---|---|
| **Framework** | Flutter 3.9.2+, Dart |
| **Backend** | Firebase Cloud Firestore, Firebase Authentication |
| **Maps** | Google Maps Flutter (`google_maps_flutter ^2.14.0`) |
| **GPS** | Geolocator (`geolocator ^10.1.0`) |
| **Geocoding** | Device-native geocoding (`geocoding ^3.0.0`) |
| **Background** | `flutter_background_service ^5.1.0` |
| **Permissions** | `permission_handler ^11.3.1` |
| **UI Design** | Flutter Material Design 3 |
| **Linting** | `flutter_lints ^5.0.0` |

---

## 🏗️ Architecture

Children Tracker follows a **layered service architecture** using Flutter's built-in `StatefulWidget` + `setState` for local state and `StreamBuilder` / `StreamSubscription` for reactive Firebase data — no third-party state management library is used.

```
┌─────────────────────────────────────────────────────┐
│                    UI Layer                         │
│         Screens (11)  ·  Widgets (reusable)         │
└────────────────────────┬────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────┐
│                  Service Layer                      │
│  AuthService · UserService · LocationService        │
│  FirestoreLocationService · BackgroundService       │
│  GeocodingService · MessageService                  │
└────────────────────────┬────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────┐
│                  Firebase Layer                     │
│        Cloud Firestore  ·  Firebase Auth            │
└─────────────────────────────────────────────────────┘
```

### 📡 Real-Time Tracking Data Flow

```
Child Device
│
├── [Foreground] LocationService.getPositionStream()
│       └──► FirestoreLocationService.uploadPosition()
│                   └──► Firestore: locations/{pairCode}
│
└── [Background] BackgroundService (Foreground Service / BG Mode)
        └──► Geolocator stream
                └──► Firestore: locations/{pairCode}
                       │
                       ▼
              Parent Device
              FirestoreLocationService.listenToChildLocation()
                       │
                       ▼
              setState → map marker + distance + speed + safe-radius check
```

### 🔑 All Services Are Singletons

```dart
// Example pattern used across all services
factory AuthService() => _instance;
static final AuthService _instance = AuthService._internal();
AuthService._internal();
```

---

## 📁 Project Structure

```
lib/
├── main.dart                        # App bootstrap, Firebase init, AuthWrapper, RoleBasedNavigator
├── firebase_options.dart            # Platform Firebase config (regenerate before use)
│
├── config/
│   ├── app_constants.dart           # All magic numbers/strings (distances, collections, limits)
│   ├── app_theme.dart               # ThemeData, AppColors, GradientBackground
│   └── config.dart                  # Barrel export
│
├── models/
│   ├── user_model.dart              # AppUser, ParentUser, ChildUser, LinkedChild
│   ├── message_model.dart           # ChildMessage
│   └── models.dart                  # Barrel export
│
├── services/
│   ├── auth_service.dart            # Firebase Auth + Firestore user creation
│   ├── user_service.dart            # User CRUD, pair code gen, parent-child linking
│   ├── location_service.dart        # GPS permissions + position stream
│   ├── firestore_location_service.dart  # Upload position/history, listen to child
│   ├── background_service.dart      # flutter_background_service controller
│   ├── geocoding_service.dart       # Reverse geocoding with in-memory cache
│   ├── message_service.dart         # Firestore messages CRUD + streams
│   └── services.dart                # Barrel export
│
├── screens/
│   ├── login_screen.dart            # Email/password sign-in + forgot password
│   ├── register_screen.dart         # Registration with role selector
│   ├── parent_mode_screen.dart      # Parent dashboard: child selection, tracking, radius
│   ├── child_mode_screen.dart       # Child dashboard: pair code, start/stop broadcast
│   ├── map_view_screen.dart         # Full-screen Google Map with markers + radius circle
│   ├── location_history_screen.dart # Timeline list of past locations
│   ├── manage_children_screen.dart  # Add/remove children by pair code
│   ├── edit_profile_screen.dart     # Display name editing + sign out
│   ├── message_parent_screen.dart   # Child → parent message compose
│   ├── parent_messages_screen.dart  # Parent inbox with unread badge
│   └── screens.dart                 # Barrel export
│
├── widgets/
│   ├── common_widgets.dart          # GlassCard, StatChip, MetricCard, RoleCard, StatusBanner
│   ├── logout_dialog.dart           # LogoutDialog, LogoutButton
│   └── widgets.dart                 # Barrel export
│
└── utils/
    ├── date_formatters.dart         # formatTime, formatDate, formatDateTime
    └── utils.dart                   # Barrel export
```

---

## 🚀 Getting Started

### Prerequisites

Before you begin, make sure you have the following installed:

- ✅ [Flutter SDK](https://flutter.dev/docs/get-started/install) **≥ 3.9.2**
- ✅ [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/) (for iOS)
- ✅ A [Firebase](https://firebase.google.com) account (free Spark tier is sufficient)
- ✅ A [Google Maps Platform](https://console.cloud.google.com) API key with **Maps SDK for Android/iOS** enabled
- ✅ [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) for Firebase configuration

---

### 1. Clone and Install

```bash
# Clone the repository
git clone https://github.com/amanuelyosef/child-tracker.git
cd child-tracker

# Install dependencies
flutter pub get
```

---

### 2. Firebase Setup

#### a) Create a Firebase Project
1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a new project (e.g., `child-tracker`)
3. Enable **Authentication → Sign-in Method → Email/Password**
4. Create a **Cloud Firestore** database (start in test mode for development)

#### b) Register Your Android App
1. In Firebase Console → Project Settings → Add App → Android
2. Use package name: `com.example.child_tracker`
3. Download `google-services.json` and place it in `android/app/`

#### c) Generate Firebase Options
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure (this regenerates lib/firebase_options.dart with real credentials)
flutterfire configure
```

> ⚠️ **Important:** The `lib/firebase_options.dart` in this repository contains **placeholder values** and will not connect to Firebase without this step.

#### d) Deploy Firestore Indexes
The messages query requires a composite index. Create it in Firebase Console:

| Collection | Field 1 | Field 2 |
|---|---|---|
| `messages` | `parentId` ASC | `sentAt` DESC |

#### e) Recommended Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can only read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Only the linked parent can read a child's location
    match /locations/{pairCode} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    // Messages: child writes, parent reads
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

> 🔒 Tighten these rules before going to production.

---

### 3. Google Maps Setup

#### Android
Replace the placeholder API key in `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY" />
```

#### iOS
Add your API key in `ios/Runner/AppDelegate.swift`:

```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

> 🔒 **Security tip:** Restrict your API key to your app's package name and SHA-1 certificate fingerprint in the Google Cloud Console to prevent unauthorized usage.

---

### 4. Running the App

```bash
# Run on Android
flutter run -d android

# Run on iOS (macOS only)
flutter run -d ios

# Build release APK
flutter build apk --release

# Build Android App Bundle (for Play Store)
flutter build appbundle

# Build for iOS release (requires Xcode signing)
flutter build ios --release
```

---

### 5. Lint and Test

```bash
# Static analysis
flutter analyze

# Run tests
flutter test
```

---

## 🔄 Core Flows

### 🔐 Authentication & Routing

```
App Launch
    │
    ▼
AuthWrapper (StreamBuilder on authStateChanges)
    │
    ├── Not signed in ──► LoginScreen / RegisterScreen
    │
    └── Signed in ──► RoleBasedNavigator
                            │
                            ├── role == parent ──► ParentModeScreen
                            └── role == child  ──► ChildModeScreen
```

### 🔗 Pairing Flow (Parent ↔ Child)

```
1. Child registers → unique 6-digit pairCode generated & saved in Firestore
2. Parent opens "Manage Children" → enters child's 6-digit code
3. UserService validates code → checks no existing parent link
4. Bidirectional write:
     parent.childrenIds[] ← append child.uid
     child.parentId       ← set parent.uid
5. Parent can now track the child in real time
```

### 📍 Location Tracking Flow

```
Child taps "Start Tracking"
    │
    ├── Foreground: LocationService stream → FirestoreLocationService.uploadPosition()
    │       └── Updates: locations/{pairCode} (real-time doc)
    │       └── Saves:   locations/{pairCode}/history (every 50 m moved)
    │
    └── Background: BackgroundService (Foreground Service)
            └── Geolocator stream → same Firestore path

Parent screen listens to locations/{pairCode}
    └── Updates map marker, distance, speed, safe-radius check in real time
```

---

## 🗄️ Data Model

### Firestore Collections

```
users/
  {uid}/
    email: string
    displayName: string
    role: "parent" | "child"
    createdAt: timestamp
    updatedAt: timestamp
    # Parent only:
    childrenIds: [uid, ...]
    # Child only:
    pairCode: string (6 digits)
    parentId: string | null
    isTrackingEnabled: boolean
    lastLocationUpdate: timestamp

locations/
  {pairCode}/                       ← Real-time position
    latitude: number
    longitude: number
    timestamp: timestamp
    accuracy: number
    altitude: number
    history/
      {autoId}/                     ← Historical trail (max 100 entries)
        latitude: number
        longitude: number
        timestamp: timestamp
        accuracy: number
        address: string

messages/
  {autoId}/
    childId: string
    parentId: string
    childName: string
    message: string
    sentAt: timestamp
    isRead: boolean
```

---

## ⚙️ Configuration

All app-wide constants live in `lib/config/app_constants.dart`:

| Constant | Default | Description |
|---|---|---|
| `defaultSafeRadius` | `100 m` | Default geofence radius |
| `minSafeRadius` | `25 m` | Minimum geofence radius |
| `maxSafeRadius` | `500 m` | Maximum geofence radius |
| `maxHistoryItems` | `100` | Max saved history entries per child |
| `historyDistanceFilter` | `50 m` | Minimum movement to trigger a history save |
| `locationDistanceFilter` | `10 m` | Minimum movement for real-time updates |
| `pairCodeLength` | `6` | Digits in the pairing code |

---

## ⚠️ Known Limitations

> These are documented gaps in the current version, not bugs.

| Area | Issue |
|---|---|
| 📵 **Offline Support** | Firestore offline persistence is not enabled; uploads silently fail if the device is offline |
| 🔑 **Maps API Key** | The default key in the repository is a placeholder; you must supply your own |
| 📦 **App ID** | Still uses default `com.example.child_tracker` — update before publishing |
| ✍️ **Signing** | Release builds use debug signing — add a proper keystore before Play Store submission |
| 🐧 **Linux** | Linux platform is explicitly unsupported due to Firebase plugin limitations |

---

## 🗺️ Roadmap

> Planned improvements for future versions:

- [ ] 🔔 **FCM Push Notifications** — Alert parents when a child leaves the safe radius, even with the app closed
- [ ] 💬 **Two-way Messaging** — Allow parents to reply to children's messages
- [ ] 📵 **Offline Support** — Enable Firestore offline persistence for resilient location uploads
- [ ] 🔐 **Firestore Security Rules** — Bundle production-grade rules with the repository
- [ ] 🧪 **Test Coverage** — Add unit tests for all service classes and update the stale widget test
- [ ] 📍 **Multiple Geofences** — Allow parents to define named safe zones (home, school, etc.)
- [ ] 🌙 **Battery Optimization Mode** — Reduced update frequency option for power saving
- [ ] 🔑 **Social Login** — Google / Apple sign-in as alternatives to email/password
- [ ] 🌐 **Web Dashboard** — Parent-facing web portal for desktop monitoring

---

## 🤝 Contributing

Contributions are welcome! Here's how to get started:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/your-feature-name`
3. **Commit** your changes: `git commit -m 'feat: add some feature'`
4. **Push** to your branch: `git push origin feature/your-feature-name`
5. **Open** a Pull Request

### Commit Convention
This project follows [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Use for |
|---|---|
| `feat:` | New features |
| `fix:` | Bug fixes |
| `docs:` | Documentation changes |
| `refactor:` | Code refactoring |
| `test:` | Adding or fixing tests |
| `chore:` | Build, config, tooling changes |

### Code Style
- Run `flutter analyze` before submitting a PR — no warnings allowed
- Follow existing patterns: singleton services, barrel exports, `fromFirestore`/`toFirestore` on models
- Remove all `debugPrint` statements from production code paths

---

## 📄 License

This project is licensed under the **Apache License** — see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Amanuel Yosef**

[![GitHub](https://img.shields.io/badge/GitHub-amanuelyosef-181717?style=for-the-badge&logo=github)](https://github.com/amanuelyosef)

---

<div align="center">

Made with Flutter

*If this project helped you, please consider giving it a ⭐ on GitHub!*

</div>
