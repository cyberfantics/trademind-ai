import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntry {
  final String id;
  final String userId;
  final String? signalId;
  final String pair;
  final String side;
  final double entryPrice;
  final double exitPrice;
  final double leverage;
  final double positionSize;
  final double pnlPercent;
  final double pnlAmount;
  final String setup;
  final String emotion;
  final String notes;
  final DateTime? createdAt;

  const JournalEntry({
    required this.id,
    required this.userId,
    required this.signalId,
    required this.pair,
    required this.side,
    required this.entryPrice,
    required this.exitPrice,
    required this.leverage,
    required this.positionSize,
    required this.pnlPercent,
    required this.pnlAmount,
    required this.setup,
    required this.emotion,
    required this.notes,
    required this.createdAt,
  });

  bool get isWin => pnlAmount > 0;
  bool get isLoss => pnlAmount < 0;

  factory JournalEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return JournalEntry(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      signalId: data['signalId']?.toString(),
      pair: (data['pair'] ?? 'UNKNOWN').toString(),
      side: (data['side'] ?? 'LONG').toString(),
      entryPrice: _toDouble(data['entryPrice']),
      exitPrice: _toDouble(data['exitPrice']),
      leverage: _toDouble(data['leverage']),
      positionSize: _toDouble(data['positionSize']),
      pnlPercent: _toDouble(data['pnlPercent']),
      pnlAmount: _toDouble(data['pnlAmount']),
      setup: (data['setup'] ?? '').toString(),
      emotion: (data['emotion'] ?? '').toString(),
      notes: (data['notes'] ?? '').toString(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? 0;
    return 0;
  }
}
