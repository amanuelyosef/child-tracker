import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_constants.dart';
import '../firebase_options.dart';

/// Background service instance
final backgroundService = FlutterBackgroundService();

/// Initialize the background service
Future<void> initializeBackgroundService() async {
  await backgroundService.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: AppConstants.notificationChannelId,
      foregroundServiceTypes: [AndroidForegroundType.location],
      initialNotificationTitle: AppConstants.notificationTitle,
      initialNotificationContent: AppConstants.notificationContent,
      foregroundServiceNotificationId: AppConstants.foregroundNotificationId,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: _onStart,
      onBackground: (ServiceInstance service) {
        _onStart(service);
        return true;
      },
    ),
  );
}

/// Ensure the background service is running
Future<void> ensureBackgroundServiceStarted() async {
  final running = await backgroundService.isRunning();
  if (!running) {
    await backgroundService.startService();
  }
}

/// Background service entry point
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureFirebaseInitialized();

  StreamSubscription<Position>? bgStream;
  String? pairCode;

  Future<void> startTracking() async {
    await bgStream?.cancel();
    bgStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppConstants.locationDistanceFilter,
      ),
    ).listen((pos) async {
      final code = pairCode;
      if (code == null) return;
      await FirebaseFirestore.instance
          .collection(AppConstants.locationsCollection)
          .doc(code)
          .set({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  service.on('setPairCode').listen((event) {
    pairCode = event?['pairCode'] as String?;
  });

  service.on('startTracking').listen((event) {
    startTracking();
  });

  service.on('stopTracking').listen((event) async {
    await bgStream?.cancel();
  });

  service.on('stopService').listen((event) async {
    await bgStream?.cancel();
    service.stopSelf();
  });

  if (service is AndroidServiceInstance) {
    await service.setForegroundNotificationInfo(
      title: AppConstants.notificationTitle,
      content: AppConstants.notificationContent,
    );
    await service.setAsForegroundService();
  }
}

/// Ensure Firebase is initialized (safe for multiple calls)
Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app' && e.code != 'app/duplicate-app') rethrow;
  } catch (_) {
    // Swallow unexpected duplicates
  }
}
