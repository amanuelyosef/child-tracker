import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_constants.dart';

/// Service for syncing location data with Firebase
class FirestoreLocationService {
  /// Singleton pattern
  static final FirestoreLocationService _instance = FirestoreLocationService._internal();
  factory FirestoreLocationService() => _instance;
  FirestoreLocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload position to Firestore
  Future<void> uploadPosition(String pairCode, Position pos) async {
    final now = FieldValue.serverTimestamp();
    
    // Update main location document
    final doc = _firestore.collection(AppConstants.locationsCollection).doc(pairCode);
    await doc.set({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'timestamp': now,
      'accuracy': pos.accuracy,
      'altitude': pos.altitude,
    });

    // Store in history
    await doc.collection(AppConstants.historySubcollection).add({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'timestamp': now,
      'accuracy': pos.accuracy,
    });
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
