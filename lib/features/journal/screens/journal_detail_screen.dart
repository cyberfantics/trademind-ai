import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:trade_mind_ai/features/ai_chat/screens/ai_chat_screen.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../models/journal_entry.dart';
import '../services/journal_service.dart';

class JournalDetailScreen extends StatefulWidget {
  final JournalEntry entry;

  const JournalDetailScreen({
    super.key,
    required this.entry,
  });

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  final GlobalKey _shareImageKey = GlobalKey();

  JournalEntry get entry => widget.entry;

  bool get isProfit => entry.pnlAmount >= 0;

  Color get resultColor => isProfit ? AppColors.profit : AppColors.loss;

  String get resultText => isProfit ? 'PROFIT' : 'LOSS';

  String get formattedDate {
    if (entry.createdAt == null) return 'Unknown';
    return DateFormat('dd MMM yyyy, hh:mm a').format(entry.createdAt!);
  }

  String signedPercent() {
    final sign = entry.pnlPercent >= 0 ? '+' : '';
    return '$sign${entry.pnlPercent.toStringAsFixed(2)}%';
  }

  String signedAmount() {
    final sign = entry.pnlAmount >= 0 ? '+' : '';
    return '$sign${entry.pnlAmount.toStringAsFixed(2)}';
  }

  String formatPrice(num value) {
    if (value.abs() >= 1) return value.toStringAsFixed(2);
    return value.toStringAsFixed(6);
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
                  'Share Journal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.image_rounded),
                  title: const Text('Share as Image'),
                  subtitle: const Text('PNG card with logo and QR code'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareAsImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded),
                  title: const Text('Share as PDF'),
                  subtitle: const Text('Same journal image inside PDF'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareAsPdf();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.text_snippet_rounded),
                  title: const Text('Share as Text'),
                  subtitle: const Text('Simple text format'),
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
    Share.share('''
TradeMind AI Journal

Pair: ${entry.pair}
Side: ${entry.side}
Result: $resultText
PnL: ${entry.pnlPercent.toStringAsFixed(2)}%
Amount: ${entry.pnlAmount.toStringAsFixed(2)}
Entry: ${formatPrice(entry.entryPrice)}
Exit: ${formatPrice(entry.exitPrice)}
Leverage: ${entry.leverage}x
Size: ${entry.positionSize}
Setup: ${entry.setup}
Emotion: ${entry.emotion}
Notes: ${entry.notes}

Educational only. Trade at your own risk.
''');
  }

  Future<void> _shareAsImage() async {
    final pngBytes = await _buildShareImageBytes();
    if (pngBytes == null) return;

    final tempDir = await getTemporaryDirectory();

    final file = File(
      '${tempDir.path}/signalflow_journal_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    await file.writeAsBytes(pngBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'TradeMind AI Journal',
    );
  }

  Future<void> _shareAsPdf() async {
    final pngBytes = await _buildShareImageBytes();
    if (pngBytes == null) return;

    final pdf = pw.Document();
    final image = pw.MemoryImage(pngBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Center(
            child: pw.Image(
              image,
              fit: pw.BoxFit.contain,
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final tempDir = await getTemporaryDirectory();

    final file = File(
      '${tempDir.path}/signalflow_journal_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'TradeMind AI Journal PDF',
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
      // If assets are missing, fallback icons will be used.
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
                      child: _JournalShareImageCard(
                        entry: entry,
                        resultColor: resultColor,
                        resultText: resultText,
                        signedPercent: signedPercent(),
                        signedAmount: signedAmount(),
                        formattedDate: formattedDate,
                        formatPrice: formatPrice,
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
        _showMessage('Could not create journal image.');
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

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete journal?'),
          content: const Text(
            'This trade journal entry will be removed permanently.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.loss,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await JournalService().deleteEntry(user.uid, entry.id);

    if (context.mounted) Navigator.pop(context);
  }

  String _buildAskAiAboutTradePrompt(JournalEntry entry) {
    return '''
Analyze this single trade from my journal.

Trade details:
Pair: ${entry.pair}
Side: ${entry.side}
Entry price: ${entry.entryPrice}
Exit price: ${entry.exitPrice}
Leverage: ${entry.leverage}x
Position size: ${entry.positionSize}
PnL percent: ${entry.pnlPercent.toStringAsFixed(2)}%
PnL amount: ${entry.pnlAmount.toStringAsFixed(2)}
Setup: ${entry.setup}
Emotion: ${entry.emotion}
Notes: ${entry.notes}
Date: ${entry.createdAt}

Please tell me:
1. What I did right
2. What I did wrong
3. What mistake I should avoid next time
4. What risk rule I should follow next time
5. A simple improvement plan
''';
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Detail'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Ask AI',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiChatScreen(
                    initialQuestion: _buildAskAiAboutTradePrompt(entry),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: _showShareOptions,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.pair,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 28,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _SoftChip(
                                text: entry.side.toUpperCase(),
                                icon: Icons.swap_vert_rounded,
                              ),
                              _SoftChip(
                                text: resultText,
                                icon: isProfit
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                color: resultColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: resultColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        isProfit
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: resultColor,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: resultColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: resultColor.withOpacity(0.18),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        signedPercent(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: resultColor,
                          fontSize: 44,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        signedAmount(),
                        style: TextStyle(
                          color: resultColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Total PnL',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 12) / 2;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _MetricTile(
                            label: 'Entry',
                            value: formatPrice(entry.entryPrice),
                            icon: Icons.login_rounded,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _MetricTile(
                            label: 'Exit',
                            value: formatPrice(entry.exitPrice),
                            icon: Icons.logout_rounded,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _MetricTile(
                            label: 'Leverage',
                            value: '${entry.leverage}x',
                            icon: Icons.bolt_rounded,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _MetricTile(
                            label: 'Size',
                            value: entry.positionSize.toString(),
                            icon: Icons.account_balance_wallet_rounded,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          formattedDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  title: 'Trade Review',
                  icon: Icons.article_outlined,
                ),
                const SizedBox(height: 18),
                _TextBlock(
                  label: 'Setup / Strategy',
                  value: entry.setup,
                ),
                const SizedBox(height: 18),
                _TextBlock(
                  label: 'Emotion',
                  value: entry.emotion,
                ),
                const SizedBox(height: 18),
                _TextBlock(
                  label: 'Notes',
                  value: entry.notes,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalShareImageCard extends StatelessWidget {
  final JournalEntry entry;
  final Color resultColor;
  final String resultText;
  final String signedPercent;
  final String signedAmount;
  final String formattedDate;
  final String Function(num value) formatPrice;

  const _JournalShareImageCard({
    required this.entry,
    required this.resultColor,
    required this.resultText,
    required this.signedPercent,
    required this.signedAmount,
    required this.formattedDate,
    required this.formatPrice,
  });

  String clean(String value) {
    return value.trim().isEmpty ? '-' : value.trim();
  }

  @override
  Widget build(BuildContext context) {
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
                        color: resultColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.show_chart_rounded,
                        color: resultColor,
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
                      'Trading Journal Report',
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
              color: resultColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: resultColor.withOpacity(0.18),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '${entry.pair}  •  ${entry.side.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  signedPercent,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: resultColor,
                    fontSize: 46,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  signedAmount,
                  style: TextStyle(
                    color: resultColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: resultColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    resultText,
                    style: TextStyle(
                      color: resultColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
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
                child: _ShareMetric(
                  label: 'Entry',
                  value: formatPrice(entry.entryPrice),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ShareMetric(
                  label: 'Exit',
                  value: formatPrice(entry.exitPrice),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ShareMetric(
                  label: 'Lev.',
                  value: '${entry.leverage}x',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ShareTextBlock(
            label: 'Setup',
            value: clean(entry.setup),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          _ShareTextBlock(
            label: 'Notes',
            value: clean(entry.notes),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          Text(
            formattedDate,
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

class _ShareMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ShareMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(17),
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
              fontSize: 11,
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
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareTextBlock extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;

  const _ShareTextBlock({
    required this.label,
    required this.value,
    this.maxLines = 3,
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

class _SoftChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;

  const _SoftChip({
    required this.text,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: chipColor.withOpacity(0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: chipColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textMuted.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: AppColors.textMuted,
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
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: AppColors.textMuted.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 19,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String label;
  final String value;

  const _TextBlock({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim().isEmpty ? '-' : value.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          cleanValue,
          style: const TextStyle(
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
