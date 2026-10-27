import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/pnl_calculator.dart';
import '../../../core/widgets/app_card.dart';
import '../../signals/models/trade_signal.dart';
import '../services/journal_service.dart';

class AddJournalEntryScreen extends StatefulWidget {
  final TradeSignal? signal;

  const AddJournalEntryScreen({super.key, this.signal});

  @override
  State<AddJournalEntryScreen> createState() => _AddJournalEntryScreenState();
}

class _AddJournalEntryScreenState extends State<AddJournalEntryScreen> {
  final _service = JournalService();

  final _pairController = TextEditingController();
  final _entryController = TextEditingController();
  final _exitController = TextEditingController();
  final _leverageController = TextEditingController(text: '1');
  final _sizeController = TextEditingController(text: '100');
  final _setupController = TextEditingController();
  final _emotionController = TextEditingController();
  final _notesController = TextEditingController();

  String _side = 'LONG';
  PnlResult _result = const PnlResult(pnlPercent: 0, pnlAmount: 0);
  bool _isSaving = false;

  bool get _isProfit => _result.pnlAmount >= 0;

  Color get _pnlColor {
    if (_result.pnlAmount == 0 && _result.pnlPercent == 0) {
      return AppColors.textMuted;
    }
    return _isProfit ? AppColors.profit : AppColors.loss;
  }

  @override
  void initState() {
    super.initState();

    final signal = widget.signal;
    if (signal != null) {
      _pairController.text = signal.pair;
      _side = signal.side.toUpperCase();

      _entryController.text = signal.entryMin > 0
          ? signal.entryMin.toString()
          : signal.approxFillEntry.toString();

      if (signal.currentPrice > 0 &&
          signal.status.toLowerCase().contains('hit')) {
        _exitController.text = signal.currentPrice.toString();
      }

      if (signal.leverage > 0) {
        _leverageController.text = signal.leverage.toString();
      }

      final setupParts = <String>[
        if (signal.strategy.isNotEmpty) signal.strategy,
        if (signal.timeframe.isNotEmpty) 'TF: ${signal.timeframe}',
        if (signal.setupScore > 0)
          'Score: ${signal.setupScore}/${signal.setupScoreMax}',
      ];

      _setupController.text =
          setupParts.isEmpty ? 'Discord signal' : setupParts.join(' | ');

      if (signal.reason.isNotEmpty) {
        _notesController.text = signal.reason;
      }
    }

    _result = _buildPnlResult();

    _entryController.addListener(_onInputChanged);
    _exitController.addListener(_onInputChanged);
    _leverageController.addListener(_onInputChanged);
    _sizeController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (!mounted) return;
    setState(() => _result = _buildPnlResult());
  }

  PnlResult _buildPnlResult() {
    final entry = double.tryParse(_entryController.text.trim()) ?? 0;
    final exit = double.tryParse(_exitController.text.trim()) ?? 0;
    final leverage = double.tryParse(_leverageController.text.trim()) ?? 1;
    final size = double.tryParse(_sizeController.text.trim()) ?? 0;

    if (entry <= 0 || exit <= 0 || size <= 0) {
      return const PnlResult(pnlPercent: 0, pnlAmount: 0);
    }

    return PnlCalculator.calculate(
      side: _side,
      entryPrice: entry,
      exitPrice: exit,
      leverage: leverage <= 0 ? 1 : leverage,
      positionSize: size,
    );
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    setState(() => _result = _buildPnlResult());
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Please login first.');
      return;
    }

    final pair = _pairController.text.trim().toUpperCase();
    final entry = double.tryParse(_entryController.text.trim()) ?? 0;
    final exit = double.tryParse(_exitController.text.trim()) ?? 0;
    final leverage = double.tryParse(_leverageController.text.trim()) ?? 1;
    final size = double.tryParse(_sizeController.text.trim()) ?? 0;

    if (pair.isEmpty || entry <= 0 || exit <= 0) {
      _showMessage('Please enter pair, entry price and exit price.');
      return;
    }

    if (size <= 0) {
      _showMessage('Please enter a valid position size.');
      return;
    }

    final result = PnlCalculator.calculate(
      side: _side,
      entryPrice: entry,
      exitPrice: exit,
      leverage: leverage <= 0 ? 1 : leverage,
      positionSize: size,
    );

    setState(() {
      _isSaving = true;
      _result = result;
    });

    try {
      await _service.addEntry(
        userId: user.uid,
        signalId: widget.signal?.id,
        pair: pair,
        side: _side,
        entryPrice: entry,
        exitPrice: exit,
        leverage: leverage <= 0 ? 1 : leverage,
        positionSize: size,
        pnlPercent: result.pnlPercent,
        pnlAmount: result.pnlAmount,
        setup: _setupController.text.trim(),
        emotion: _emotionController.text.trim(),
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showMessage('Could not save journal entry: $e');
    }

    if (mounted) setState(() => _isSaving = false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _entryController.removeListener(_onInputChanged);
    _exitController.removeListener(_onInputChanged);
    _leverageController.removeListener(_onInputChanged);
    _sizeController.removeListener(_onInputChanged);

    _pairController.dispose();
    _entryController.dispose();
    _exitController.dispose();
    _leverageController.dispose();
    _sizeController.dispose();
    _setupController.dispose();
    _emotionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Journal Trade'),
        centerTitle: false,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Saving...' : 'Save Journal Entry'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          _PnlPreviewCard(
            result: _result,
            pnlColor: _pnlColor,
            isProfit: _isProfit,
            onCalculate: _calculate,
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  title: 'Trade Details',
                  subtitle: 'Enter your pair, direction and prices.',
                  icon: Icons.candlestick_chart_rounded,
                ),
                const SizedBox(height: 18),
                _AppTextField(
                  controller: _pairController,
                  label: 'Pair',
                  hint: 'Example BTCUSDT',
                  icon: Icons.currency_bitcoin_rounded,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 14),
                _SideSelector(
                  value: _side,
                  onChanged: (value) {
                    setState(() {
                      _side = value;
                      _result = _buildPnlResult();
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _AppTextField(
                        controller: _entryController,
                        label: 'Entry Price',
                        hint: '0.00',
                        icon: Icons.login_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AppTextField(
                        controller: _exitController,
                        label: 'Exit Price',
                        hint: '0.00',
                        icon: Icons.logout_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _AppTextField(
                        controller: _leverageController,
                        label: 'Leverage',
                        hint: '1',
                        icon: Icons.bolt_rounded,
                        suffixText: 'x',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AppTextField(
                        controller: _sizeController,
                        label: 'Position Size',
                        hint: '100',
                        icon: Icons.account_balance_wallet_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  title: 'Trade Notes',
                  subtitle: 'Write what happened and what you learned.',
                  icon: Icons.edit_note_rounded,
                ),
                const SizedBox(height: 18),
                _AppTextField(
                  controller: _setupController,
                  label: 'Setup / Strategy',
                  hint: 'Example EMA pullback, breakout, support retest',
                  icon: Icons.auto_graph_rounded,
                ),
                const SizedBox(height: 14),
                _AppTextField(
                  controller: _emotionController,
                  label: 'Emotion',
                  hint: 'Example calm, fear, revenge, confident',
                  icon: Icons.psychology_rounded,
                ),
                const SizedBox(height: 14),
                _AppTextField(
                  controller: _notesController,
                  label: 'Notes / What you learned',
                  hint: 'Write your mistake, lesson, or reason for exit...',
                  icon: Icons.notes_rounded,
                  minLines: 4,
                  maxLines: 7,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PnlPreviewCard extends StatelessWidget {
  final PnlResult result;
  final Color pnlColor;
  final bool isProfit;
  final VoidCallback onCalculate;

  const _PnlPreviewCard({
    required this.result,
    required this.pnlColor,
    required this.isProfit,
    required this.onCalculate,
  });

  String _signedPercent() {
    final sign = result.pnlPercent > 0 ? '+' : '';
    return '$sign${result.pnlPercent.toStringAsFixed(2)}%';
  }

  String _signedAmount() {
    final sign = result.pnlAmount > 0 ? '+' : '';
    return '$sign${result.pnlAmount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: pnlColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: pnlColor.withOpacity(0.16),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: pnlColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isProfit
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: pnlColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live PnL Preview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Updates automatically while typing',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Calculate',
                  onPressed: onCalculate,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              _signedPercent(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: pnlColor,
                fontSize: 42,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: pnlColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _signedAmount(),
                style: TextStyle(
                  color: pnlColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: AppColors.textMuted.withOpacity(0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: AppColors.textMuted,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SideSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SideSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SideOption(
            title: 'LONG',
            subtitle: 'Price goes up',
            icon: Icons.arrow_upward_rounded,
            color: AppColors.profit,
            selected: value == 'LONG',
            onTap: () => onChanged('LONG'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SideOption(
            title: 'SHORT',
            subtitle: 'Price goes down',
            icon: Icons.arrow_downward_rounded,
            color: AppColors.loss,
            selected: value == 'SHORT',
            onTap: () => onChanged('SHORT'),
          ),
        ),
      ],
    );
  }
}

class _SideOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SideOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? color.withOpacity(0.55)
                  : AppColors.textMuted.withOpacity(0.12),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? color : null,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int minLines;
  final int maxLines;
  final String? suffixText;

  const _AppTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.minLines = 1,
    this.maxLines = 1,
    this.suffixText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffixText,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.textMuted.withOpacity(0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.textMuted.withOpacity(0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
