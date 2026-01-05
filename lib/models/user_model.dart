import 'package:cloud_firestore/cloud_firestore.dart';

/// User roles in the app
enum UserRole { parent, child }

/// Base user model with common fields
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    this.updatedAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: data['role'] == 'child' ? UserRole.child : UserRole.parent,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role == UserRole.child ? 'child' : 'parent',
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}

/// Parent-specific user model
class ParentUser extends AppUser {
  final List<String> childrenIds; // List of child user IDs

  ParentUser({
    required super.uid,
    required super.email,
    required super.displayName,
    required super.createdAt,
    super.updatedAt,
    this.childrenIds = const [],
  }) : super(role: UserRole.parent);

  factory ParentUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ParentUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      childrenIds: List<String>.from(data['childrenIds'] ?? []),
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      ...super.toFirestore(),
      'childrenIds': childrenIds,
    };
  }

  ParentUser copyWith({
    String? displayName,
    List<String>? childrenIds,
    DateTime? updatedAt,
  }) {
    return ParentUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      childrenIds: childrenIds ?? this.childrenIds,
    );
  }
}

/// Child-specific user model
class ChildUser extends AppUser {
  final String pairCode; // Permanent pairing code
  final String? parentId; // Connected parent's user ID
  final bool isTrackingEnabled;
  final DateTime? lastLocationUpdate;

  ChildUser({
    required super.uid,
    required super.email,
    required super.displayName,
    required super.createdAt,
    super.updatedAt,
    required this.pairCode,
    this.parentId,
    this.isTrackingEnabled = true,
    this.lastLocationUpdate,
  }) : super(role: UserRole.child);

  factory ChildUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChildUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      pairCode: data['pairCode'] ?? '',
      parentId: data['parentId'],
      isTrackingEnabled: data['isTrackingEnabled'] ?? true,
      lastLocationUpdate: (data['lastLocationUpdate'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      ...super.toFirestore(),
      'pairCode': pairCode,
      if (parentId != null) 'parentId': parentId,
      'isTrackingEnabled': isTrackingEnabled,
      if (lastLocationUpdate != null)
        'lastLocationUpdate': Timestamp.fromDate(lastLocationUpdate!),
    };
  }

  ChildUser copyWith({
    String? displayName,
    String? parentId,
    bool? isTrackingEnabled,
    DateTime? lastLocationUpdate,
    DateTime? updatedAt,
  }) {
    return ChildUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pairCode: pairCode,
      parentId: parentId ?? this.parentId,
      isTrackingEnabled: isTrackingEnabled ?? this.isTrackingEnabled,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
    );
  }
}

/// Linked child info stored in parent's view
class LinkedChild {
  final String childId;
  final String pairCode;
  final String displayName;
  final String email;
  final bool isTrackingEnabled;
  final DateTime? lastLocationUpdate;

  LinkedChild({
    required this.childId,
    required this.pairCode,
    required this.displayName,
    required this.email,
    this.isTrackingEnabled = true,
    this.lastLocationUpdate,
  });

  factory LinkedChild.fromChildUser(ChildUser child) {
    return LinkedChild(
      childId: child.uid,
      pairCode: child.pairCode,
      displayName: child.displayName,
      email: child.email,
      isTrackingEnabled: child.isTrackingEnabled,
      lastLocationUpdate: child.lastLocationUpdate,
    );
  }
}
