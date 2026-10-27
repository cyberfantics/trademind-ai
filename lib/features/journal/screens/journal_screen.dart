import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/journal_entry.dart';
import '../services/journal_service.dart';
import 'add_journal_entry_screen.dart';
import 'journal_detail_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final JournalService _service = JournalService();

  bool _isSummaryCollapsed = false;
  bool _isDeletingJournal = false;

  Future<void> _deleteAllJournal({
    required String userId,
    required int entriesCount,
  }) async {
    if (_isDeletingJournal) return;

    if (entriesCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No journal entries to delete.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete all journal?'),
          content: Text(
            'This will permanently delete all $entriesCount journal trade(s). This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.loss,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isDeletingJournal = true);

    try {
      await _deleteJournalCollection(userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All journal entries deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete journal: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeletingJournal = false);
      }
    }
  }

  Future<void> _deleteJournalCollection(String userId) async {
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('journal');

    while (true) {
      final snapshot = await collection.limit(450).get();

      if (snapshot.docs.isEmpty) break;

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login again.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trade Journal'),
        centerTitle: false,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isDeletingJournal
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddJournalEntryScreen(),
                  ),
                );
              },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Trade'),
      ),
      body: StreamBuilder<List<JournalEntry>>(
        stream: _service.watchJournal(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _LoadingView();
          }

          final entries = snapshot.data ?? [];

          if (entries.isEmpty) {
            return const EmptyState(
              title: 'No journal trades yet',
              subtitle: 'Save each trade with reason, emotion, notes and PnL.',
              icon: Icons.book_outlined,
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: _JournalStats(
                  entries: entries,
                  collapsed: _isSummaryCollapsed,
                  isDeletingJournal: _isDeletingJournal,
                  onToggleCollapsed: () {
                    setState(() => _isSummaryCollapsed = !_isSummaryCollapsed);
                  },
                  onDeleteAllJournal: () {
                    _deleteAllJournal(
                      userId: user.uid,
                      entriesCount: entries.length,
                    );
                  },
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _JournalCard(entry: entry);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JournalStats extends StatelessWidget {
  final List<JournalEntry> entries;
  final bool collapsed;
  final bool isDeletingJournal;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onDeleteAllJournal;

  const _JournalStats({
    required this.entries,
    required this.collapsed,
    required this.isDeletingJournal,
    required this.onToggleCollapsed,
    required this.onDeleteAllJournal,
  });

  int get wins => entries.where((entry) => entry.isWin).length;

  int get losses => entries.where((entry) => entry.isLoss).length;

  double get totalPnl {
    return entries.fold<double>(
      0,
      (sum, entry) => sum + entry.pnlAmount,
    );
  }

  double get winRate {
    if (entries.isEmpty) return 0;
    return (wins / entries.length) * 100;
  }

  String get summaryTitle {
    if (entries.length < 3) return 'Building your journal';
    if (totalPnl > 0 && winRate >= 60) return 'Strong journal performance';
    if (totalPnl > 0) return 'You are net positive';
    if (totalPnl < 0 && losses > wins) return 'Review losing trades';
    if (totalPnl < 0) return 'Risk needs attention';
    return 'Break-even performance';
  }

  String get summaryText {
    if (entries.length < 3) {
      return 'You have ${entries.length} trade${entries.length == 1 ? '' : 's'} saved. Add more trades to find stronger patterns.';
    }

    if (totalPnl > 0 && winRate >= 60) {
      return 'Your journal is showing a strong result. Keep repeating the setups that are working.';
    }

    if (totalPnl > 0) {
      return 'You are profitable overall. Now check which setups gave the cleanest wins.';
    }

    if (totalPnl < 0 && losses > wins) {
      return 'Losses are higher than wins. Review entries, emotions and risk before the next trade.';
    }

    if (totalPnl < 0) {
      return 'You are slightly negative. Reduce risk and check if one trade caused most of the loss.';
    }

    return 'You are close to break-even. Focus on better entries and avoid emotional trades.';
  }

  Color get summaryColor {
    if (totalPnl > 0) return AppColors.profit;
    if (totalPnl < 0) return AppColors.loss;
    return AppColors.primary;
  }

  IconData get summaryIcon {
    if (totalPnl > 0) return Icons.trending_up_rounded;
    if (totalPnl < 0) return Icons.warning_amber_rounded;
    return Icons.auto_stories_rounded;
  }

  String signedAmount(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF111827),
                  const Color(0xFF0B1220),
                  const Color(0xFF101827),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF8FBFF),
                  const Color(0xFFF2F7FF),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : AppColors.primary.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: summaryColor.withOpacity(isDark ? 0.18 : 0.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.28 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -55,
              right: -45,
              child: Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: summaryColor.withOpacity(0.13),
                ),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -55,
              child: Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.08),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(collapsed ? 14 : 18),
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: collapsed
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: _collapsedView(),
                secondChild: _expandedView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collapsedView() {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                summaryColor.withOpacity(0.95),
                summaryColor.withOpacity(0.70),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: summaryColor.withOpacity(0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            summaryIcon,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _MiniMetricBadge(
                label: 'Trades',
                value: entries.length,
                color: AppColors.primary,
              ),
              _MiniMetricBadge(
                label: 'Win',
                valueText: '${winRate.toStringAsFixed(1)}%',
                color: winRate >= 50 ? AppColors.profit : AppColors.loss,
              ),
              _MiniMetricBadge(
                label: 'PnL',
                valueText: signedAmount(totalPnl),
                color: totalPnl >= 0 ? AppColors.profit : AppColors.loss,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Expand summary',
          onPressed: onToggleCollapsed,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ],
    );
  }

  Widget _expandedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _HeroSummary(
                title: summaryTitle,
                subtitle: summaryText,
                color: summaryColor,
                icon: summaryIcon,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Minimize summary',
              onPressed: onToggleCollapsed,
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _PremiumStatBox(
                title: 'Trades',
                value: '${entries.length}',
                icon: Icons.receipt_long_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PremiumStatBox(
                title: 'Win Rate',
                value: '${winRate.toStringAsFixed(1)}%',
                icon: Icons.percent_rounded,
                color: winRate >= 50 ? AppColors.profit : AppColors.loss,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PremiumStatBox(
                title: 'Wins / Losses',
                value: '$wins / $losses',
                icon: Icons.balance_rounded,
                color: wins >= losses ? AppColors.profit : AppColors.loss,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PremiumStatBox(
                title: 'Total PnL',
                value: signedAmount(totalPnl),
                icon: totalPnl >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: totalPnl >= 0 ? AppColors.profit : AppColors.loss,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _DeleteJournalButton(
          disabled: entries.isEmpty || isDeletingJournal,
          loading: isDeletingJournal,
          count: entries.length,
          onTap: onDeleteAllJournal,
        ),
      ],
    );
  }
}

class _MiniMetricBadge extends StatelessWidget {
  final String label;
  final int? value;
  final String? valueText;
  final Color color;

  const _MiniMetricBadge({
    required this.label,
    this.value,
    this.valueText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textValue = valueText ?? '${value ?? 0}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Text(
        '$label $textValue',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _HeroSummary({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.95),
                  color.withOpacity(0.70),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumStatBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _PremiumStatBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.075),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.13)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteJournalButton extends StatelessWidget {
  final bool disabled;
  final bool loading;
  final int count;
  final VoidCallback onTap;

  const _DeleteJournalButton({
    required this.disabled,
    required this.loading,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: disabled ? AppColors.textMuted.withOpacity(0.08) : null,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: disabled
                ? null
                : LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.loss.withOpacity(0.95),
                      AppColors.loss.withOpacity(0.74),
                    ],
                  ),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: AppColors.loss.withOpacity(0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  Icons.delete_forever_rounded,
                  color: disabled ? AppColors.textMuted : Colors.white,
                  size: 19,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  loading
                      ? 'Deleting journal...'
                      : 'Delete all $count journal trades',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: disabled ? AppColors.textMuted : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final JournalEntry entry;

  const _JournalCard({required this.entry});

  String get dateText {
    if (entry.createdAt == null) return 'Unknown date';
    return DateFormat('dd MMM yyyy').format(entry.createdAt!);
  }

  String get setupText {
    final setup = entry.setup.trim();
    if (setup.isEmpty) return 'No setup added';
    return setup;
  }

  @override
  Widget build(BuildContext context) {
    final color = entry.pnlAmount >= 0 ? AppColors.profit : AppColors.loss;
    final isProfit = entry.pnlAmount >= 0;
    final signPercent = entry.pnlPercent >= 0 ? '+' : '';
    final signAmount = entry.pnlAmount >= 0 ? '+' : '';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JournalDetailScreen(entry: entry),
              ),
            );
          },
          child: AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: color.withOpacity(0.18),
                        ),
                      ),
                      child: Icon(
                        isProfit
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.pair,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${entry.side.toUpperCase()} • $dateText',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$signPercent${entry.pnlPercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: color,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$signAmount${entry.pnlAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withOpacity(0.035),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: AppColors.textMuted.withOpacity(0.06),
                    ),
                  ),
                  child: Text(
                    setupText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (entry.emotion.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.psychology_rounded,
                        color: AppColors.textMuted.withOpacity(0.70),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry.emotion.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textMuted.withOpacity(0.78),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading journal...',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;

  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: AppColors.loss.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.loss,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Could not load journal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
