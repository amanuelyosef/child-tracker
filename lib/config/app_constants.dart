/// Application constants and configuration values.
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Children Tracker';
  static const String appTagline = 'Stay close. Stay safe.';

  // Location settings
  static const int locationDistanceFilter = 10; // meters
  static const int parentLocationDistanceFilter = 5; // meters
  static const double defaultSafeRadius = 100; // meters
  static const double minSafeRadius = 25; // meters
  static const double maxSafeRadius = 500; // meters

  // Background service
  static const String notificationChannelId = 'child_tracker_channel';
  static const int foregroundNotificationId = 888;
  static const String notificationTitle = 'Child Tracker';
  static const String notificationContent = 'Sharing location in background';

  // Firebase collections
  static const String locationsCollection = 'locations';
  static const String usersCollection = 'users';
  static const String historySubcollection = 'history';

  // History
  static const int maxHistoryItems = 100;
}
