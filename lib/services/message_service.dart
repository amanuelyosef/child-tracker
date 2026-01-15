import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';

/// Service for handling child-to-parent messaging
class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  CollectionReference<Map<String, dynamic>> get _messagesCollection =>
      _firestore.collection('messages');

  /// Send a message from child to parent
  Future<bool> sendMessage({
    required String childId,
    required String parentId,
    required String childName,
    required String message,
  }) async {
    try {
      debugPrint('MessageService: Sending message from $childName to parent $parentId');
      
      await _messagesCollection.add({
        'childId': childId,
        'parentId': parentId,
        'childName': childName,
        'message': message,
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      
      debugPrint('MessageService: Message sent successfully');
      return true;
    } catch (e) {
      debugPrint('MessageService: Error sending message: $e');
      return false;
    }
  }

  /// Get all messages for a parent (real-time stream)
  Stream<List<ChildMessage>> getMessagesForParent(String parentId) {
    return _messagesCollection
        .where('parentId', isEqualTo: parentId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .handleError((error) {
          debugPrint('MessageService: Error fetching messages: $error');
          // Return empty stream on error (likely missing index or empty collection)
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => ChildMessage.fromFirestore(doc))
            .toList());
  }

  /// Get unread message count for a parent
  Stream<int> getUnreadMessageCount(String parentId) {
    return _messagesCollection
        .where('parentId', isEqualTo: parentId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .handleError((error) {
          debugPrint('MessageService: Error fetching unread count: $error');
        })
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark a message as read
  Future<void> markAsRead(String messageId) async {
    try {
      await _messagesCollection.doc(messageId).update({'isRead': true});
    } catch (e) {
      debugPrint('MessageService: Error marking message as read: $e');
    }
  }

  /// Mark all messages as read for a parent
  Future<void> markAllAsRead(String parentId) async {
    try {
      final batch = _firestore.batch();
      final unreadMessages = await _messagesCollection
          .where('parentId', isEqualTo: parentId)
          .where('isRead', isEqualTo: false)
          .get();
      
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('MessageService: Error marking all messages as read: $e');
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _messagesCollection.doc(messageId).delete();
    } catch (e) {
      debugPrint('MessageService: Error deleting message: $e');
    }
  }
}
