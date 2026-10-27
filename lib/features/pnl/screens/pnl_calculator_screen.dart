import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/pnl_calculator.dart';
import '../../../core/widgets/app_card.dart';

class PnlCalculatorScreen extends StatefulWidget {
  const PnlCalculatorScreen({super.key});

  @override
  State<PnlCalculatorScreen> createState() => _PnlCalculatorScreenState();
}

class _PnlCalculatorScreenState extends State<PnlCalculatorScreen> {
  final GlobalKey _shareImageKey = GlobalKey();
  final _pairController = TextEditingController(text: 'BTCUSDT');
  final _entryController = TextEditingController();
  final _exitController = TextEditingController();
  final _leverageController = TextEditingController(text: '1');
  final _sizeController = TextEditingController(text: '100');

  String _side = 'LONG';
  PnlResult _result = const PnlResult(pnlPercent: 0, pnlAmount: 0);

  bool get _hasResult {
    return _result.pnlPercent != 0 || _result.pnlAmount != 0;
  }

  bool get _isProfit {
    return _result.pnlAmount >= 0;
  }

  Color get _pnlColor {
    if (!_hasResult) return AppColors.textMuted;
    return _isProfit ? AppColors.profit : AppColors.loss;
  }

  @override
  void initState() {
    super.initState();

    _entryController.addListener(_onInputChanged);
    _exitController.addListener(_onInputChanged);
    _leverageController.addListener(_onInputChanged);
    _sizeController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (!mounted) return;

    setState(() {
      _result = _buildResult(showError: false) ??
          const PnlResult(
            pnlPercent: 0,
            pnlAmount: 0,
          );
    });
  }

  PnlResult? _buildResult({required bool showError}) {
    final entry = double.tryParse(_entryController.text.trim()) ?? 0;
    final exit = double.tryParse(_exitController.text.trim()) ?? 0;
    final leverage = double.tryParse(_leverageController.text.trim()) ?? 1;
    final size = double.tryParse(_sizeController.text.trim()) ?? 0;

    if (entry <= 0 || exit <= 0) {
      if (showError) {
        _showMessage('Enter valid entry and exit price.');
      }
      return null;
    }

    if (size <= 0) {
      if (showError) {
        _showMessage('Enter valid position size.');
      }
      return null;
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

    final result = _buildResult(showError: true);
    if (result == null) return;

    setState(() => _result = result);
  }

  Future<void> _share() async {
    FocusScope.of(context).unfocus();

    final result = _buildResult(showError: true);
    if (result == null) return;

    setState(() => _result = result);

    final pair = _pairController.text.trim().isEmpty
        ? 'BTCUSDT'
        : _pairController.text.trim().toUpperCase();

    try {
      // IMPORTANT: Load images before taking screenshot
      await precacheImage(
        const AssetImage('assets/images/logo.png'),
        context,
      );

      await precacheImage(
        const AssetImage('assets/images/whatsapp_qr.png'),
        context,
      );
    } catch (_) {
      // If asset is missing, the card will still use fallback icons.
    }

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (_) {
        return Material(
          type: MaterialType.transparency,
          child: IgnorePointer(
            child: Center(
              child: RepaintBoundary(
                key: _shareImageKey,
                child: SizedBox(
                  width: 390,
                  child: _PnlShareImageCard(
                    pair: pair,
                    side: _side,
                    result: result,
                    color: result.pnlAmount >= 0
                        ? AppColors.profit
                        : AppColors.loss,
                    isProfit: result.pnlAmount >= 0,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(overlayEntry);

    // IMPORTANT: wait extra frames so images finish painting
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 300));
    await WidgetsBinding.instance.endOfFrame;

    try {
      final boundary = _shareImageKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        overlayEntry.remove();
        _showMessage('Could not create share image.');
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        overlayEntry.remove();
        _showMessage('Could not create image file.');
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();

      final file = File(
        '${tempDir.path}/signalflow_pnl_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await file.writeAsBytes(pngBytes);

      overlayEntry.remove();

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'TradeMind AI PnL',
      );
    } catch (e) {
      overlayEntry.remove();
      _showMessage('Could not share image: $e');
    }
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

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PnL Calculator'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _PnlResultCard(
              result: _result,
              color: _pnlColor,
              hasResult: _hasResult,
              isProfit: _isProfit,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _calculate,
                    icon: const Icon(Icons.calculate_rounded),
                    label: const Text('Calculate PnL'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                        title: 'Trade Details',
                        subtitle:
                            'Enter your pair, side, entry and exit price.',
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
                            _result = _buildResult(showError: false) ??
                                const PnlResult(
                                  pnlPercent: 0,
                                  pnlAmount: 0,
                                );
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                const _InfoNote(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PnlResultCard extends StatelessWidget {
  final PnlResult result;
  final Color color;
  final bool hasResult;
  final bool isProfit;

  const _PnlResultCard({
    required this.result,
    required this.color,
    required this.hasResult,
    required this.isProfit,
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
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: color.withOpacity(0.16),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    !hasResult
                        ? Icons.calculate_rounded
                        : isProfit
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated PnL',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Live result updates while typing',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _signedPercent(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 44,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _signedAmount(),
                style: TextStyle(
                  color: color,
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
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
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
                  ? color.withOpacity(0.50)
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
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
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
  final String? suffixText;

  const _AppTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.suffixText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
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

class _InfoNote extends StatelessWidget {
  const _InfoNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.12),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This calculator is for educational use only. Always confirm fees, funding, slippage and exchange rules before trading.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PnlShareImageCard extends StatelessWidget {
  final String pair;
  final String side;
  final PnlResult result;
  final Color color;
  final bool isProfit;

  const _PnlShareImageCard({
    required this.pair,
    required this.side,
    required this.result,
    required this.color,
    required this.isProfit,
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
    final resultText = isProfit ? 'PROFIT' : 'LOSS';

    return Container(
      width: 390,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF10131A),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 54,
                  width: 54,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.show_chart_rounded,
                        color: color,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TradeMind AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'PnL Result Card',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: color.withOpacity(0.18),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '$pair  •  $side',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _signedPercent(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 54,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _signedAmount(),
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    resultText,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Image.asset(
                  'assets/images/whatsapp_qr.png',
                  height: 86,
                  width: 86,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      height: 86,
                      width: 86,
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        color: Colors.black,
                        size: 54,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join our WhatsApp Channel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Scan the QR code for updates, signals and trading education.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Educational only. Trade at your own risk.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
