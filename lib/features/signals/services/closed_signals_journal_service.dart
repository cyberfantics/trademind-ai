import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trade_signal.dart';

class ClosedSignalsJournalResult {
  final int added;
  final int skipped;

  const ClosedSignalsJournalResult({
    required this.added,
    required this.skipped,
  });
}

class ClosedSignalsJournalService {
  final FirebaseFirestore _db;

  ClosedSignalsJournalService({
    FirebaseFirestore? db,
  }) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _journalCollection(String userId) {
    return _db.collection('users').doc(userId).collection('journal');
  }

  Future<ClosedSignalsJournalResult> addClosedSignalsToJournal({
    required String userId,
    required List<TradeSignal> signals,
    required bool Function(TradeSignal signal) isTp2Hit,
    required bool Function(TradeSignal signal) isSlHit,
  }) async {
    if (signals.isEmpty) {
      return const ClosedSignalsJournalResult(added: 0, skipped: 0);
    }

    int added = 0;
    int skipped = 0;

    WriteBatch batch = _db.batch();
    int pendingWrites = 0;

    for (final signal in signals) {
      final docId = _journalDocId(signal);
      final docRef = _journalCollection(userId).doc(docId);

      final existing = await docRef.get();

      if (existing.exists) {
        skipped++;
        continue;
      }

      final data = _signalToJournalMap(
        signal: signal,
        isTp2Hit: isTp2Hit(signal),
        isSlHit: isSlHit(signal),
      );

      batch.set(docRef, data);

      added++;
      pendingWrites++;

      if (pendingWrites >= 450) {
        await batch.commit();
        batch = _db.batch();
        pendingWrites = 0;
      }
    }

    if (pendingWrites > 0) {
      await batch.commit();
    }

    return ClosedSignalsJournalResult(
      added: added,
      skipped: skipped,
    );
  }

  String _journalDocId(TradeSignal signal) {
    final raw =
        '${signal.pair}_${signal.side}_${signal.createdAt?.millisecondsSinceEpoch ?? signal.signalTitle}_${signal.statusLabel}_${signal.hitType}';

    final cleaned = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return 'signal_$cleaned';
  }

  Map<String, dynamic> _signalToJournalMap({
    required TradeSignal signal,
    required bool isTp2Hit,
    required bool isSlHit,
  }) {
    final entryPrice = _numberFromText(signal.entryText);
    final exitPrice = _exitPrice(signal: signal, isTp2Hit: isTp2Hit);

    final leverage = signal.leverage > 0 ? signal.leverage.toDouble() : 1.0;
    final positionSize = signal.qty > 0 ? signal.qty.toDouble() : 0.0;

    final pnlPercent = _pnlPercent(
      side: signal.side,
      entry: entryPrice,
      exit: exitPrice,
      leverage: leverage,
    );

    final pnlAmount =
        positionSize > 0 ? (positionSize * pnlPercent / 100) : 0.0;

    final isWin = pnlPercent > 0 || isTp2Hit;
    final isLoss = pnlPercent < 0 || (isSlHit && !isTp2Hit);

    final createdAt =
        signal.statusUpdatedAt ?? signal.createdAt ?? DateTime.now();

    return {
      'pair': signal.pair,
      'side': signal.side,
      'entryPrice': entryPrice,
      'exitPrice': exitPrice,
      'leverage': leverage,
      'positionSize': positionSize,
      'pnlPercent': pnlPercent,
      'pnlAmount': pnlAmount,
      'isWin': isWin,
      'isLoss': isLoss,
      'setup':
          signal.strategy.isNotEmpty ? signal.strategy : signal.signalTitle,
      'emotion': 'Auto imported',
      'notes':
          'Imported from closed signal.\n\nStatus: ${signal.statusLabel}\nHit: ${signal.hitType}\nReason: ${signal.reason}\nLatest update: ${signal.lastUpdateRaw}',
      'source': 'closed_signal_bulk_import',
      'signalPair': signal.pair,
      'signalStatus': signal.statusLabel,
      'signalHitType': signal.hitType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  double _exitPrice({
    required TradeSignal signal,
    required bool isTp2Hit,
  }) {
    if (signal.tpHitPrice > 0) {
      return signal.tpHitPrice.toDouble();
    }

    if (signal.currentPrice > 0) {
      return signal.currentPrice.toDouble();
    }

    if (isTp2Hit && signal.takeProfits.isNotEmpty) {
      final tp2Text = signal.takeProfits.length >= 2
          ? signal.takeProfits[1].toString()
          : signal.takeProfits.last.toString();

      final tp2 = _numberFromText(tp2Text);

      if (tp2 > 0) return tp2;
    }

    if (signal.protectedStopLoss > 0) {
      return signal.protectedStopLoss.toDouble();
    }

    if (signal.stopLoss > 0) {
      return signal.stopLoss.toDouble();
    }

    return 0;
  }

  double _numberFromText(String value) {
    final cleaned = value.replaceAll(',', '');
    final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(cleaned);

    if (match == null) return 0;

    return double.tryParse(match.group(0) ?? '') ?? 0;
  }

  double _pnlPercent({
    required String side,
    required double entry,
    required double exit,
    required double leverage,
  }) {
    if (entry <= 0 || exit <= 0) return 0;

    final upperSide = side.toUpperCase();

    final rawPercent = upperSide.contains('SHORT')
        ? ((entry - exit) / entry) * 100
        : ((exit - entry) / entry) * 100;

    return rawPercent * leverage;
  }
}
