import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../../journal/screens/add_journal_entry_screen.dart';
import '../models/trade_signal.dart';

class SignalDetailScreen extends StatefulWidget {
  final TradeSignal signal;

  const SignalDetailScreen({
    super.key,
    required this.signal,
  });

  @override
  State<SignalDetailScreen> createState() => _SignalDetailScreenState();
}

class _SignalDetailScreenState extends State<SignalDetailScreen> {
  final GlobalKey _shareImageKey = GlobalKey();

  TradeSignal get signal => widget.signal;

  Color get _sideColor {
    final side = signal.side.toUpperCase();
    return side.contains('SHORT') ? AppColors.loss : AppColors.profit;
  }

  String get _createdDate {
    if (signal.createdAt == null) return 'Unknown';
    return DateFormat('dd MMM yyyy, hh:mm a').format(signal.createdAt!);
  }

  String get _updatedDate {
    if (signal.statusUpdatedAt == null) return 'Unknown';
    return DateFormat('dd MMM yyyy, hh:mm a').format(signal.statusUpdatedAt!);
  }

  String get _takeProfitsText {
    if (signal.takeProfits.isEmpty) return '-';
    return signal.takeProfits.join('  •  ');
  }

  Future<void> _showShareOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Share Signal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.image_rounded),
                  title: const Text('Share as Image'),
                  subtitle: const Text('PNG signal card with logo and QR'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareAsImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded),
                  title: const Text('Share as PDF'),
                  subtitle: const Text('Same signal card inside PDF'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareAsPdf();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.text_snippet_rounded),
                  title: const Text('Share as Text'),
                  subtitle: const Text('Simple signal text'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareAsText();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareAsText() {
    final text = '''
TradeMind AI Signal

Signal: ${signal.signalTitle}
Pair: ${signal.pair}
Side: ${signal.side}
Timeframe: ${signal.timeframe}
Entry: ${signal.entryText}
SL: ${signal.stopLoss}
TP: ${signal.takeProfits.join(', ')}
Status: ${signal.statusLabel}
Setup Score: ${signal.setupScore}/${signal.setupScoreMax}
Strategy: ${signal.strategy}

Educational only. Trade at your own risk.
''';

    Share.share(text);
  }

  Future<void> _shareAsImage() async {
    final pngBytes = await _buildShareImageBytes();
    if (pngBytes == null) return;

    final tempDir = await getTemporaryDirectory();

    final file = File(
      '${tempDir.path}/signalflow_signal_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    await file.writeAsBytes(pngBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'TradeMind AI Signal',
    );
  }

  Future<Uint8List?> _buildScreenStylePdfImageBytes() async {
    try {
      await precacheImage(
        const AssetImage('assets/images/logo.png'),
        context,
      );

      await precacheImage(
        const AssetImage('assets/images/whatsapp_qr.png'),
        context,
      );
    } catch (_) {}

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (_) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.01,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Center(
                  child: RepaintBoundary(
                    key: _shareImageKey,
                    child: SizedBox(
                      width: 390,
                      child: _SignalPdfScreenView(
                        signal: signal,
                        sideColor: _sideColor,
                        takeProfitsText: _takeProfitsText,
                        createdDate: _createdDate,
                        updatedDate: _updatedDate,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(overlayEntry);

    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 500));
    await WidgetsBinding.instance.endOfFrame;

    try {
      final boundary = _shareImageKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        _showMessage('Could not create PDF image.');
        return null;
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        _showMessage('Could not create PDF image file.');
        return null;
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      _showMessage('Could not create PDF: $e');
      return null;
    } finally {
      overlayEntry.remove();
    }
  }

  Future<void> _shareAsPdf() async {
    final pngBytes = await _buildScreenStylePdfImageBytes();
    if (pngBytes == null) return;

    final decodedImage = await decodeImageFromList(pngBytes);

    final imageWidth = decodedImage.width.toDouble();
    final imageHeight = decodedImage.height.toDouble();

    final pdf = pw.Document();
    final image = pw.MemoryImage(pngBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          imageWidth,
          imageHeight,
        ),
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Image(
            image,
            width: imageWidth,
            height: imageHeight,
            fit: pw.BoxFit.fill,
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final tempDir = await getTemporaryDirectory();

    final file = File(
      '${tempDir.path}/signalflow_signal_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'TradeMind AI Signal PDF',
    );
  }

  Future<Uint8List?> _buildShareImageBytes() async {
    try {
      await precacheImage(
        const AssetImage('assets/images/logo.png'),
        context,
      );

      await precacheImage(
        const AssetImage('assets/images/whatsapp_qr.png'),
        context,
      );
    } catch (_) {
      // Fallback icons will be used if assets are missing.
    }

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (_) {
        return Material(
          type: MaterialType.transparency,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.01,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Center(
                  child: RepaintBoundary(
                    key: _shareImageKey,
                    child: SizedBox(
                      width: 390,
                      child: _SignalShareImageCard(
                        signal: signal,
                        sideColor: _sideColor,
                        createdDate: _createdDate,
                        takeProfitsText: _takeProfitsText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(overlayEntry);

    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 500));
    await WidgetsBinding.instance.endOfFrame;

    try {
      final boundary = _shareImageKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        _showMessage('Could not create signal image.');
        return null;
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        _showMessage('Could not create image file.');
        return null;
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      _showMessage('Could not create share file: $e');
      return null;
    } finally {
      overlayEntry.remove();
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
  Widget build(BuildContext context) {
    final hasSetupDetails = signal.reason.isNotEmpty ||
        signal.strategy.isNotEmpty ||
        signal.backtestSummary.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signal Detail'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: _showShareOptions,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showShareOptions,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddJournalEntryScreen(signal: signal),
                      ),
                    );
                  },
                  icon: const Icon(Icons.book_rounded),
                  label: const Text('Add to Journal'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
        children: [
          _HeroSignalCard(
            signal: signal,
            sideColor: _sideColor,
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  title: 'Trade Levels',
                  subtitle: 'Entry, stop loss and targets.',
                  icon: Icons.candlestick_chart_rounded,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _LevelBox(
                        label: 'Entry',
                        value: signal.entryText,
                        icon: Icons.login_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LevelBox(
                        label: 'Stop Loss',
                        value: '${signal.stopLoss}',
                        icon: Icons.shield_outlined,
                        color: AppColors.loss,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _WideValueBox(
                  label: 'Take Profits',
                  value: _takeProfitsText,
                  icon: Icons.flag_rounded,
                  color: AppColors.profit,
                ),
                if (signal.currentPrice > 0) ...[
                  const SizedBox(height: 12),
                  _WideValueBox(
                    label: 'Current Price',
                    value: '${signal.currentPrice}',
                    icon: Icons.show_chart_rounded,
                  ),
                ],
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
                  title: 'Signal Status',
                  subtitle: 'Latest result and tracking information.',
                  icon: Icons.track_changes_rounded,
                ),
                const SizedBox(height: 18),
                _DetailRow(
                  label: 'Status',
                  value: signal.statusLabel,
                  icon: Icons.info_outline_rounded,
                ),
                if (signal.hitType.isNotEmpty)
                  _DetailRow(
                    label: 'Last Hit',
                    value: signal.hitType,
                    icon: Icons.bolt_rounded,
                  ),
                if (signal.tpHitPrice > 0)
                  _DetailRow(
                    label: 'TP Hit Price',
                    value: '${signal.tpHitPrice}',
                    icon: Icons.check_circle_outline_rounded,
                    valueColor: AppColors.profit,
                  ),
                if (signal.protectedStopLoss > 0)
                  _DetailRow(
                    label: 'Protected SL',
                    value: '${signal.protectedStopLoss}',
                    icon: Icons.security_rounded,
                  ),
                _DetailRow(
                  label: 'Source',
                  value: signal.source,
                  icon: Icons.source_rounded,
                ),
                _DetailRow(
                  label: 'Created',
                  value: _createdDate,
                  icon: Icons.calendar_month_rounded,
                ),
                if (signal.statusUpdatedAt != null)
                  _DetailRow(
                    label: 'Last Update',
                    value: _updatedDate,
                    icon: Icons.update_rounded,
                  ),
              ],
            ),
          ),
          if (hasSetupDetails) ...[
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    title: 'Setup Details',
                    subtitle: 'Strategy, backtest and signal reason.',
                    icon: Icons.auto_graph_rounded,
                  ),
                  const SizedBox(height: 18),
                  if (signal.strategy.isNotEmpty)
                    _DetailRow(
                      label: 'Strategy',
                      value: signal.strategy,
                      icon: Icons.route_rounded,
                    ),
                  if (signal.backtestSummary.isNotEmpty)
                    _TextBlock(
                      title: 'Backtest',
                      body: signal.backtestSummary,
                    ),
                  if (signal.reason.isNotEmpty)
                    _TextBlock(
                      title: 'Reason',
                      body: signal.reason,
                    ),
                ],
              ),
            ),
          ],
          if (signal.liveAutoTradePlaced) ...[
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    title: 'Auto-Trade Info',
                    subtitle: 'Live execution and exchange protection.',
                    icon: Icons.smart_toy_outlined,
                  ),
                  const SizedBox(height: 18),
                  if (signal.entrySide.isNotEmpty)
                    _DetailRow(
                      label: 'Entry Side',
                      value: signal.entrySide,
                      icon: Icons.swap_vert_rounded,
                    ),
                  if (signal.qty > 0)
                    _DetailRow(
                      label: 'Qty',
                      value: '${signal.qty}',
                      icon: Icons.numbers_rounded,
                    ),
                  if (signal.approxFillEntry > 0)
                    _DetailRow(
                      label: 'Approx Fill',
                      value: '${signal.approxFillEntry}',
                      icon: Icons.price_check_rounded,
                    ),
                  if (signal.leverage > 0)
                    _DetailRow(
                      label: 'Leverage',
                      value: '${signal.leverage}x',
                      icon: Icons.bolt_rounded,
                    ),
                  if (signal.margin.isNotEmpty)
                    _DetailRow(
                      label: 'Margin',
                      value: signal.margin,
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  _DetailRow(
                    label: 'Exchange Protection',
                    value: signal.exchangeProtection ? 'Enabled' : 'Disabled',
                    icon: Icons.verified_user_outlined,
                    valueColor: signal.exchangeProtection
                        ? AppColors.profit
                        : AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ],
          if (signal.lastUpdateRaw.isNotEmpty) ...[
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: _TextBlock(
                title: 'Latest Discord Update',
                body: signal.lastUpdateRaw,
              ),
            ),
          ],
          const SizedBox(height: 18),
          const _RiskNote(),
        ],
      ),
    );
  }
}

class _HeroSignalCard extends StatelessWidget {
  final TradeSignal signal;
  final Color sideColor;

  const _HeroSignalCard({
    required this.signal,
    required this.sideColor,
  });

  @override
  Widget build(BuildContext context) {
    final side = signal.side.toUpperCase();

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: sideColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: sideColor.withOpacity(0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: sideColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    side.contains('SHORT')
                        ? Icons.south_east_rounded
                        : Icons.north_east_rounded,
                    color: sideColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signal.pair,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 28,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        signal.signalTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(label: signal.statusLabel),
                _InfoChip(
                  label: side,
                  icon: side.contains('SHORT')
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: sideColor,
                ),
                if (signal.timeframe.isNotEmpty)
                  _InfoChip(
                    label: signal.timeframe,
                    icon: Icons.schedule_rounded,
                  ),
                if (signal.setupScore > 0)
                  _InfoChip(
                    label: 'Score ${signal.setupScore}/${signal.setupScoreMax}',
                    icon: Icons.star_rounded,
                  ),
                if (signal.liveAutoTradePlaced)
                  const _InfoChip(
                    label: 'Live auto-trade',
                    icon: Icons.smart_toy_outlined,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _LevelBox({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: activeColor.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: activeColor,
            size: 22,
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WideValueBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _WideValueBox({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: activeColor.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: activeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: activeColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w900,
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

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _InfoChip({
    required this.label,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: activeColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: activeColor.withOpacity(0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: activeColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: activeColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim().isEmpty ? '-' : value.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.035),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cleanValue,
                textAlign: TextAlign.right,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String title;
  final String body;

  const _TextBlock({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final cleanBody = body.trim().isEmpty ? '-' : body.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              cleanBody,
              style: const TextStyle(
                height: 1.5,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskNote extends StatelessWidget {
  const _RiskNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.loss.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.loss.withOpacity(0.14),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.loss,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Trading signals are for educational purposes only. Profit is not guaranteed. Always use your own risk management.',
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

class _SignalShareImageCard extends StatelessWidget {
  final TradeSignal signal;
  final Color sideColor;
  final String createdDate;
  final String takeProfitsText;

  const _SignalShareImageCard({
    required this.signal,
    required this.sideColor,
    required this.createdDate,
    required this.takeProfitsText,
  });

  String clean(String value) {
    return value.trim().isEmpty ? '-' : value.trim();
  }

  @override
  Widget build(BuildContext context) {
    final side = signal.side.toUpperCase();

    return Container(
      width: 390,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF10131A),
        borderRadius: BorderRadius.circular(28),
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
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 48,
                  width: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: sideColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.show_chart_rounded,
                        color: sideColor,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TradeMind AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Trading Signal Card',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sideColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: sideColor.withOpacity(0.18),
              ),
            ),
            child: Column(
              children: [
                Text(
                  signal.pair,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  signal.signalTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: sideColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    side,
                    style: TextStyle(
                      color: sideColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SignalShareMetric(
                  label: 'Entry',
                  value: clean(signal.entryText),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SignalShareMetric(
                  label: 'SL',
                  value: '${signal.stopLoss}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SignalShareMetric(
                  label: 'TF',
                  value: clean(signal.timeframe),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SignalShareTextBlock(
            label: 'Take Profits',
            value: clean(takeProfitsText),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          _SignalShareTextBlock(
            label: 'Status',
            value: clean(signal.statusLabel),
            maxLines: 1,
          ),
          if (signal.strategy.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SignalShareTextBlock(
              label: 'Strategy',
              value: clean(signal.strategy),
              maxLines: 2,
            ),
          ],
          if (signal.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SignalShareTextBlock(
              label: 'Reason',
              value: clean(signal.reason),
              maxLines: 3,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            createdDate,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Image.asset(
                  'assets/images/whatsapp_qr.png',
                  height: 68,
                  width: 68,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      height: 68,
                      width: 68,
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        color: Colors.black,
                        size: 46,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join our WhatsApp Channel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Scan for updates, signals and trading education.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Educational only. Trade at your own risk.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalShareMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SignalShareMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalShareTextBlock extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;

  const _SignalShareTextBlock({
    required this.label,
    required this.value,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalPdfScreenView extends StatelessWidget {
  final TradeSignal signal;
  final Color sideColor;
  final String takeProfitsText;
  final String createdDate;
  final String updatedDate;

  const _SignalPdfScreenView({
    required this.signal,
    required this.sideColor,
    required this.takeProfitsText,
    required this.createdDate,
    required this.updatedDate,
  });

  @override
  Widget build(BuildContext context) {
    final hasSetupDetails = signal.reason.isNotEmpty ||
        signal.strategy.isNotEmpty ||
        signal.backtestSummary.isNotEmpty;

    return Container(
      width: 390,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PdfLogoHeader(),
          const SizedBox(height: 14),
          _HeroSignalCard(
            signal: signal,
            sideColor: sideColor,
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  title: 'Trade Levels',
                  subtitle: 'Entry, stop loss and targets.',
                  icon: Icons.candlestick_chart_rounded,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _LevelBox(
                        label: 'Entry',
                        value: signal.entryText,
                        icon: Icons.login_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LevelBox(
                        label: 'Stop Loss',
                        value: '${signal.stopLoss}',
                        icon: Icons.shield_outlined,
                        color: AppColors.loss,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _WideValueBox(
                  label: 'Take Profits',
                  value: takeProfitsText,
                  icon: Icons.flag_rounded,
                  color: AppColors.profit,
                ),
                if (signal.currentPrice > 0) ...[
                  const SizedBox(height: 12),
                  _WideValueBox(
                    label: 'Current Price',
                    value: '${signal.currentPrice}',
                    icon: Icons.show_chart_rounded,
                  ),
                ],
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
                  title: 'Signal Status',
                  subtitle: 'Latest result and tracking information.',
                  icon: Icons.track_changes_rounded,
                ),
                const SizedBox(height: 18),
                _DetailRow(
                  label: 'Status',
                  value: signal.statusLabel,
                  icon: Icons.info_outline_rounded,
                ),
                if (signal.hitType.isNotEmpty)
                  _DetailRow(
                    label: 'Last Hit',
                    value: signal.hitType,
                    icon: Icons.bolt_rounded,
                  ),
                if (signal.tpHitPrice > 0)
                  _DetailRow(
                    label: 'TP Hit Price',
                    value: '${signal.tpHitPrice}',
                    icon: Icons.check_circle_outline_rounded,
                    valueColor: AppColors.profit,
                  ),
                if (signal.protectedStopLoss > 0)
                  _DetailRow(
                    label: 'Protected SL',
                    value: '${signal.protectedStopLoss}',
                    icon: Icons.security_rounded,
                  ),
                _DetailRow(
                  label: 'Source',
                  value: signal.source,
                  icon: Icons.source_rounded,
                ),
                _DetailRow(
                  label: 'Created',
                  value: createdDate,
                  icon: Icons.calendar_month_rounded,
                ),
                if (signal.statusUpdatedAt != null)
                  _DetailRow(
                    label: 'Last Update',
                    value: updatedDate,
                    icon: Icons.update_rounded,
                  ),
              ],
            ),
          ),
          if (hasSetupDetails) ...[
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    title: 'Setup Details',
                    subtitle: 'Strategy, backtest and signal reason.',
                    icon: Icons.auto_graph_rounded,
                  ),
                  const SizedBox(height: 18),
                  if (signal.strategy.isNotEmpty)
                    _DetailRow(
                      label: 'Strategy',
                      value: signal.strategy,
                      icon: Icons.route_rounded,
                    ),
                  if (signal.backtestSummary.isNotEmpty)
                    _TextBlock(
                      title: 'Backtest',
                      body: signal.backtestSummary,
                    ),
                  if (signal.reason.isNotEmpty)
                    _TextBlock(
                      title: 'Reason',
                      body: signal.reason,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const _PdfQrFooter(),
          const SizedBox(height: 12),
          const _RiskNote(),
        ],
      ),
    );
  }
}

class _PdfLogoHeader extends StatelessWidget {
  const _PdfLogoHeader();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/logo.png',
              height: 46,
              width: 46,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.show_chart_rounded,
                    color: AppColors.primary,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TradeMind AI',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Trading Signal Report',
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
    );
  }
}

class _PdfQrFooter extends StatelessWidget {
  const _PdfQrFooter();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.asset(
              'assets/images/whatsapp_qr.png',
              height: 68,
              width: 68,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(
                  height: 68,
                  width: 68,
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.black,
                    size: 46,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join our WhatsApp Channel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Scan for updates, signals and trading education.',
                  style: TextStyle(
                    color: AppColors.textMuted,
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
    );
  }
}
