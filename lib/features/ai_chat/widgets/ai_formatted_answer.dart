part of '../screens/ai_chat_screen.dart';

enum _AiBlockType {
  heading,
  bullet,
  numbered,
  paragraph,
  warning,
  action,
  divider,
}

class _AiTextBlock {
  final _AiBlockType type;
  final String text;
  final int? number;
  final Color color;
  final IconData icon;

  const _AiTextBlock({
    required this.type,
    required this.text,
    this.number,
    required this.color,
    required this.icon,
  });
}

class _AiPremiumFormattedAnswer extends StatelessWidget {
  final String text;
  final bool showTopBar;

  const _AiPremiumFormattedAnswer({
    required this.text,
    this.showTopBar = true,
  });
  @override
  Widget build(BuildContext context) {
    final blocks = _parseAiText(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTopBar) ...[
          _AiAnswerTopBar(originalText: text),
          const SizedBox(height: 10),
        ],
        if (blocks.isEmpty)
          SelectableText(
            _cleanAiInlineText(text),
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              height: 1.45,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          for (final block in blocks) _AiTextBlockWidget(block: block),
      ],
    );
  }
}

class _AiAnswerTopBar extends StatelessWidget {
  final String originalText;

  const _AiAnswerTopBar({
    required this.originalText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.13),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.20),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                'AI Coach',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Material(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: _cleanAiForCopy(originalText),
                ),
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AI answer copied'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(
                Icons.copy_rounded,
                color: Colors.white.withOpacity(0.72),
                size: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AiTextBlockWidget extends StatelessWidget {
  final _AiTextBlock block;

  const _AiTextBlockWidget({
    required this.block,
  });

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case _AiBlockType.heading:
        return _AiHeadingBlock(block: block);

      case _AiBlockType.warning:
        return _AiCalloutBlock(
          block: block,
          backgroundOpacity: 0.10,
        );

      case _AiBlockType.action:
        return _AiCalloutBlock(
          block: block,
          backgroundOpacity: 0.095,
        );

      case _AiBlockType.bullet:
        return _AiBulletBlock(block: block);

      case _AiBlockType.numbered:
        return _AiNumberedBlock(block: block);

      case _AiBlockType.divider:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.02),
                  Colors.white.withOpacity(0.14),
                  Colors.white.withOpacity(0.02),
                ],
              ),
            ),
          ),
        );

      case _AiBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: SelectableText(
            block.text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.90),
              height: 1.48,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }
  }
}

class _AiHeadingBlock extends StatelessWidget {
  final _AiTextBlock block;

  const _AiHeadingBlock({
    required this.block,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        top: 6,
        bottom: 9,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            block.color.withOpacity(0.18),
            block.color.withOpacity(0.055),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: block.color.withOpacity(0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 26,
            width: 26,
            decoration: BoxDecoration(
              color: block.color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              block.icon,
              color: block.color,
              size: 15,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              block.text,
              style: TextStyle(
                color: block.color,
                height: 1.25,
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiCalloutBlock extends StatelessWidget {
  final _AiTextBlock block;
  final double backgroundOpacity;

  const _AiCalloutBlock({
    required this.block,
    required this.backgroundOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: block.color.withOpacity(backgroundOpacity),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: block.color.withOpacity(0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            block.icon,
            color: block.color,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: SelectableText(
              block.text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                height: 1.42,
                fontSize: 13.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiBulletBlock extends StatelessWidget {
  final _AiTextBlock block;

  const _AiBulletBlock({
    required this.block,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 22,
            width: 22,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: block.color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: block.color.withOpacity(0.16),
              ),
            ),
            child: Icon(
              block.icon,
              color: block.color,
              size: 13.5,
            ),
          ),
          Expanded(
            child: SelectableText(
              block.text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.91),
                height: 1.44,
                fontSize: 13.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiNumberedBlock extends StatelessWidget {
  final _AiTextBlock block;

  const _AiNumberedBlock({
    required this.block,
  });

  @override
  Widget build(BuildContext context) {
    final number = block.number ?? 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(
              minWidth: 25,
              minHeight: 25,
            ),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  block.color.withOpacity(0.24),
                  block.color.withOpacity(0.09),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: block.color.withOpacity(0.20),
              ),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: block.color,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              block.text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.91),
                height: 1.44,
                fontSize: 13.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<_AiTextBlock> _parseAiText(String input) {
  final normalized = input
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('•', '-')
      .replaceAll('– ', '- ')
      .replaceAll('— ', '- ');

  final lines = normalized.split('\n');

  final blocks = <_AiTextBlock>[];
  final paragraphBuffer = StringBuffer();

  void flushParagraph() {
    final paragraph = _cleanAiInlineText(paragraphBuffer.toString().trim());

    if (paragraph.isNotEmpty) {
      blocks.add(
        _AiTextBlock(
          type: _AiBlockType.paragraph,
          text: paragraph,
          color: _blockColorForText(paragraph),
          icon: _blockIconForText(paragraph),
        ),
      );
    }

    paragraphBuffer.clear();
  }

  for (final rawLine in lines) {
    final line = rawLine.trim();

    if (line.isEmpty) {
      flushParagraph();
      continue;
    }

    if (RegExp(r'^[-*_]{3,}$').hasMatch(line)) {
      flushParagraph();

      blocks.add(
        const _AiTextBlock(
          type: _AiBlockType.divider,
          text: '',
          color: AppColors.primary,
          icon: Icons.horizontal_rule_rounded,
        ),
      );

      continue;
    }

    if (_isHeadingLine(line)) {
      flushParagraph();

      final heading = _cleanHeadingText(line);

      blocks.add(
        _AiTextBlock(
          type: _AiBlockType.heading,
          text: heading,
          color: _blockColorForText(heading),
          icon: _blockIconForText(heading),
        ),
      );

      continue;
    }

    final bulletMatch = RegExp(r'^[-*]\s+(.+)$').firstMatch(line);

    if (bulletMatch != null) {
      flushParagraph();

      final bullet = _cleanAiInlineText(bulletMatch.group(1) ?? '');
      final type = _specialBlockTypeForText(bullet) ?? _AiBlockType.bullet;

      blocks.add(
        _AiTextBlock(
          type: type,
          text: bullet,
          color: _blockColorForText(bullet),
          icon: _blockIconForText(bullet),
        ),
      );

      continue;
    }

    final numberedMatch = RegExp(r'^(\d+)[\.\)]\s+(.+)$').firstMatch(line);

    if (numberedMatch != null) {
      flushParagraph();

      final text = _cleanAiInlineText(numberedMatch.group(2) ?? '');

      blocks.add(
        _AiTextBlock(
          type: _AiBlockType.numbered,
          number: int.tryParse(numberedMatch.group(1) ?? ''),
          text: text,
          color: _blockColorForText(text),
          icon: _blockIconForText(text),
        ),
      );

      continue;
    }

    final specialType = _specialBlockTypeForText(line);

    if (specialType != null) {
      flushParagraph();

      final cleaned = _cleanAiInlineText(line);

      blocks.add(
        _AiTextBlock(
          type: specialType,
          text: cleaned,
          color: _blockColorForText(cleaned),
          icon: _blockIconForText(cleaned),
        ),
      );

      continue;
    }

    if (paragraphBuffer.isNotEmpty) {
      paragraphBuffer.write(' ');
    }

    paragraphBuffer.write(line);
  }

  flushParagraph();

  return blocks;
}

_AiBlockType? _specialBlockTypeForText(String text) {
  final lower = text.toLowerCase();

  if (lower.startsWith('warning') ||
      lower.startsWith('risk') ||
      lower.startsWith('danger') ||
      lower.contains('be careful') ||
      lower.contains('avoid')) {
    return _AiBlockType.warning;
  }

  if (lower.startsWith('action') ||
      lower.startsWith('next step') ||
      lower.startsWith('do this') ||
      lower.contains('you should') ||
      lower.contains('your plan')) {
    return _AiBlockType.action;
  }

  return null;
}

bool _isHeadingLine(String line) {
  final trimmed = line.trim();

  if (RegExp(r'^#{1,6}\s+').hasMatch(trimmed)) {
    return true;
  }

  if (RegExp(r'^\*\*.+\*\*:?\s*$').hasMatch(trimmed)) {
    return true;
  }

  if (RegExp(r'^__.+__:?\s*$').hasMatch(trimmed)) {
    return true;
  }

  final clean = _cleanAiInlineText(trimmed);

  if (clean.endsWith(':') && clean.length <= 75) {
    return true;
  }

  final words = clean.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length;

  if (words <= 7 &&
      !clean.contains('.') &&
      !clean.contains(',') &&
      clean.length <= 55 &&
      _looksLikeTitle(clean)) {
    return true;
  }

  return false;
}

bool _looksLikeTitle(String text) {
  final lower = text.toLowerCase();

  final titleWords = [
    'summary',
    'mistake',
    'mistakes',
    'risk',
    'discipline',
    'emotion',
    'emotions',
    'setup',
    'setups',
    'plan',
    'improvement',
    'improve',
    'next',
    'journal',
    'pattern',
    'patterns',
    'strength',
    'weakness',
    'weaknesses',
    'action',
    'focus',
  ];

  return titleWords.any(lower.contains);
}

String _cleanHeadingText(String text) {
  var cleaned = text.trim();

  cleaned = cleaned.replaceFirst(RegExp(r'^#{1,6}\s*'), '');

  cleaned = cleaned.replaceAllMapped(
    RegExp(r'^\*\*(.+)\*\*:?\s*$'),
    (match) => match.group(1) ?? '',
  );

  cleaned = cleaned.replaceAllMapped(
    RegExp(r'^__(.+)__:?\s*$'),
    (match) => match.group(1) ?? '',
  );

  cleaned = _cleanAiInlineText(cleaned);

  if (cleaned.endsWith(':')) {
    cleaned = cleaned.substring(0, cleaned.length - 1).trim();
  }

  return cleaned;
}

String _cleanAiInlineText(String text) {
  var cleaned = text;

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

  cleaned = cleaned.replaceAll(RegExp(r'#{1,6}\s*'), '');
  cleaned = cleaned.replaceAll(RegExp(r'\*+'), '');
  cleaned = cleaned.replaceAll(RegExp(r'_+'), '');
  cleaned = cleaned.replaceAll(RegExp(r'`+'), '');
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

  return cleaned.trim();
}

String _cleanAiForCopy(String text) {
  var cleaned = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');

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

Color _blockColorForText(String text) {
  final lower = text.toLowerCase();

  if (lower.contains('loss') ||
      lower.contains('mistake') ||
      lower.contains('risk') ||
      lower.contains('danger') ||
      lower.contains('avoid') ||
      lower.contains('weak') ||
      lower.contains('problem') ||
      lower.contains('revenge')) {
    return AppColors.loss;
  }

  if (lower.contains('win') ||
      lower.contains('profit') ||
      lower.contains('improve') ||
      lower.contains('strength') ||
      lower.contains('good') ||
      lower.contains('plan') ||
      lower.contains('next step')) {
    return AppColors.profit;
  }

  if (lower.contains('emotion') ||
      lower.contains('discipline') ||
      lower.contains('journal') ||
      lower.contains('setup') ||
      lower.contains('pattern')) {
    return AppColors.primary;
  }

  return AppColors.primary;
}

IconData _blockIconForText(String text) {
  final lower = text.toLowerCase();

  if (lower.contains('loss') ||
      lower.contains('mistake') ||
      lower.contains('risk') ||
      lower.contains('danger') ||
      lower.contains('avoid') ||
      lower.contains('revenge')) {
    return Icons.warning_amber_rounded;
  }

  if (lower.contains('win') ||
      lower.contains('profit') ||
      lower.contains('improve') ||
      lower.contains('strength')) {
    return Icons.trending_up_rounded;
  }

  if (lower.contains('plan') ||
      lower.contains('next step') ||
      lower.contains('action')) {
    return Icons.task_alt_rounded;
  }

  if (lower.contains('emotion') || lower.contains('discipline')) {
    return Icons.psychology_rounded;
  }

  if (lower.contains('setup') || lower.contains('pattern')) {
    return Icons.analytics_rounded;
  }

  return Icons.auto_awesome_rounded;
}

