import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/ai_message.dart';

class AiShareService {
  static const String appName = 'TradeMind AI';
  static const String appSubtitle = 'AI Journal Coach';

  /// Change this to Play Store link / website / landing page.
  static const String joinUrl = 'https://github.com/cyberfantics';

  Future<void> shareAsText({
    required AiMessage message,
  }) async {
    final text = '''
$appName - $appSubtitle

${message.isUser ? 'Question' : 'AI Response'}:

${_cleanPlainText(message.text)}

Join:
$joinUrl
''';

    await Share.share(
      text,
      subject: '$appName AI Response',
    );
  }

  Future<void> shareFullChatAsPdf({
    required List<AiMessage> messages,
  }) async {
    final exportMessages =
        messages.where((message) => message.text.trim().isNotEmpty).toList();

    if (exportMessages.isEmpty) {
      throw Exception('No AI chat messages found.');
    }

    final pdf = pw.Document();
    final logoBytes = await _tryLoadLogoBytes();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 30),
        header: (context) {
          return _buildCleanFullChatHeader(
            logoBytes: logoBytes,
            isFirstPage: context.pageNumber == 1,
          );
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(
                  color: PdfColor.fromHex('#E2E8F0'),
                  width: 0.6,
                ),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    appName,
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#64748B'),
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#64748B'),
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            pw.SizedBox(height: 10),
            for (var i = 0; i < exportMessages.length; i++)
              ..._buildCleanMessageWidgets(
                message: exportMessages[i],
                index: i + 1,
              ),
            pw.SizedBox(height: 16),
            _buildCleanJoinQrBox(),
          ];
        },
      ),
    );

    final pdfBytes = await pdf.save();

    if (pdfBytes.isEmpty) {
      throw Exception('PDF file was empty.');
    }

    final dir = await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/signalflow_full_ai_chat_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    await file.writeAsBytes(
      pdfBytes,
      flush: true,
    );

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: 'application/pdf',
          name: 'signalflow_full_ai_chat.pdf',
        ),
      ],
      text: '$appName Full AI Chat PDF',
    );
  }

  pw.Widget _buildCleanFullChatHeader({
    required Uint8List? logoBytes,
    required bool isFirstPage,
  }) {
    if (!isFirstPage) {
      return pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          '$appName - AI Chat Export',
          style: pw.TextStyle(
            color: PdfColor.fromHex('#64748B'),
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8FAFC'),
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(
          color: PdfColor.fromHex('#E2E8F0'),
          width: 0.7,
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logoBytes != null)
            pw.Container(
              width: 42,
              height: 42,
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#2563EB'),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Image(
                pw.MemoryImage(logoBytes),
                fit: pw.BoxFit.contain,
              ),
            )
          else
            pw.Container(
              width: 42,
              height: 42,
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#2563EB'),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Center(
                child: pw.Text(
                  'SF',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  appName,
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#0F172A'),
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Full AI Chat Export',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#2563EB'),
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildCleanMessageWidgets({
    required AiMessage message,
    required int index,
  }) {
    final isUser = message.isUser;
    final role = isUser ? 'User Question' : 'AI Coach';
    final cleanText = _cleanPlainText(message.text);

    final paragraphs = _splitIntoSafeParagraphs(cleanText);

    final titleColor =
        isUser ? PdfColor.fromHex('#1D4ED8') : PdfColor.fromHex('#0F172A');

    final boxColor =
        isUser ? PdfColor.fromHex('#EFF6FF') : PdfColor.fromHex('#F8FAFC');

    final borderColor =
        isUser ? PdfColor.fromHex('#BFDBFE') : PdfColor.fromHex('#E2E8F0');

    final widgets = <pw.Widget>[
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
        child: pw.Row(
          children: [
            pw.Container(
              width: 22,
              height: 22,
              decoration: pw.BoxDecoration(
                color: isUser
                    ? PdfColor.fromHex('#2563EB')
                    : PdfColor.fromHex('#0F172A'),
                borderRadius: pw.BorderRadius.circular(999),
              ),
              child: pw.Center(
                child: pw.Text(
                  isUser ? 'U' : 'AI',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: isUser ? 9 : 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              '$index. $role',
              style: pw.TextStyle(
                color: titleColor,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ];

    for (final paragraph in paragraphs) {
      widgets.add(
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 7),
          padding: const pw.EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 9,
          ),
          decoration: pw.BoxDecoration(
            color: boxColor,
            borderRadius: pw.BorderRadius.circular(9),
            border: pw.Border.all(
              color: borderColor,
              width: 0.6,
            ),
          ),
          child: pw.Text(
            paragraph,
            textAlign: pw.TextAlign.left,
            softWrap: true,
            style: pw.TextStyle(
              color: PdfColor.fromHex('#0F172A'),
              fontSize: 10.2,
              lineSpacing: 3.2,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  pw.Widget _buildCleanJoinQrBox() {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 18),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8FAFC'),
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(
          color: PdfColor.fromHex('#E2E8F0'),
          width: 0.7,
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 58,
            height: 58,
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(
                color: PdfColor.fromHex('#CBD5E1'),
                width: 0.6,
              ),
            ),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: joinUrl,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Join $appName',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#0F172A'),
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  joinUrl,
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#2563EB'),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _splitIntoSafeParagraphs(String text) {
    final clean = text.trim();

    if (clean.isEmpty) return [''];

    final rawParagraphs = clean
        .split(RegExp(r'\n{1,}'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final result = <String>[];

    for (final paragraph in rawParagraphs) {
      if (paragraph.length <= 750) {
        result.add(paragraph);
      } else {
        result.addAll(
          _splitLongParagraph(
            paragraph,
            maxChars: 750,
          ),
        );
      }
    }

    return result;
  }

  List<String> _splitLongParagraph(
    String text, {
    required int maxChars,
  }) {
    final words = text.split(RegExp(r'\s+'));
    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final word in words) {
      if ((buffer.length + word.length + 1) > maxChars) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }

      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }

      buffer.write(word);
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString().trim());
    }

    return chunks;
  }

  Future<Uint8List?> _tryLoadLogoBytes() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> sharePngAsPdf({
    required Uint8List pngBytes,
  }) async {
    if (pngBytes.isEmpty) {
      throw Exception('PDF image is empty.');
    }

    final imageSize = await _readPngSize(pngBytes);

    final pdf = pw.Document();
    final image = pw.MemoryImage(pngBytes);

    final double pageWidth = PdfPageFormat.a4.width;
    const double margin = 18.0;

    final availableWidth = pageWidth - (margin * 2);
    final imageHeight = availableWidth * (imageSize.height / imageSize.width);

    /// This makes a long PDF page so the full AI response is not cut.
    final pageHeight = imageHeight + (margin * 2);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          pageWidth,
          pageHeight,
        ),
        margin: const pw.EdgeInsets.all(margin),
        build: (context) {
          return pw.Center(
            child: pw.Image(
              image,
              width: availableWidth,
              fit: pw.BoxFit.fitWidth,
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    if (pdfBytes.isEmpty) {
      throw Exception('PDF file is empty.');
    }

    final dir = await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/signalflow_ai_response_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    await file.writeAsBytes(
      pdfBytes,
      flush: true,
    );

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: 'application/pdf',
          name: 'signalflow_ai_response.pdf',
        ),
      ],
      text: '$appName AI Response PDF',
    );
  }

  Future<ui.Size> _readPngSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    final image = frame.image;

    final size = ui.Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    image.dispose();

    return size;
  }

  String _cleanPlainText(String text) {
    var cleaned = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*\*(.*?)\*\*'),
      (match) => match.group(1) ?? '',
    );

    cleaned = cleaned.replaceAllMapped(
      RegExp(r'__(.*?)__'),
      (match) => match.group(1) ?? '',
    );

    cleaned = cleaned.replaceAllMapped(
      RegExp(r'`([^`]*)`'),
      (match) => match.group(1) ?? '',
    );

    cleaned = cleaned
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'_+'), '')
        .replaceAll(RegExp(r'`+'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return cleaned;
  }
}
