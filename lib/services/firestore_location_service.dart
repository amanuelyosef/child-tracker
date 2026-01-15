import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_constants.dart';
import 'geocoding_service.dart';

/// Service for syncing location data with Firebase
class FirestoreLocationService {
  /// Singleton pattern
  static final FirestoreLocationService _instance = FirestoreLocationService._internal();
  factory FirestoreLocationService() => _instance;
  FirestoreLocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GeocodingService _geocodingService = GeocodingService();

  // Track last saved history position for distance-based saving
  double? _lastHistoryLat;
  double? _lastHistoryLng;

  /// Upload position to Firestore (real-time tracking)
  /// Only saves to history if moved 50+ meters from last history entry
  Future<void> uploadPosition(String pairCode, Position pos) async {
    final now = FieldValue.serverTimestamp();
    
    // Always update main location document (for real-time tracking)
    final doc = _firestore.collection(AppConstants.locationsCollection).doc(pairCode);
    await doc.set({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'timestamp': now,
      'accuracy': pos.accuracy,
      'altitude': pos.altitude,
    });

    // Only save to history if moved significant distance (50m by default)
    final shouldSaveHistory = _shouldSaveToHistory(pos.latitude, pos.longitude);
    
    if (shouldSaveHistory) {
      // Get human-readable address
      String address;
      try {
        address = await _geocodingService.getAddressFromCoordinates(
          pos.latitude, 
          pos.longitude,
        );
      } catch (_) {
        address = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      }

      // Store in history with address
      await doc.collection(AppConstants.historySubcollection).add({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'timestamp': now,
        'accuracy': pos.accuracy,
        'address': address,
      });

      // Update last saved position
      _lastHistoryLat = pos.latitude;
      _lastHistoryLng = pos.longitude;
    }
  }

  /// Check if we should save to history based on distance from last save
  bool _shouldSaveToHistory(double lat, double lng) {
    // Always save first position
    if (_lastHistoryLat == null || _lastHistoryLng == null) {
      return true;
    }

    // Calculate distance from last saved history position
    final distance = Geolocator.distanceBetween(
      _lastHistoryLat!,
      _lastHistoryLng!,
      lat,
      lng,
    );

    // Save if moved more than history distance filter (50m)
    return distance >= AppConstants.historyDistanceFilter;
  }

  /// Reset the last history position (e.g., when starting new session)
  void resetHistoryTracking() {
    _lastHistoryLat = null;
    _lastHistoryLng = null;
  }

  /// Upload simple location (for background service)
  Future<void> uploadSimpleLocation(String pairCode, double lat, double lng) async {
    await _firestore.collection(AppConstants.locationsCollection).doc(pairCode).set({
      'latitude': lat,
      'longitude': lng,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Listen to child location updates
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToChildLocation(String pairCode) {
    return _firestore
        .collection(AppConstants.locationsCollection)
        .doc(pairCode)
        .snapshots();
  }

  /// Get location history
  Stream<QuerySnapshot> getLocationHistory(String pairCode) {
    return _firestore
        .collection(AppConstants.locationsCollection)
        .doc(pairCode)
        .collection(AppConstants.historySubcollection)
        .orderBy('timestamp', descending: true)
        .limit(AppConstants.maxHistoryItems)
        .snapshots();
  }
}
