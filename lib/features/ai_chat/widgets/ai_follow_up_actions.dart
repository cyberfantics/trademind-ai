part of '../screens/ai_chat_screen.dart';

class _AiFollowUpActions extends StatelessWidget {
  final AiMessage message;
  final void Function(String question) onAsk;

  const _AiFollowUpActions({
    required this.message,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        'Simpler',
        'Explain your last answer in simpler words.',
        Icons.lightbulb_outline_rounded,
      ),
      (
        'Plan',
        'Turn your last answer into a simple action plan.',
        Icons.task_alt_rounded,
      ),
      (
        'Checklist',
        'Make a checklist from your last answer.',
        Icons.checklist_rounded,
      ),
      (
        'Risk rules',
        'Make simple risk rules from your last answer.',
        Icons.shield_outlined,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (message.aiRemaining != null && message.aiLimit != null)
            _RequestsLeftChip(
              remaining: message.aiRemaining!,
              limit: message.aiLimit!,
            ),
          ...actions.map((item) {
            return Material(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: () => onAsk(item.$2),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.$3,
                        color: AppColors.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        item.$1,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RequestsLeftChip extends StatelessWidget {
  final int remaining;
  final int limit;

  const _RequestsLeftChip({
    required this.remaining,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    final color = remaining <= 1 ? AppColors.loss : AppColors.profit;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            '$remaining/$limit left',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

