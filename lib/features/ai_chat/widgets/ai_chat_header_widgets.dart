part of '../screens/ai_chat_screen.dart';

class _CoachHeaderCard extends StatelessWidget {
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final int trades;
  final double winRate;
  final double totalPnl;
  final bool isLoading;

  const _CoachHeaderCard({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    required this.trades,
    required this.winRate,
    required this.totalPnl,
    required this.isLoading,
  });

  String signedAmount(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.95),
                      AppColors.primary.withOpacity(0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(19),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.22),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(15),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        icon,
                        color: Colors.white,
                        size: 27,
                      ),
              ),
              const SizedBox(width: 13),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  label: 'Trades',
                  value: '$trades',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderStat(
                  label: 'Win Rate',
                  value: '${winRate.toStringAsFixed(1)}%',
                  color: winRate >= 50 ? AppColors.profit : AppColors.loss,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderStat(
                  label: 'PnL',
                  value: signedAmount(totalPnl),
                  color: totalPnl >= 0 ? AppColors.profit : AppColors.loss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 58,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.075),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.13),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickQuestionsBar extends StatelessWidget {
  final void Function(String question) onAsk;

  const _QuickQuestionsBar({
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final questions = [
      (
        'Mistakes',
        'Analyze my recent trading mistakes from my journal.',
        Icons.search_rounded,
        AppColors.loss,
      ),
      (
        'Improve',
        'What are the top 3 things I should improve based on my journal?',
        Icons.trending_up_rounded,
        AppColors.profit,
      ),
      (
        'Emotion',
        'Which emotions are hurting my trades?',
        Icons.psychology_rounded,
        AppColors.primary,
      ),
      (
        'Plan',
        'Make me a simple trading discipline plan for next week.',
        Icons.event_note_rounded,
        AppColors.textMuted,
      ),
    ];

    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: questions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final q = questions[index];

          return _QuickPromptButton(
            title: q.$1,
            question: q.$2,
            icon: q.$3,
            color: q.$4,
            onTap: onAsk,
          );
        },
      ),
    );
  }
}

class _QuickPromptButton extends StatelessWidget {
  final String title;
  final String question;
  final IconData icon;
  final Color color;
  final void Function(String question) onTap;

  const _QuickPromptButton({
    required this.title,
    required this.question,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => onTap(question),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: color.withOpacity(0.14),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsibleCoachHeader extends StatelessWidget {
  final bool expanded;
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final int trades;
  final double winRate;
  final double totalPnl;
  final bool isLoading;
  final VoidCallback onToggle;

  const _CollapsibleCoachHeader({
    required this.expanded,
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    required this.trades,
    required this.winRate,
    required this.totalPnl,
    required this.isLoading,
    required this.onToggle,
  });

  String _signedAmount(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        expanded ? 10 : 6,
      ),
      child: AnimatedCrossFade(
        firstChild: _ExpandedCoachHeader(
          title: title,
          message: message,
          color: color,
          icon: icon,
          trades: trades,
          winRate: winRate,
          totalPnl: totalPnl,
          isLoading: isLoading,
          onToggle: onToggle,
        ),
        secondChild: _CollapsedCoachTab(
          title: title,
          color: color,
          icon: icon,
          trades: trades,
          winRate: winRate,
          totalPnl: totalPnl,
          isLoading: isLoading,
          onToggle: onToggle,
          signedAmount: _signedAmount,
        ),
        crossFadeState:
            expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        duration: const Duration(milliseconds: 240),
        reverseDuration: const Duration(milliseconds: 180),
        sizeCurve: Curves.easeOutCubic,
      ),
    );
  }
}

class _ExpandedCoachHeader extends StatelessWidget {
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final int trades;
  final double winRate;
  final double totalPnl;
  final bool isLoading;
  final VoidCallback onToggle;

  const _ExpandedCoachHeader({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    required this.trades,
    required this.winRate,
    required this.totalPnl,
    required this.isLoading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _CoachHeaderCard(
          title: title,
          message: message,
          color: color,
          icon: icon,
          trades: trades,
          winRate: winRate,
          totalPnl: totalPnl,
          isLoading: isLoading,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 18,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CollapsedCoachTab extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final int trades;
  final double winRate;
  final double totalPnl;
  final bool isLoading;
  final VoidCallback onToggle;
  final String Function(double value) signedAmount;

  const _CollapsedCoachTab({
    required this.title,
    required this.color,
    required this.icon,
    required this.trades,
    required this.winRate,
    required this.totalPnl,
    required this.isLoading,
    required this.onToggle,
    required this.signedAmount,
  });

  @override
  Widget build(BuildContext context) {
    final pnlColor = totalPnl >= 0 ? AppColors.profit : AppColors.loss;
    final winRateColor = winRate >= 50 ? AppColors.profit : AppColors.loss;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: color.withOpacity(0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.18),
                  ),
                ),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Icon(
                        icon,
                        color: color,
                        size: 18,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _CompactStatText(
                text: '$trades trades',
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 7),
              _CompactDot(color: AppColors.textMuted),
              const SizedBox(width: 7),
              _CompactStatText(
                text: '${winRate.toStringAsFixed(0)}% WR',
                color: winRateColor,
              ),
              const SizedBox(width: 7),
              _CompactDot(color: AppColors.textMuted),
              const SizedBox(width: 7),
              _CompactStatText(
                text: signedAmount(totalPnl),
                color: pnlColor,
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactStatText extends StatelessWidget {
  final String text;
  final Color color;

  const _CompactStatText({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 10.8,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CompactDot extends StatelessWidget {
  final Color color;

  const _CompactDot({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3.5,
      height: 3.5,
      decoration: BoxDecoration(
        color: color.withOpacity(0.65),
        shape: BoxShape.circle,
      ),
    );
  }
}
