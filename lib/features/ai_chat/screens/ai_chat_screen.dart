import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../journal/models/journal_entry.dart';
import '../../journal/services/journal_service.dart';
import '../models/ai_message.dart';
import '../services/gemini_service.dart';
import '../services/ai_chat_history_service.dart';

import '../services/ai_share_service.dart';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';

part '../widgets/ai_chat_header_widgets.dart';
part '../widgets/ai_message_bubble.dart';
part '../widgets/ai_follow_up_actions.dart';
part '../widgets/ai_formatted_answer.dart';
part '../widgets/ai_pdf_share_card.dart';

class AiChatScreen extends StatefulWidget {
  final String? initialQuestion;

  const AiChatScreen({
    super.key,
    this.initialQuestion,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _messageController = TextEditingController();
  final ScreenshotController _shareScreenshotController =
      ScreenshotController();

  final _journalService = JournalService();
  final _geminiService = GeminiService();
  final _chatHistoryService = AiChatHistoryService();
  final _aiShareService = AiShareService();
  final Map<String, GlobalKey> _messageKeys = {};

  final _scrollController = ScrollController();

  List<JournalEntry> _journalEntries = [];

  final List<AiMessage> _messages = [];

  bool _isLoadingJournal = true;
  bool _isSending = false;
  bool _forceRefreshJournalOnNextAsk = false;
  bool _showJumpToBottom = false;
  bool _didSendInitialQuestion = false;
  bool _isCoachHeaderExpanded = true;

  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();

    _messages.add(_welcomeMessage());
    _scrollController.addListener(_handleScroll);

    _loadJournal();

    _loadChatHistory().whenComplete(() {
      _sendInitialQuestionIfNeeded();
    });
  }

  void _sendInitialQuestionIfNeeded() {
    final question = widget.initialQuestion?.trim();

    if (_didSendInitialQuestion || question == null || question.isEmpty) {
      return;
    }

    _didSendInitialQuestion = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _forceRefreshJournalOnNextAsk = true;
      _sendMessage(question);
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final distanceFromBottom = _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;

    final shouldShow = distanceFromBottom > 320;

    if (shouldShow == _showJumpToBottom) return;

    setState(() {
      _showJumpToBottom = shouldShow;
    });
  }

  Future<void> _scrollToBottom({
    bool animated = true,
  }) async {
    if (!_scrollController.hasClients) return;

    final bottom = _scrollController.position.maxScrollExtent;

    if (animated) {
      await _scrollController.animateTo(
        bottom,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(bottom);
    }
  }

  GlobalKey _keyForMessage(AiMessage message) {
    final key = message.id ??
        message.turnId ??
        message.createdAt.microsecondsSinceEpoch.toString();

    return _messageKeys.putIfAbsent(
      key,
      () => GlobalKey(),
    );
  }

  AiMessage? _lastAssistantMessage() {
    final assistantMessages = _messages
        .where((message) => !message.isUser)
        .where((message) => !_isWelcomeMessage(message))
        .toList();

    if (assistantMessages.isEmpty) return null;

    return assistantMessages.last;
  }

  bool _isWelcomeMessage(AiMessage message) {
    return !message.isUser &&
        message.text.startsWith('Hi, I am your AI trading coach.');
  }

  Future<void> _loadChatHistory() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final savedMessages = await _chatHistoryService.getMessages(
        userId: user.uid,
        limit: 80,
      );

      if (!mounted) return;

      if (savedMessages.isNotEmpty) {
        setState(() {
          _messages
            ..clear()
            ..addAll(savedMessages);
        });

        _scrollToBottomSoon();
      }
    } catch (_) {
      // Chat can still work without old history.
    }
  }

  String _localId() {
    return 'local-${DateTime.now().microsecondsSinceEpoch}';
  }

  void _replaceMessageById(String id, AiMessage newMessage) {
    final index = _messages.indexWhere((message) => message.id == id);

    if (index == -1) return;

    setState(() {
      _messages[index] = newMessage;
    });
  }

  AiMessage? _lastUserMessage() {
    final userMessages = _messages
        .where((message) => message.isUser)
        .where((message) => message.text.trim().isNotEmpty)
        .toList();

    if (userMessages.isEmpty) return null;

    return userMessages.last;
  }

  bool _questionNeedsFreshJournal(String question) {
    final q = question.toLowerCase().trim();

    final journalKeywords = [
      'analyze my journal',
      'analyse my journal',
      'check my journal',
      'review my journal',
      'read my journal',
      'scan my journal',
      'my journal',
      'journal analysis',
      'analyze trades',
      'analyse trades',
      'check trades',
      'review trades',
      'my trades',
      'recent trades',
      'latest trades',
      'trading mistakes',
      'find my mistakes',
      'biggest mistake',
      'performance',
      'win rate',
      'pnl',
      'profit and loss',
      'risk',
      'setups',
      'emotions',
    ];

    return journalKeywords.any(q.contains);
  }

  AiMessage _welcomeMessage() {
    return AiMessage(
      role: 'assistant',
      text:
          'Hi, I am your AI trading coach. I can read your recent journal and help you find mistakes, emotions, weak setups, and what to improve next.',
      createdAt: DateTime.now(),
    );
  }

  Future<void> _deleteAiChatHistory() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _addAssistantMessage('Please login first.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete AI chat?'),
          content: const Text(
            'This will delete your saved AI questions and answers. Your trading journal will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _chatHistoryService.deleteAllMessages(
        userId: user.uid,
      );

      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..add(_welcomeMessage());
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI chat history deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete AI chat: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadJournal() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() => _isLoadingJournal = false);
      return;
    }

    try {
      final entries = await _journalService.getRecentJournal(
        userId: user.uid,
        limit: 50,
      );

      if (!mounted) return;

      setState(() {
        _journalEntries = entries;
        _isLoadingJournal = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoadingJournal = false);

      _addAssistantMessage(
        'I could not load your journal right now. Error: $e',
      );
    }
  }

  Future<void> _shareMessageAsText(AiMessage message) async {
    try {
      await _aiShareService.shareAsText(
        message: message,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share text: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareMessageAsPdf(AiMessage message) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating PDF...'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );

      final shareWidget = InheritedTheme.captureAll(
        context,
        Material(
          color: Colors.transparent,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: _AiResponsePdfShareCard(
              message: message,
            ),
          ),
        ),
      );

      final pngBytes = await _shareScreenshotController.captureFromLongWidget(
        shareWidget,
        context: context,
        pixelRatio: 2,
        delay: const Duration(milliseconds: 300),
        constraints: const BoxConstraints(
          maxWidth: 1080,
        ),
      );

      await _aiShareService.sharePngAsPdf(
        pngBytes: pngBytes,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create PDF: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openMessageActions(AiMessage message) async {
    if (_isWelcomeMessage(message)) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionTile(
                  icon: Icons.copy_rounded,
                  title: 'Copy message',
                  onTap: () {
                    Navigator.pop(context);
                    _copyMessage(message);
                  },
                ),
                _ActionTile(
                  icon: Icons.ios_share_rounded,
                  title: 'Share as text',
                  onTap: () {
                    Navigator.pop(context);
                    _shareMessageAsText(message);
                  },
                ),
                _ActionTile(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'Share as PDF',
                  onTap: () {
                    Navigator.pop(context);
                    _shareMessageAsPdf(message);
                  },
                ),
                _ActionTile(
                  icon: message.isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  title: message.isPinned ? 'Unpin message' : 'Pin message',
                  onTap: () {
                    Navigator.pop(context);
                    _togglePinMessage(message);
                  },
                ),
                if (message.isUser)
                  _ActionTile(
                    icon: Icons.edit_rounded,
                    title: 'Edit & ask again',
                    onTap: () {
                      Navigator.pop(context);
                      _editAndAskAgain(message);
                    },
                  ),
                if (!message.isUser)
                  _ActionTile(
                    icon: Icons.refresh_rounded,
                    title: 'Regenerate answer',
                    onTap: () {
                      Navigator.pop(context);
                      _regenerateFromMessage(message);
                    },
                  ),
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete this message',
                  isDanger: true,
                  onTap: () {
                    Navigator.pop(context);
                    _deleteOneMessage(message);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyMessage(AiMessage message) async {
    await Clipboard.setData(
      ClipboardData(text: message.text),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _togglePinMessage(AiMessage message) async {
    final user = FirebaseAuth.instance.currentUser;

    if (message.id == null || user == null) return;

    final newPinnedValue = !message.isPinned;

    try {
      await _chatHistoryService.togglePin(
        userId: user.uid,
        messageId: message.id!,
        isPinned: newPinnedValue,
        category: newPinnedValue ? _guessMessageCategory(message.text) : null,
      );

      if (!mounted) return;

      setState(() {
        final index = _messages.indexWhere((item) => item.id == message.id);

        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            isPinned: newPinnedValue,
            category:
                newPinnedValue ? _guessMessageCategory(message.text) : null,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update pin: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteOneMessage(AiMessage message) async {
    final isQuestionWithAnswer = message.isUser && message.turnId != null;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isQuestionWithAnswer
                ? 'Delete question and answer?'
                : 'Delete message?',
          ),
          content: Text(
            isQuestionWithAnswer
                ? 'This will delete this question and its relevant AI answer.'
                : 'This will delete only this message.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user != null) {
        if (isQuestionWithAnswer) {
          await _chatHistoryService.deleteTurnMessages(
            userId: user.uid,
            turnId: message.turnId!,
          );
        } else if (message.id != null && !message.id!.startsWith('local-')) {
          await _chatHistoryService.deleteMessage(
            userId: user.uid,
            messageId: message.id!,
          );
        }
      }

      if (!mounted) return;

      setState(() {
        if (isQuestionWithAnswer) {
          _messages.removeWhere((item) => item.turnId == message.turnId);
        } else {
          _messages.removeWhere((item) => item.id == message.id);
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete message: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editAndAskAgain(AiMessage message) async {
    final controller = TextEditingController(text: message.text);

    final editedText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit question'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Write improved question...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Ask again'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (editedText == null || editedText.trim().isEmpty) return;

    await _sendMessage(editedText.trim());
  }

  Future<void> _regenerateFromMessage(AiMessage message) async {
    final previousQuestion = _lastUserMessage();

    if (previousQuestion == null) {
      await _sendMessage('Regenerate your last answer.');
      return;
    }

    await _sendMessage(
      'Regenerate your answer for this question with clearer points: ${previousQuestion.text}',
    );
  }

  String _guessMessageCategory(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('risk')) return 'Risk';
    if (lower.contains('emotion') || lower.contains('discipline')) {
      return 'Emotion';
    }
    if (lower.contains('mistake') || lower.contains('loss')) {
      return 'Mistake';
    }
    if (lower.contains('setup') || lower.contains('entry')) {
      return 'Setup';
    }
    if (lower.contains('plan') || lower.contains('checklist')) {
      return 'Plan';
    }

    return 'General';
  }

  Future<void> _refreshJournal() async {
    setState(() {
      _isLoadingJournal = true;
      _forceRefreshJournalOnNextAsk = true;
    });

    await _loadJournal();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Journal refreshed. Next AI question will use latest journal.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendMessage([String? quickQuestion]) async {
    final question = (quickQuestion ?? _messageController.text).trim();

    if (question.isEmpty || _isSending) return;

    _messageController.clear();

    final user = FirebaseAuth.instance.currentUser;

    final previousUserMessage = _lastUserMessage();
    final previousAssistantMessage = _lastAssistantMessage();

    final hasPreviousContext =
        previousUserMessage != null && previousAssistantMessage != null;

    final needsFreshJournal = _questionNeedsFreshJournal(question);

    final shouldSendJournalData = _forceRefreshJournalOnNextAsk ||
        needsFreshJournal ||
        !hasPreviousContext;

    final tempUserId = _localId();

    final turnId = 'turn-${DateTime.now().microsecondsSinceEpoch}';

    final userMessage = AiMessage(
      id: tempUserId,
      turnId: turnId,
      role: 'user',
      text: question,
      createdAt: DateTime.now(),
      status: 'sending',
      source: shouldSendJournalData ? 'freshJournal' : 'followUp',
      usedJournal: shouldSendJournalData,
    );

    setState(() {
      _messages.add(userMessage);
      _isSending = true;
    });

    _scrollToBottomSoon();

    AiMessage? savedUserMessage;

    try {
      if (user != null) {
        savedUserMessage = await _chatHistoryService.saveMessage(
          userId: user.uid,
          message: userMessage.copyWith(status: 'sent'),
        );

        if (mounted) {
          _replaceMessageById(tempUserId, savedUserMessage);
        }
      }

      List<JournalEntry> entriesToSend = [];

      if (shouldSendJournalData && user != null) {
        final latestEntries = await _journalService.getRecentJournal(
          userId: user.uid,
          limit: 50,
        );

        entriesToSend = latestEntries;

        if (mounted) {
          setState(() {
            _journalEntries = latestEntries;
          });
        }
      }

      final result = await _geminiService.askWithJournal(
        question: question,
        journalEntries: entriesToSend,
        previousUserMessage: previousUserMessage,
        previousAssistantMessage: previousAssistantMessage,
      );

      if (!mounted) return;

      final tempAssistantId = _localId();

      final assistantMessage = AiMessage(
        id: tempAssistantId,
        turnId: turnId,
        role: 'assistant',
        text: result.answer,
        createdAt: DateTime.now(),
        status: result.success ? 'sent' : 'failed',
        source: shouldSendJournalData ? 'freshJournal' : 'followUp',
        usedJournal: shouldSendJournalData,
        aiRemaining: result.rateLimit?.remaining,
        aiLimit: result.rateLimit?.limit,
      );
      setState(() {
        _messages.add(assistantMessage);
        _isSending = false;
        _forceRefreshJournalOnNextAsk = false;
      });

      if (user != null) {
        final savedAssistantMessage = await _chatHistoryService.saveMessage(
          userId: user.uid,
          message: assistantMessage,
        );

        if (mounted) {
          _replaceMessageById(tempAssistantId, savedAssistantMessage);
        }
      }
    } catch (e) {
      if (!mounted) return;

      if (savedUserMessage == null && userMessage.id != null) {
        _replaceMessageById(
          userMessage.id!,
          userMessage.copyWith(status: 'failed'),
        );
      }

      setState(() {
        _messages.add(
          AiMessage(
            id: _localId(),
            role: 'assistant',
            text: 'AI error: $e',
            createdAt: DateTime.now(),
            status: 'failed',
            source: 'system',
          ),
        );

        _isSending = false;
      });
    }

    _scrollToBottomSoon();
  }

  void _addAssistantMessage(String text) {
    setState(() {
      _messages.add(
        AiMessage(
          role: 'assistant',
          text: text,
          createdAt: DateTime.now(),
        ),
      );
    });
  }

  void _scrollToBottomSoon() {
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      _scrollToBottom();
    });
  }

  int get _wins {
    return _journalEntries.where((entry) => entry.isWin).length;
  }

  int get _losses {
    return _journalEntries.where((entry) => entry.isLoss).length;
  }

  double get _winRate {
    if (_journalEntries.isEmpty) return 0;
    return (_wins / _journalEntries.length) * 100;
  }

  double get _totalPnl {
    return _journalEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.pnlAmount,
    );
  }

  String get _coachMoodTitle {
    if (_isLoadingJournal) return 'Reading your journal...';
    if (_journalEntries.isEmpty) return 'No journal data yet';
    if (_journalEntries.length < 3) return 'Need more trades';
    if (_totalPnl > 0 && _winRate >= 60) return 'Strong performance';
    if (_totalPnl > 0) return 'Net positive';
    if (_totalPnl < 0 && _losses > _wins) return 'Review mistakes';
    if (_totalPnl < 0) return 'Control risk';
    return 'Break-even zone';
  }

  String get _coachMoodText {
    if (_isLoadingJournal) {
      return 'Loading recent trades so AI can give better advice.';
    }

    if (_journalEntries.isEmpty) {
      return 'Add trades in your journal first, then AI can analyze your patterns.';
    }

    if (_journalEntries.length < 3) {
      return '${_journalEntries.length} trade${_journalEntries.length == 1 ? '' : 's'} loaded. Add more trades for stronger analysis.';
    }

    if (_totalPnl > 0 && _winRate >= 60) {
      return 'Good result. Ask AI which setups you should repeat.';
    }

    if (_totalPnl > 0) {
      return 'You are positive overall. Ask AI how to improve consistency.';
    }

    if (_totalPnl < 0 && _losses > _wins) {
      return 'Losses are higher. Ask AI to find your biggest mistakes.';
    }

    if (_totalPnl < 0) {
      return 'Your PnL is negative. Ask AI for a safer risk plan.';
    }

    return 'You are close to break-even. Ask AI how to improve entries.';
  }

  Color get _coachMoodColor {
    if (_isLoadingJournal) return AppColors.primary;
    if (_journalEntries.isEmpty) return AppColors.textMuted;
    if (_totalPnl > 0) return AppColors.profit;
    if (_totalPnl < 0) return AppColors.loss;
    return AppColors.primary;
  }

  IconData get _coachMoodIcon {
    if (_isLoadingJournal) return Icons.auto_awesome_rounded;
    if (_journalEntries.isEmpty) return Icons.book_outlined;
    if (_totalPnl > 0) return Icons.trending_up_rounded;
    if (_totalPnl < 0) return Icons.warning_amber_rounded;
    return Icons.balance_rounded;
  }

  Future<void> _openPinnedMessages() async {
    final pinned = _messages.where((message) => message.isPinned).toList();

    final selected = await showModalBottomSheet<AiMessage>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            builder: (context, controller) {
              if (pinned.isEmpty) {
                return const Center(
                  child: Text('No pinned advice yet.'),
                );
              }

              return ListView.separated(
                controller: controller,
                padding: const EdgeInsets.all(16),
                itemCount: pinned.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final message = pinned[index];

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.pop(context, message),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.push_pin_rounded,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  message.category ?? 'Pinned Advice',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.open_in_full_rounded,
                                color: AppColors.textMuted,
                                size: 15,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message.text,
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );

    if (selected != null) {
      await _scrollToMessage(selected);
    }
  }

  Future<void> _exportFullAiChatAsPdf() async {
    try {
      final exportMessages = _messages
          .where((message) => !_isWelcomeMessage(message))
          .where((message) => message.text.trim().isNotEmpty)
          .toList();

      if (exportMessages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No AI chat to export yet.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating full chat PDF...'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );

      await _aiShareService.shareFullChatAsPdf(
        messages: exportMessages,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export AI chat: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _scrollToMessage(AiMessage message) async {
    final index = _messages.indexWhere((item) => item.id == message.id);

    if (index == -1 || !_scrollController.hasClients) return;

    final position = _scrollController.position;
    final totalItems = _messages.length;

    if (totalItems <= 1) return;

    final averageItemHeight = position.maxScrollExtent / totalItems;

    double targetOffset = averageItemHeight * index;

    targetOffset = targetOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );

    await Future.delayed(const Duration(milliseconds: 180));

    final key = _keyForMessage(message);
    final targetContext = key.currentContext;

    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
    } else {
      final secondOffset = (targetOffset + 220).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );

      await _scrollController.animateTo(
        secondOffset,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );

      await Future.delayed(const Duration(milliseconds: 160));

      final secondContext = key.currentContext;

      if (secondContext != null) {
        await Scrollable.ensureVisible(
          secondContext,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.18,
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _highlightedMessageId = message.id;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      setState(() {
        _highlightedMessageId = null;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showQuickQuestions = _messages.length == 1 && !_isSending;

    return Scaffold(
      floatingActionButton: _showJumpToBottom
          ? Padding(
              padding: const EdgeInsets.only(bottom: 74),
              child: FloatingActionButton.small(
                tooltip: 'Jump to latest',
                onPressed: () => _scrollToBottom(),
                child: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
            )
          : null,
      appBar: AppBar(
        title: const Text('AI Journal Coach'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Export full AI chat',
            onPressed: _messages.length <= 1 || _isSending
                ? null
                : _exportFullAiChatAsPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Pinned advice',
            onPressed: _openPinnedMessages,
            icon: const Icon(Icons.push_pin_outlined),
          ),
          IconButton(
            tooltip: 'Delete AI chat',
            onPressed: _isSending ? null : _deleteAiChatHistory,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          IconButton(
            tooltip: 'Refresh journal',
            onPressed: _isLoadingJournal ? null : _refreshJournal,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          _CollapsibleCoachHeader(
            expanded: _isCoachHeaderExpanded,
            title: _coachMoodTitle,
            message: _coachMoodText,
            color: _coachMoodColor,
            icon: _coachMoodIcon,
            trades: _journalEntries.length,
            winRate: _winRate,
            totalPnl: _totalPnl,
            isLoading: _isLoadingJournal,
            onToggle: () {
              setState(() {
                _isCoachHeaderExpanded = !_isCoachHeaderExpanded;
              });
            },
          ),
          if (showQuickQuestions)
            _QuickQuestionsBar(
              onAsk: _sendMessage,
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length + (_isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isSending && index == _messages.length) {
                  return const _TypingBubble();
                }

                final message = _messages[index];
                final key = _keyForMessage(message);

                return RepaintBoundary(
                  key: key,
                  child: _MessageBubble(
                    message: message,
                    isHighlighted: _highlightedMessageId == message.id,
                    onLongPress: () => _openMessageActions(message),
                    onQuickAction: _sendMessage,
                    onShareText: () => _shareMessageAsText(message),
                    onSharePdf: () => _shareMessageAsPdf(message),
                  ),
                );
              },
            ),
          ),
          _InputBar(
            controller: _messageController,
            isSending: _isSending,
            onSend: () => _sendMessage(),
          ),
        ],
      ),
    );
  }
}
