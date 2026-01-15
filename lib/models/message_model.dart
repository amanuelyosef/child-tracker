import 'package:cloud_firestore/cloud_firestore.dart';

/// Message sent from child to parent
class ChildMessage {
  final String id;
  final String childId;
  final String parentId;
  final String childName;
  final String message;
  final DateTime sentAt;
  final bool isRead;

  ChildMessage({
    required this.id,
    required this.childId,
    required this.parentId,
    required this.childName,
    required this.message,
    required this.sentAt,
    this.isRead = false,
  });

  factory ChildMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChildMessage(
      id: doc.id,
      childId: data['childId'] ?? '',
      parentId: data['parentId'] ?? '',
      childName: data['childName'] ?? '',
      message: data['message'] ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'childId': childId,
      'parentId': parentId,
      'childName': childName,
      'message': message,
      'sentAt': Timestamp.fromDate(sentAt),
      'isRead': isRead,
    };
  }

  ChildMessage copyWith({
    bool? isRead,
  }) {
    return ChildMessage(
      id: id,
      childId: childId,
      parentId: parentId,
      childName: childName,
      message: message,
      sentAt: sentAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
