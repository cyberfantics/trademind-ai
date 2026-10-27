import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trade_signal.dart';

class SignalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<TradeSignal>> watchSignals() {
    return _db
        .collection('signals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(TradeSignal.fromDoc).toList());
  }

  Future<void> createManualSignal({
    required String pair,
    required String side,
    required double entryMin,
    required double entryMax,
    required double stopLoss,
    required List<double> takeProfits,
  }) async {
    await _db.collection('signals').add({
      'pair': pair.toUpperCase(),
      'side': side.toUpperCase(),
      'entryMin': entryMin,
      'entryMax': entryMax,
      'stopLoss': stopLoss,
      'takeProfits': takeProfits,
      'status': 'active',
      'source': 'admin',
      'rawMessage': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStatus(String signalId, String status) async {
    await _db.collection('signals').doc(signalId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
