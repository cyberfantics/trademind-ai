import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/journal_entry.dart';

class JournalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _journalRef(String userId) {
    return _db.collection('users').doc(userId).collection('journal');
  }

  Stream<List<JournalEntry>> watchJournal(String userId) {
    return _journalRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(JournalEntry.fromDoc).toList());
  }


  Future<List<JournalEntry>> getRecentJournal({
    required String userId,
    int limit = 50,
  }) async {
    final snapshot = await _journalRef(userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map(JournalEntry.fromDoc).toList();
  }

  Future<void> addEntry({
    required String userId,
    String? signalId,
    required String pair,
    required String side,
    required double entryPrice,
    required double exitPrice,
    required double leverage,
    required double positionSize,
    required double pnlPercent,
    required double pnlAmount,
    required String setup,
    required String emotion,
    required String notes,
  }) async {
    await _journalRef(userId).add({
      'userId': userId,
      'signalId': signalId,
      'pair': pair.toUpperCase(),
      'side': side.toUpperCase(),
      'entryPrice': entryPrice,
      'exitPrice': exitPrice,
      'leverage': leverage,
      'positionSize': positionSize,
      'pnlPercent': pnlPercent,
      'pnlAmount': pnlAmount,
      'setup': setup,
      'emotion': emotion,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEntry(String userId, String entryId) async {
    await _journalRef(userId).doc(entryId).delete();
  }
}
