import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ai_message.dart';

class AiChatHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('aiChats')
        .doc('journalCoach')
        .collection('messages');
  }

  Future<List<AiMessage>> getMessages({
    required String userId,
    int limit = 50,
  }) async {
    final snapshot = await _messagesRef(userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map(AiMessage.fromFirestore)
        .toList()
        .reversed
        .toList();
  }

  Future<AiMessage> saveMessage({
    required String userId,
    required AiMessage message,
  }) async {
    final cleanMessage = message.copyWith(status: 'sent');

    final doc = await _messagesRef(userId).add(
      cleanMessage.toFirestore(),
    );

    return cleanMessage.copyWith(id: doc.id);
  }

  Future<void> updateMessageText({
    required String userId,
    required String messageId,
    required String text,
  }) async {
    await _messagesRef(userId).doc(messageId).update({
      'text': text,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMessageStatus({
    required String userId,
    required String messageId,
    required String status,
  }) async {
    await _messagesRef(userId).doc(messageId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> togglePin({
    required String userId,
    required String messageId,
    required bool isPinned,
    String? category,
  }) async {
    await _messagesRef(userId).doc(messageId).update({
      'isPinned': isPinned,
      'category': category,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage({
    required String userId,
    required String messageId,
  }) async {
    await _messagesRef(userId).doc(messageId).delete();
  }

  Future<void> deleteAllMessages({
    required String userId,
  }) async {
    final snapshot = await _messagesRef(userId).get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<void> deleteTurnMessages({
    required String userId,
    required String turnId,
  }) async {
    final snapshot =
        await _messagesRef(userId).where('turnId', isEqualTo: turnId).get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<List<AiMessage>> getPinnedMessages({
    required String userId,
  }) async {
    final snapshot = await _messagesRef(userId)
        .where('isPinned', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs.map(AiMessage.fromFirestore).toList();
  }
}
