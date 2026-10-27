import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/trade_signal.dart';
import '../services/closed_signals_journal_service.dart';
import '../services/signal_service.dart';
import '../widgets/signal_card.dart';
import 'signal_detail_screen.dart';

enum _SignalFilter {
  all,
  active,
  closed,
}

enum _ResultFilter {
  all,
  tp2,
  sl,
}

enum _SideFilter {
  all,
  long,
  short,
}

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  final _service = SignalService();
  final _closedSignalsJournalService = ClosedSignalsJournalService();

  _SignalFilter _filter = _SignalFilter.all;
  _ResultFilter _resultFilter = _ResultFilter.all;
  _SideFilter _sideFilter = _SideFilter.all;

  bool _isSummaryCollapsed = false;
  bool _isAddingClosedSignalsToJournal = false;

  String _signalText(TradeSignal signal) {
    return '${signal.statusLabel} ${signal.hitType} ${signal.lastUpdateRaw}'
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
  }

  bool _isTp2Hit(TradeSignal signal) {
    final text = _signalText(signal);
    final compactText = text.replaceAll(' ', '');

    return compactText.contains('tp2hit') ||
        compactText.contains('t2hit') ||
        RegExp(r'tp\s*2.*hit').hasMatch(text) ||
        RegExp(r'hit.*tp\s*2').hasMatch(text);
  }

  bool _isSlHit(TradeSignal signal) {
    final text = _signalText(signal);
    final compactText = text.replaceAll(' ', '');

    return compactText.contains('slhit') ||
        compactText.contains('protectedslhit') ||
        compactText.contains('stoplosshit') ||
        RegExp(r'\bsl\b.*hit').hasMatch(text) ||
        RegExp(r'hit.*\bsl\b').hasMatch(text) ||
        RegExp(r'stop\s*loss.*hit').hasMatch(text);
  }

  bool _isClosedSignal(TradeSignal signal) {
    final text = _signalText(signal);
    return text.contains('close') ||
        text.contains('closed') ||
        _isTp2Hit(signal) ||
        _isSlHit(signal);
  }

  bool _isLongSignal(TradeSignal signal) {
    return signal.side.toUpperCase().contains('LONG');
  }

  bool _isShortSignal(TradeSignal signal) {
    return signal.side.toUpperCase().contains('SHORT');
  }

  List<TradeSignal> _filteredSignals(List<TradeSignal> signals) {
    return signals.where((signal) {
      final isClosed = _isClosedSignal(signal);

      if (_filter == _SignalFilter.active && isClosed) return false;
      if (_filter == _SignalFilter.closed && !isClosed) return false;

      if (_resultFilter == _ResultFilter.tp2 && !_isTp2Hit(signal)) {
        return false;
      }

      if (_resultFilter == _ResultFilter.sl && !_isSlHit(signal)) {
        return false;
      }

      if (_sideFilter == _SideFilter.long && !_isLongSignal(signal)) {
        return false;
      }

      if (_sideFilter == _SideFilter.short && !_isShortSignal(signal)) {
        return false;
      }

      return true;
    }).toList();
  }

  void _changeMainFilter(_SignalFilter filter) {
    setState(() {
      _filter = filter;

      if (filter != _SignalFilter.closed) {
        _resultFilter = _ResultFilter.all;
      }
    });
  }

  void _changeResultFilter(_ResultFilter filter) {
    setState(() {
      if (_resultFilter == filter && filter != _ResultFilter.all) {
        _resultFilter = _ResultFilter.all;
        return;
      }

      _resultFilter = filter;

      if (filter != _ResultFilter.all) {
        _filter = _SignalFilter.closed;
      }
    });
  }

  void _changeSideFilter(_SideFilter filter) {
    setState(() {
      if (_sideFilter == filter) {
        _sideFilter = _SideFilter.all;
      } else {
        _sideFilter = filter;
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _filter = _SignalFilter.all;
      _resultFilter = _ResultFilter.all;
      _sideFilter = _SideFilter.all;
    });
  }

  Future<void> _addAllClosedSignalsToJournal(List<TradeSignal> signals) async {
    if (_isAddingClosedSignalsToJournal) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final closedSignals = signals.where(_isClosedSignal).toList();

    if (closedSignals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No closed signals found to add.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add closed signals?'),
          content: Text(
            'This will add ${closedSignals.length} closed signal(s) into your journal. Existing imported signals will be skipped.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.book_rounded),
              label: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _isAddingClosedSignalsToJournal = true);

    try {
      final result =
          await _closedSignalsJournalService.addClosedSignalsToJournal(
        userId: user.uid,
        signals: closedSignals,
        isTp2Hit: _isTp2Hit,
        isSlHit: _isSlHit,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Journal updated: ${result.added} added, ${result.skipped} skipped.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add signals to journal: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingClosedSignalsToJournal = false);
      }
    }
  }

  String get _emptyFilteredMessage {
    if (_resultFilter == _ResultFilter.tp2) return 'No TP2 trades found.';
    if (_resultFilter == _ResultFilter.sl) return 'No SL trades found.';
    if (_sideFilter == _SideFilter.long) return 'No long trades found.';
    if (_sideFilter == _SideFilter.short) return 'No short trades found.';
    if (_filter == _SignalFilter.active) return 'No active trades found.';
    if (_filter == _SignalFilter.closed) return 'No closed trades found.';
    return 'Try changing your filters.';
  }

  Widget _filteredEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_off_rounded,
                color: AppColors.textMuted.withOpacity(0.8),
                size: 34,
              ),
              const SizedBox(height: 10),
              const Text(
                'No signals found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _emptyFilteredMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signalsList(List<TradeSignal> visibleSignals) {
    if (visibleSignals.isEmpty) {
      return _filteredEmptyView();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: visibleSignals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final signal = visibleSignals[index];

        return SignalCard(
          signal: signal,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SignalDetailScreen(signal: signal),
              ),
            );
          },
        );
      },
    );
  }

  Widget _signalsBody(List<TradeSignal> signals) {
    final visibleSignals = _filteredSignals(signals);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: _SignalsSummaryCard(
            signals: signals,
            collapsed: _isSummaryCollapsed,
            selectedFilter: _filter,
            selectedResultFilter: _resultFilter,
            selectedSideFilter: _sideFilter,
            isClosedSignal: _isClosedSignal,
            isTp2Hit: _isTp2Hit,
            isSlHit: _isSlHit,
            isAddingClosedSignalsToJournal: _isAddingClosedSignalsToJournal,
            onToggleCollapsed: () {
              setState(() => _isSummaryCollapsed = !_isSummaryCollapsed);
            },
            onFilterChanged: _changeMainFilter,
            onResultFilterChanged: _changeResultFilter,
            onSideFilterChanged: _changeSideFilter,
            onResetFilters: _resetFilters,
            onAddClosedSignalsToJournal: () =>
                _addAllClosedSignalsToJournal(signals),
          ),
        ),
        Expanded(
          child: _signalsList(visibleSignals),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Signals'),
        centerTitle: false,
      ),
      body: StreamBuilder<List<TradeSignal>>(
        stream: _service.watchSignals(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _LoadingView();
          }

          final signals = snapshot.data ?? [];

          if (signals.isEmpty) {
            return const EmptyState(
              title: 'No signals yet',
              subtitle:
                  'When your Discord bot sends a signal, it will appear here.',
              icon: Icons.candlestick_chart_rounded,
            );
          }

          return _signalsBody(signals);
        },
      ),
    );
  }
}

class _SignalsSummaryCard extends StatelessWidget {
  final List<TradeSignal> signals;
  final bool collapsed;

  final _SignalFilter selectedFilter;
  final _ResultFilter selectedResultFilter;
  final _SideFilter selectedSideFilter;

  final bool Function(TradeSignal signal) isClosedSignal;
  final bool Function(TradeSignal signal) isTp2Hit;
  final bool Function(TradeSignal signal) isSlHit;

  final bool isAddingClosedSignalsToJournal;

  final VoidCallback onToggleCollapsed;
  final ValueChanged<_SignalFilter> onFilterChanged;
  final ValueChanged<_ResultFilter> onResultFilterChanged;
  final ValueChanged<_SideFilter> onSideFilterChanged;
  final VoidCallback onResetFilters;
  final VoidCallback onAddClosedSignalsToJournal;

  const _SignalsSummaryCard({
    required this.signals,
    required this.collapsed,
    required this.selectedFilter,
    required this.selectedResultFilter,
    required this.selectedSideFilter,
    required this.isClosedSignal,
    required this.isTp2Hit,
    required this.isSlHit,
    required this.isAddingClosedSignalsToJournal,
    required this.onToggleCollapsed,
    required this.onFilterChanged,
    required this.onResultFilterChanged,
    required this.onSideFilterChanged,
    required this.onResetFilters,
    required this.onAddClosedSignalsToJournal,
  });

  int get activeCount => signals.where((s) => !isClosedSignal(s)).length;
  int get closedCount => signals.where(isClosedSignal).length;
  int get tp2Count => signals.where(isTp2Hit).length;
  int get slCount => signals.where(isSlHit).length;

  int get longCount {
    return signals.where((s) => s.side.toUpperCase().contains('LONG')).length;
  }

  int get shortCount {
    return signals.where((s) => s.side.toUpperCase().contains('SHORT')).length;
  }

  bool get hasActiveFilters {
    return selectedFilter != _SignalFilter.all ||
        selectedResultFilter != _ResultFilter.all ||
        selectedSideFilter != _SideFilter.all;
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
                  const Color(0xFFF7FAFF),
                  const Color(0xFFF1F6FF),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : AppColors.primary.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(isDark ? 0.18 : 0.13),
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
                  color: AppColors.primary.withOpacity(0.13),
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
                  color: AppColors.profit.withOpacity(0.08),
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
        _PremiumIcon(size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _MiniMetricBadge(
                label: 'Active',
                value: activeCount,
                color: AppColors.profit,
              ),
              _MiniMetricBadge(
                label: 'Closed',
                value: closedCount,
                color: AppColors.loss,
              ),
              _MiniMetricBadge(
                label: 'Total',
                value: signals.length,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        _GlassIconButton(
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: onToggleCollapsed,
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
            _PremiumIcon(size: 46),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Signals Dashboard',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Clean view for trades, filters and journal',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _GlassIconButton(
              icon: Icons.keyboard_arrow_up_rounded,
              onTap: onToggleCollapsed,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _PremiumStatTile(
                title: 'Active',
                value: activeCount,
                icon: Icons.flash_on_rounded,
                color: AppColors.profit,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PremiumStatTile(
                title: 'Closed',
                value: closedCount,
                icon: Icons.lock_rounded,
                color: AppColors.loss,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PremiumStatTile(
                title: 'Total',
                value: signals.length,
                icon: Icons.stacked_line_chart_rounded,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionLabel('Main Filters'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PremiumFilterChip(
              label: 'All',
              count: signals.length,
              selected: selectedFilter == _SignalFilter.all,
              onTap: () => onFilterChanged(_SignalFilter.all),
            ),
            _PremiumFilterChip(
              label: 'Active',
              count: activeCount,
              selected: selectedFilter == _SignalFilter.active,
              color: AppColors.profit,
              onTap: () => onFilterChanged(_SignalFilter.active),
            ),
            _PremiumFilterChip(
              label: 'Closed',
              count: closedCount,
              selected: selectedFilter == _SignalFilter.closed,
              color: AppColors.loss,
              onTap: () => onFilterChanged(_SignalFilter.closed),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _SectionLabel('Smart Filters'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PremiumFilterChip(
              label: 'Long',
              count: longCount,
              selected: selectedSideFilter == _SideFilter.long,
              color: AppColors.profit,
              icon: Icons.north_rounded,
              onTap: () => onSideFilterChanged(_SideFilter.long),
            ),
            _PremiumFilterChip(
              label: 'Short',
              count: shortCount,
              selected: selectedSideFilter == _SideFilter.short,
              color: AppColors.loss,
              icon: Icons.south_rounded,
              onTap: () => onSideFilterChanged(_SideFilter.short),
            ),
            _PremiumFilterChip(
              label: 'TP2',
              count: tp2Count,
              selected: selectedResultFilter == _ResultFilter.tp2,
              color: AppColors.profit,
              icon: Icons.flag_rounded,
              onTap: () => onResultFilterChanged(_ResultFilter.tp2),
            ),
            _PremiumFilterChip(
              label: 'SL',
              count: slCount,
              selected: selectedResultFilter == _ResultFilter.sl,
              color: AppColors.loss,
              icon: Icons.warning_amber_rounded,
              onTap: () => onResultFilterChanged(_ResultFilter.sl),
            ),
            if (hasActiveFilters)
              _PremiumFilterChip(
                label: 'Reset',
                count: 0,
                selected: false,
                showCount: false,
                icon: Icons.restart_alt_rounded,
                onTap: onResetFilters,
              ),
          ],
        ),
        const SizedBox(height: 16),
        _JournalActionButton(
          disabled: closedCount == 0 || isAddingClosedSignalsToJournal,
          loading: isAddingClosedSignalsToJournal,
          closedCount: closedCount,
          onTap: onAddClosedSignalsToJournal,
        ),
      ],
    );
  }
}

class _PremiumIcon extends StatelessWidget {
  final double size;

  const _PremiumIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.95),
            AppColors.primary.withOpacity(0.72),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.candlestick_chart_rounded,
        color: Colors.white,
        size: 25,
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 38,
          width: 38,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: AppColors.textMuted.withOpacity(0.88),
        fontSize: 10.5,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _PremiumStatTile extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _PremiumStatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.075),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.13)),
      ),
      child: Column(
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 7),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color? color;
  final IconData? icon;
  final bool showCount;
  final VoidCallback onTap;

  const _PremiumFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;

    return Material(
      color: selected ? activeColor.withOpacity(0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? activeColor.withOpacity(0.52)
                  : AppColors.textMuted.withOpacity(0.13),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? activeColor : AppColors.textMuted,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? activeColor : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (showCount) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? activeColor.withOpacity(0.14)
                        : AppColors.textMuted.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? activeColor : AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalActionButton extends StatelessWidget {
  final bool disabled;
  final bool loading;
  final int closedCount;
  final VoidCallback onTap;

  const _JournalActionButton({
    required this.disabled,
    required this.loading,
    required this.closedCount,
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
                      AppColors.primary.withOpacity(0.95),
                      AppColors.primary.withOpacity(0.76),
                    ],
                  ),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.22),
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
                  Icons.auto_stories_rounded,
                  color: disabled ? AppColors.textMuted : Colors.white,
                  size: 19,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  loading
                      ? 'Adding closed trades...'
                      : 'Add $closedCount closed trades to journal',
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

class _MiniMetricBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniMetricBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
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
              'Loading live signals...',
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
                'Could not load signals',
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
