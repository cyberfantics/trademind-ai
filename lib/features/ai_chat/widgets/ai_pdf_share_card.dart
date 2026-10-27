part of '../screens/ai_chat_screen.dart';

// ignore: unused_element
class _AiFullChatPdfShareCard extends StatelessWidget {
  final List<AiMessage> messages;

  const _AiFullChatPdfShareCard({
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      padding: const EdgeInsets.all(42),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF020617),
            Color(0xFF0B1220),
            Color(0xFF111827),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(34),
        decoration: BoxDecoration(
          color: const Color(0xEE0F172A),
          borderRadius: BorderRadius.circular(42),
          border: Border.all(
            color: const Color(0x334F8CFF),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AiPdfHeader(),
            const SizedBox(height: 34),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF60A5FA).withOpacity(0.13),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF60A5FA).withOpacity(0.18),
                ),
              ),
              child: const Text(
                'FULL AI CHAT EXPORT',
                style: TextStyle(
                  color: Color(0xFF60A5FA),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 22),
            for (final message in messages)
              _AiPdfChatMessageCard(
                message: message,
              ),
            const SizedBox(height: 24),
            const _AiPdfFooter(),
          ],
        ),
      ),
    );
  }
}

class _AiPdfChatMessageCard extends StatelessWidget {
  final AiMessage message;

  const _AiPdfChatMessageCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isUser
            ? const Color(0xFF1D4ED8).withOpacity(0.26)
            : const Color(0xFF111827),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isUser
              ? const Color(0xFF60A5FA).withOpacity(0.26)
              : const Color(0x332563EB),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUser ? Icons.person_rounded : Icons.auto_awesome_rounded,
                color: isUser ? Colors.white : const Color(0xFF60A5FA),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                isUser ? 'User Question' : 'AI Coach',
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF60A5FA),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          isUser
              ? Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : _AiPremiumFormattedAnswer(
                  text: message.text,
                  showTopBar: false,
                ),
        ],
      ),
    );
  }
}

class _AiResponsePdfShareCard extends StatelessWidget {
  final AiMessage message;

  const _AiResponsePdfShareCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      padding: const EdgeInsets.all(42),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF020617),
            Color(0xFF0B1220),
            Color(0xFF111827),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(34),
        decoration: BoxDecoration(
          color: const Color(0xEE0F172A),
          borderRadius: BorderRadius.circular(42),
          border: Border.all(
            color: const Color(0x334F8CFF),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AiPdfHeader(),
            const SizedBox(height: 34),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF60A5FA).withOpacity(0.13),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF60A5FA).withOpacity(0.18),
                ),
              ),
              child: Text(
                message.isUser ? 'USER QUESTION' : 'AI COACH RESPONSE',
                style: const TextStyle(
                  color: Color(0xFF60A5FA),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 22),

            /// Clean answer box. No share buttons, no quick buttons.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0x332563EB),
                  width: 1.4,
                ),
              ),
              child: message.isUser
                  ? Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : _AiPremiumFormattedAnswer(
                      text: message.text,
                      showTopBar: false,
                    ),
            ),
            const SizedBox(height: 34),
            const _AiPdfFooter(),
          ],
        ),
      ),
    );
  }
}

class _AiPdfHeader extends StatelessWidget {
  const _AiPdfHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 82,
            height: 82,
            color: const Color(0xFF2563EB),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Text(
                    'SF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 22),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AiShareService.appName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 6),
              Text(
                AiShareService.appSubtitle,
                style: TextStyle(
                  color: Color(0xFF93C5FD),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: QrImageView(
            data: AiShareService.joinUrl,
            size: 104,
            backgroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _AiPdfFooter extends StatelessWidget {
  const _AiPdfFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          color: Colors.white.withOpacity(0.12),
          height: 1,
        ),
        const SizedBox(height: 20),
        const Text(
          'Generated by ${AiShareService.appName}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          AiShareService.joinUrl,
          style: TextStyle(
            color: Color(0xFF93C5FD),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
