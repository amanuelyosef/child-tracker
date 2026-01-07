import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Service for managing users and parent-child relationships
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';
  static const String _locationsCollection = 'locations';

  /// Generate a unique 6-digit pair code for a child
  Future<String> generateUniquePairCode() async {
    final rng = Random();
    String code;
    bool isUnique = false;

    do {
      code = (rng.nextInt(900000) + 100000).toString();
      // Check if code already exists
      final query = await _firestore
          .collection(_usersCollection)
          .where('pairCode', isEqualTo: code)
          .limit(1)
          .get();
      isUnique = query.docs.isEmpty;
    } while (!isUnique);

    return code;
  }

  /// Create a new parent user
  Future<void> createParentUser({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    debugPrint('UserService.createParentUser called');
    debugPrint('UID: $uid, Email: $email, Name: $displayName');
    
    final data = {
      'email': email,
      'displayName': displayName,
      'role': 'parent',
      'childrenIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    };
    
    debugPrint('Data to write: $data');
    debugPrint('Writing to collection: $_usersCollection, doc: $uid');
    
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .set(data);
      debugPrint('Parent user document written successfully!');
    } catch (e) {
      debugPrint('!!! FIRESTORE WRITE ERROR in createParentUser: $e');
      rethrow;
    }
  }

  /// Create a new child user with a unique pair code
  Future<String> createChildUser({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    debugPrint('UserService.createChildUser called');
    debugPrint('UID: $uid, Email: $email, Name: $displayName');
    
    final pairCode = await generateUniquePairCode();
    debugPrint('Generated pairCode: $pairCode');

    final data = {
      'email': email,
      'displayName': displayName,
      'role': 'child',
      'pairCode': pairCode,
      'isTrackingEnabled': true,
      'createdAt': FieldValue.serverTimestamp(),
    };
    
    debugPrint('Data to write: $data');
    debugPrint('Writing to collection: $_usersCollection, doc: $uid');
    
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .set(data);
      debugPrint('Child user document written successfully!');

      // Also create the location document for this child
      debugPrint('Creating location document with pairCode: $pairCode');
      await _firestore.collection(_locationsCollection).doc(pairCode).set({
        'childId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Location document created successfully!');
    } catch (e) {
      debugPrint('!!! FIRESTORE WRITE ERROR in createChildUser: $e');
      rethrow;
    }

    return pairCode;
  }

  /// Get user by ID
  Future<AppUser?> getUser(String uid) async {
    debugPrint('UserService.getUser called for UID: $uid');
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      debugPrint('UserService.getUser: doc.exists = ${doc.exists}');
      if (!doc.exists) {
        debugPrint('UserService.getUser: Document does not exist!');
        return null;
      }

      final data = doc.data()!;
      debugPrint('UserService.getUser: data = $data');
      final role = data['role'] as String?;

      if (role == 'child') {
        return ChildUser.fromFirestore(doc);
      } else {
        return ParentUser.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('UserService.getUser ERROR: $e');
      return null;
    }
  }

  /// Get parent user by ID
  Future<ParentUser?> getParentUser(String uid) async {
    final doc = await _firestore.collection(_usersCollection).doc(uid).get();
    if (!doc.exists) return null;
    return ParentUser.fromFirestore(doc);
  }

  /// Get child user by ID
  Future<ChildUser?> getChildUser(String uid) async {
    final doc = await _firestore.collection(_usersCollection).doc(uid).get();
    if (!doc.exists) return null;
    return ChildUser.fromFirestore(doc);
  }

  /// Get child user by pair code
  Future<ChildUser?> getChildByPairCode(String pairCode) async {
    final query = await _firestore
        .collection(_usersCollection)
        .where('pairCode', isEqualTo: pairCode)
        .where('role', isEqualTo: 'child')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return ChildUser.fromFirestore(query.docs.first);
  }

  /// Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (displayName != null) {
      updates['displayName'] = displayName;
    }

    await _firestore.collection(_usersCollection).doc(uid).update(updates);
  }

  /// Add a child to parent's list
  Future<bool> addChildToParent({
    required String parentId,
    required String pairCode,
  }) async {
    // Find the child by pair code
    final child = await getChildByPairCode(pairCode);
    if (child == null) return false;

    // Check if child already has a parent
    if (child.parentId != null && child.parentId != parentId) {
      return false; // Child already linked to another parent
    }

    // Update parent's children list
    await _firestore.collection(_usersCollection).doc(parentId).update({
      'childrenIds': FieldValue.arrayUnion([child.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update child's parent reference
    await _firestore.collection(_usersCollection).doc(child.uid).update({
      'parentId': parentId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  /// Remove a child from parent's list
  Future<void> removeChildFromParent({
    required String parentId,
    required String childId,
  }) async {
    // Remove from parent's children list
    await _firestore.collection(_usersCollection).doc(parentId).update({
      'childrenIds': FieldValue.arrayRemove([childId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Remove parent reference from child
    await _firestore.collection(_usersCollection).doc(childId).update({
      'parentId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get all children for a parent
  Future<List<ChildUser>> getChildrenForParent(String parentId) async {
    final parent = await getParentUser(parentId);
    if (parent == null || parent.childrenIds.isEmpty) return [];

    final children = <ChildUser>[];
    for (final childId in parent.childrenIds) {
      final child = await getChildUser(childId);
      if (child != null) {
        children.add(child);
      }
    }

    return children;
  }

  /// Stream of children for a parent
  Stream<List<ChildUser>> streamChildrenForParent(String parentId) {
    return _firestore
        .collection(_usersCollection)
        .doc(parentId)
        .snapshots()
        .asyncMap((parentDoc) async {
      if (!parentDoc.exists) return <ChildUser>[];

      final data = parentDoc.data()!;
      final childrenIds = List<String>.from(data['childrenIds'] ?? []);

      if (childrenIds.isEmpty) return <ChildUser>[];

      final children = <ChildUser>[];
      for (final childId in childrenIds) {
        final child = await getChildUser(childId);
        if (child != null) {
          children.add(child);
        }
      }

      return children;
    });
  }

  /// Get parent info for a child
  Future<ParentUser?> getParentForChild(String childId) async {
    final child = await getChildUser(childId);
    if (child == null || child.parentId == null) return null;

    return getParentUser(child.parentId!);
  }

  /// Toggle tracking for a child
  Future<void> setTrackingEnabled({
    required String childId,
    required bool enabled,
  }) async {
    await _firestore.collection(_usersCollection).doc(childId).update({
      'isTrackingEnabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update last location timestamp for a child
  Future<void> updateLastLocationTime(String childId) async {
    await _firestore.collection(_usersCollection).doc(childId).update({
      'lastLocationUpdate': FieldValue.serverTimestamp(),
    });
  }

  /// Stream user data
  Stream<AppUser?> streamUser(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;

      final data = doc.data()!;
      final role = data['role'] as String?;

      if (role == 'child') {
        return ChildUser.fromFirestore(doc);
      } else {
        return ParentUser.fromFirestore(doc);
      }
    });
  }

  /// Stream child user data
  Stream<ChildUser?> streamChildUser(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return ChildUser.fromFirestore(doc);
    });
  }
}
