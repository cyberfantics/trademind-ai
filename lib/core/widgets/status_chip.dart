import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String label;

  const StatusChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    final Color color;

    if (lower.contains('tp') || lower.contains('profit') || lower.contains('win')) {
      color = AppColors.profit;
    } else if (lower.contains('sl') || lower.contains('loss')) {
      color = AppColors.loss;
    } else {
      color = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
