class PnlResult {
  final double pnlPercent;
  final double pnlAmount;

  const PnlResult({required this.pnlPercent, required this.pnlAmount});
}

class PnlCalculator {
  static PnlResult calculate({
    required String side,
    required double entryPrice,
    required double exitPrice,
    required double leverage,
    required double positionSize,
  }) {
    if (entryPrice <= 0 || exitPrice <= 0 || leverage <= 0) {
      return const PnlResult(pnlPercent: 0, pnlAmount: 0);
    }

    final normalizedSide = side.toUpperCase();
    final rawPercent = normalizedSide == 'SHORT'
        ? ((entryPrice - exitPrice) / entryPrice) * 100
        : ((exitPrice - entryPrice) / entryPrice) * 100;

    final pnlPercent = rawPercent * leverage;
    final pnlAmount = positionSize * (pnlPercent / 100);

    return PnlResult(pnlPercent: pnlPercent, pnlAmount: pnlAmount);
  }
}
