import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../models/trade_signal.dart';

class SignalCard extends StatelessWidget {
  final TradeSignal signal;
  final VoidCallback onTap;

  const SignalCard({
    super.key,
    required this.signal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLong = signal.side.toUpperCase() == 'LONG';
    final sideColor = isLong ? AppColors.profit : AppColors.loss;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    signal.signalTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sideColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    signal.side.toUpperCase(),
                    style: TextStyle(color: sideColor, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(label: signal.statusLabel),
                if (signal.timeframe.isNotEmpty) _MiniChip(label: signal.timeframe),
                if (signal.setupScore > 0) _MiniChip(label: 'Score ${signal.setupScore}/${signal.setupScoreMax}'),
                if (signal.liveAutoTradePlaced) const _MiniChip(label: 'Auto-trade'),
              ],
            ),
            const SizedBox(height: 13),
            Text('Entry: ${signal.entryText}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 5),
            Text('SL: ${signal.stopLoss}', style: const TextStyle(color: AppColors.loss)),
            const SizedBox(height: 5),
            Text('TP: ${signal.takeProfits.join(', ')}', style: const TextStyle(color: AppColors.profit)),
            if (signal.currentPrice > 0) ...[
              const SizedBox(height: 5),
              Text('Current: ${signal.currentPrice}', style: const TextStyle(color: AppColors.textMuted)),
            ],
            const SizedBox(height: 13),
            Row(
              children: [
                if (signal.strategy.isNotEmpty)
                  Expanded(
                    child: Text(
                      signal.strategy,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                else
                  const Spacer(),
                Text(
                  signal.createdAt == null
                      ? ''
                      : DateFormat('dd MMM, HH:mm').format(signal.createdAt!),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;

  const _MiniChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
