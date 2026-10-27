import 'package:cloud_firestore/cloud_firestore.dart';

class TradeSignal {
  final String id;
  final int signalNumber;
  final String pair;
  final String side;
  final String timeframe;
  final double entryMin;
  final double entryMax;
  final double stopLoss;
  final List<double> takeProfits;
  final String status;
  final double currentPrice;
  final String source;
  final String rawMessage;
  final String lastUpdateRaw;

  final int setupScore;
  final int setupScoreMax;
  final String reason;
  final String strategy;
  final Map<String, dynamic> backtest;

  final bool liveAutoTradePlaced;
  final String entrySide;
  final double qty;
  final double approxFillEntry;
  final double leverage;
  final String margin;
  final bool exchangeProtection;

  final String hitType;
  final int hitTakeProfit;
  final double tpHitPrice;
  final double protectedStopLoss;
  final bool tradeStillRunning;
  final bool protectionRefreshed;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? statusUpdatedAt;
  final DateTime? closedAt;

  const TradeSignal({
    required this.id,
    required this.signalNumber,
    required this.pair,
    required this.side,
    required this.timeframe,
    required this.entryMin,
    required this.entryMax,
    required this.stopLoss,
    required this.takeProfits,
    required this.status,
    required this.currentPrice,
    required this.source,
    required this.rawMessage,
    required this.lastUpdateRaw,
    required this.setupScore,
    required this.setupScoreMax,
    required this.reason,
    required this.strategy,
    required this.backtest,
    required this.liveAutoTradePlaced,
    required this.entrySide,
    required this.qty,
    required this.approxFillEntry,
    required this.leverage,
    required this.margin,
    required this.exchangeProtection,
    required this.hitType,
    required this.hitTakeProfit,
    required this.tpHitPrice,
    required this.protectedStopLoss,
    required this.tradeStillRunning,
    required this.protectionRefreshed,
    required this.createdAt,
    required this.updatedAt,
    required this.statusUpdatedAt,
    required this.closedAt,
  });

  factory TradeSignal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TradeSignal(
      id: doc.id,
      signalNumber: _toInt(data['signalNumber']),
      pair: (data['pair'] ?? 'UNKNOWN').toString(),
      side: (data['side'] ?? 'LONG').toString(),
      timeframe: (data['timeframe'] ?? '').toString(),
      entryMin: _toDouble(data['entryMin']),
      entryMax: _toDouble(data['entryMax']),
      stopLoss: _toDouble(data['stopLoss']),
      takeProfits: List<dynamic>.from(data['takeProfits'] ?? [])
          .map(_toDouble)
          .where((value) => value > 0)
          .toList(),
      status: (data['status'] ?? 'active').toString(),
      currentPrice: _toDouble(data['currentPrice']),
      source: (data['source'] ?? 'manual').toString(),
      rawMessage: (data['rawMessage'] ?? '').toString(),
      lastUpdateRaw: (data['lastUpdateRaw'] ?? '').toString(),
      setupScore: _toInt(data['setupScore']),
      setupScoreMax: _toInt(data['setupScoreMax'], fallback: 100),
      reason: (data['reason'] ?? '').toString(),
      strategy: (data['strategy'] ?? '').toString(),
      backtest: Map<String, dynamic>.from(data['backtest'] ?? {}),
      liveAutoTradePlaced: _toBool(data['liveAutoTradePlaced']),
      entrySide: (data['entrySide'] ?? '').toString(),
      qty: _toDouble(data['qty']),
      approxFillEntry: _toDouble(data['approxFillEntry']),
      leverage: _toDouble(data['leverage']),
      margin: (data['margin'] ?? '').toString(),
      exchangeProtection: _toBool(data['exchangeProtection']),
      hitType: (data['hitType'] ?? '').toString(),
      hitTakeProfit: _toInt(data['hitTakeProfit']),
      tpHitPrice: _toDouble(data['tpHitPrice']),
      protectedStopLoss: _toDouble(data['protectedStopLoss']),
      tradeStillRunning: _toBool(data['tradeStillRunning']),
      protectionRefreshed: _toBool(data['protectionRefreshed']),
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
      statusUpdatedAt: _toDate(data['statusUpdatedAt']),
      closedAt: _toDate(data['closedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'signalNumber': signalNumber,
      'pair': pair.toUpperCase(),
      'side': side.toUpperCase(),
      'timeframe': timeframe,
      'entryMin': entryMin,
      'entryMax': entryMax,
      'stopLoss': stopLoss,
      'takeProfits': takeProfits,
      'status': status,
      'currentPrice': currentPrice,
      'source': source,
      'rawMessage': rawMessage,
      'lastUpdateRaw': lastUpdateRaw,
      'setupScore': setupScore,
      'setupScoreMax': setupScoreMax,
      'reason': reason,
      'strategy': strategy,
      'backtest': backtest,
      'liveAutoTradePlaced': liveAutoTradePlaced,
      'entrySide': entrySide,
      'qty': qty,
      'approxFillEntry': approxFillEntry,
      'leverage': leverage,
      'margin': margin,
      'exchangeProtection': exchangeProtection,
      'hitType': hitType,
      'hitTakeProfit': hitTakeProfit,
      'tpHitPrice': tpHitPrice,
      'protectedStopLoss': protectedStopLoss,
      'tradeStillRunning': tradeStillRunning,
      'protectionRefreshed': protectionRefreshed,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String get signalTitle {
    if (signalNumber > 0) return '#$signalNumber | $pair';
    return pair;
  }

  String get entryText {
    if (entryMin <= 0) return 'Waiting';
    if (entryMax <= 0 || entryMax == entryMin) return _formatNumber(entryMin);
    return '${_formatNumber(entryMin)} - ${_formatNumber(entryMax)}';
  }

  String get statusLabel {
    final lower = status.toLowerCase();
    if (lower == 'sl_hit') return 'SL HIT';
    final tpMatch = RegExp(r'tp(\d+)_hit').firstMatch(lower);
    if (tpMatch != null) return 'TP${tpMatch.group(1)} HIT';
    if (lower == 'active') return 'ACTIVE';
    return status.replaceAll('_', ' ').toUpperCase();
  }

  bool get isClosed => status.toLowerCase().contains('sl') || closedAt != null;
  bool get hasHitTp => hitTakeProfit > 0 || status.toLowerCase().contains('tp');

  String get backtestSummary {
    if (backtest.isEmpty) return '';
    final trades = _toInt(backtest['trades']);
    final winRate = _toDouble(backtest['winRate']);
    final pf = _toDouble(backtest['profitFactor']);
    final totalR = _toDouble(backtest['totalR']);
    final avgR = _toDouble(backtest['avgR']);
    final maxLs = _toInt(backtest['maxLosingStreak']);
    final parts = <String>[];
    if (trades > 0) parts.add('$trades trades');
    if (winRate > 0) parts.add('WR ${winRate.toStringAsFixed(1)}%');
    if (pf > 0) parts.add('PF ${pf.toStringAsFixed(2)}');
    if (totalR != 0) parts.add('Total ${totalR.toStringAsFixed(2)}R');
    if (avgR != 0) parts.add('Avg ${avgR.toStringAsFixed(2)}R');
    if (maxLs > 0) parts.add('Max LS $maxLs');
    return parts.join(' • ');
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? 0;
    return 0;
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
