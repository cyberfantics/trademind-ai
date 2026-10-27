part of '../screens/ai_chat_screen.dart';

class _MessageBubble extends StatelessWidget {
  final AiMessage message;
  final VoidCallback onLongPress;
  final void Function(String question) onQuickAction;

  final VoidCallback onShareText;
  final VoidCallback onSharePdf;
  final bool isHighlighted;

  const _MessageBubble({
    required this.message,
    required this.onLongPress,
    required this.onQuickAction,
    required this.onShareText,
    required this.onSharePdf,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isUser) ...[
              const _AssistantAvatar(),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.80,
                    ),
                    padding: EdgeInsets.fromLTRB(
                      isUser ? 14 : 12,
                      isUser ? 13 : 11,
                      isUser ? 14 : 12,
                      isUser ? 13 : 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF2563EB),
                                Color(0xFF7C3AED),
                              ],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF111827),
                                Color(0xFF0B1220),
                              ],
                            ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(22),
                        topRight: const Radius.circular(22),
                        bottomLeft: Radius.circular(isUser ? 22 : 6),
                        bottomRight: Radius.circular(isUser ? 6 : 22),
                      ),
                      border: isUser
                          ? null
                          : Border.all(
                              color: isHighlighted
                                  ? AppColors.profit.withOpacity(0.75)
                                  : AppColors.primary.withOpacity(0.18),
                              width: isHighlighted ? 2 : 1,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: isUser
                              ? AppColors.primary.withOpacity(0.16)
                              : Colors.black.withOpacity(0.16),
                          blurRadius: 18,
                          offset: const Offset(0, 9),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MessageMetaRow(
                            message: message,
                            onShareText: onShareText,
                            onSharePdf:
                                onSharePdf), // _MessageMetaRow now includes sharing callbacks

                        const SizedBox(height: 8),
                        isUser
                            ? Text(
                                message.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.42,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : _AiPremiumFormattedAnswer(
                                text: message.text,
                              ),
                      ],
                    ),
                  ),
                  if (!isUser && message.status == 'sent')
                    _AiFollowUpActions(
                      message: message,
                      onAsk: onQuickAction,
                    ),
                ],
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              const _UserAvatar(),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageMetaRow extends StatelessWidget {
  final AiMessage message;
  final VoidCallback onShareText;
  final VoidCallback onSharePdf;

  const _MessageMetaRow({
    required this.message,
    required this.onShareText,
    required this.onSharePdf,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (message.isPinned) {
      chips.add(
        const _MiniChip(
          icon: Icons.push_pin_rounded,
          label: 'Pinned',
          color: AppColors.primary,
        ),
      );
    }

    if (!message.isUser && message.source == 'freshJournal') {
      chips.add(
        const _MiniChip(
          icon: Icons.book_rounded,
          label: 'Fresh journal',
          color: AppColors.profit,
        ),
      );
    }

    if (!message.isUser && message.source == 'followUp') {
      chips.add(
        const _MiniChip(
          icon: Icons.forum_rounded,
          label: 'Follow-up',
          color: AppColors.textMuted,
        ),
      );
    }

    if (message.status == 'sending') {
      chips.add(
        const _MiniChip(
          icon: Icons.sync_rounded,
          label: 'Sending',
          color: AppColors.textMuted,
        ),
      );
    }

    if (message.status == 'failed') {
      chips.add(
        const _MiniChip(
          icon: Icons.error_outline_rounded,
          label: 'Failed',
          color: AppColors.loss,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: chips.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: chips,
                ),
        ),
        if (!message.isUser) ...[
          _TinyIconButton(
            icon: Icons.text_snippet_outlined,
            tooltip: 'Share text',
            onTap: onShareText,
          ),
          const SizedBox(width: 5),
          _TinyIconButton(
            icon: Icons.picture_as_pdf_rounded,
            tooltip: 'Share PDF',
            onTap: onSharePdf,
          ),
        ],
      ],
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TinyIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              color: Colors.white.withOpacity(0.70),
              size: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 31,
      width: 31,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.18),
        ),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: AppColors.primary,
        size: 17,
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 31,
      width: 31,
      decoration: BoxDecoration(
        color: AppColors.profit.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.profit.withOpacity(0.18),
        ),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: AppColors.profit,
        size: 17,
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _AssistantAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'AI is checking your journal...',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
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

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Ask AI about your journal...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onSubmitted: (_) {
                    if (!isSending) onSend();
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: isSending ? null : onSend,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(15),
              ),
              child: isSending
                  ? const SizedBox(
                      height: 19,
                      width: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDanger;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? AppColors.loss : AppColors.textMuted;

    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: color,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
