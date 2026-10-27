import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:trade_mind_ai/features/ai_chat/models/ai_response_result.dart';

import '../../../core/config/backend_config.dart';
import '../../journal/models/journal_entry.dart';
import '../models/ai_message.dart';

class GeminiService {
  Future<AiResponseResult> askWithJournal({
    required String question,
    required List<JournalEntry> journalEntries,
    AiMessage? previousUserMessage,
    AiMessage? previousAssistantMessage,
  }) async {
    if (!BackendConfig.hasBackendUrl) {
      return const AiResponseResult(
        success: false,
        answer: 'AI backend URL is missing.',
        error: 'AI backend URL is missing.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const AiResponseResult(
        success: false,
        answer: 'Please login first to use SignalFlow AI.',
        error: 'Please login first to use SignalFlow AI.',
      );
    }

    try {
      await user.reload();

      final freshUser = FirebaseAuth.instance.currentUser;

      if (freshUser == null) {
        return const AiResponseResult(
          success: false,
          answer: 'Please login first to use SignalFlow AI.',
          error: 'Please login first to use SignalFlow AI.',
        );
      }

      final idToken = await freshUser.getIdToken(true);

      if (idToken == null || idToken.trim().isEmpty) {
        return const AiResponseResult(
          success: false,
          answer:
              'Could not get Firebase login token. Please logout and login again.',
          error: 'Could not get Firebase login token.',
        );
      }

      final previousContext = {
        'question': previousUserMessage?.text ?? '',
        'answer': previousAssistantMessage?.text ?? '',
      };

      final response = await http
          .post(
            Uri.parse(BackendConfig.aiBackendUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'question': question,
              'journalEntries': journalEntries
                  .take(50)
                  .map((entry) => _journalEntryToJson(entry))
                  .toList(),
              'previousContext': previousContext,
            }),
          )
          .timeout(const Duration(seconds: 45));

      final decoded = _safeJsonDecode(response.body);

      AiRateLimitInfo? rateLimit;

      if (decoded is Map<String, dynamic> && decoded['rateLimit'] is Map) {
        rateLimit = AiRateLimitInfo.fromJson(
          Map<String, dynamic>.from(decoded['rateLimit'] as Map),
        );
      }

      if (response.statusCode == 429) {
        final error = decoded is Map<String, dynamic>
            ? decoded['error']?.toString()
            : null;

        return AiResponseResult(
          success: false,
          answer: error ?? 'Daily AI limit reached. Please try again tomorrow.',
          error: error ?? 'Daily AI limit reached.',
          rateLimit: rateLimit,
        );
      }

      if (response.statusCode == 401) {
        final error = decoded is Map<String, dynamic>
            ? decoded['error']?.toString()
            : null;

        return AiResponseResult(
          success: false,
          answer: error ?? 'Authentication failed. Please login again.',
          error: error ?? 'Authentication failed.',
          rateLimit: rateLimit,
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded is Map<String, dynamic>
            ? decoded['error']?.toString()
            : null;

        return AiResponseResult(
          success: false,
          answer: error ?? 'AI backend request failed: ${response.statusCode}',
          error: error ?? 'AI backend request failed.',
          rateLimit: rateLimit,
        );
      }

      if (decoded is! Map<String, dynamic>) {
        return AiResponseResult(
          success: false,
          answer: 'AI backend returned an invalid response.\n${response.body}',
          error: 'Invalid backend response.',
          rateLimit: rateLimit,
        );
      }

      final success = decoded['success'] == true;
      final answer = decoded['answer']?.toString().trim();

      if (!success || answer == null || answer.isEmpty) {
        final error = decoded['error']?.toString() ??
            'AI did not return an answer. Try again.';

        return AiResponseResult(
          success: false,
          answer: error,
          error: error,
          rateLimit: rateLimit,
        );
      }

      return AiResponseResult(
        success: true,
        answer: answer,
        rateLimit: rateLimit,
      );
    } catch (e) {
      return AiResponseResult(
        success: false,
        answer:
            'AI request failed. Please check your internet connection and try again.\n\n$e',
        error: e.toString(),
      );
    }
  }

  dynamic _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _journalEntryToJson(JournalEntry entry) {
    return {
      'pair': entry.pair,
      'side': entry.side,
      'entryPrice': entry.entryPrice,
      'exitPrice': entry.exitPrice,
      'leverage': entry.leverage,
      'positionSize': entry.positionSize,
      'pnlPercent': entry.pnlPercent,
      'pnlAmount': entry.pnlAmount,
      'isWin': entry.isWin,
      'isLoss': entry.isLoss,
      'setup': entry.setup,
      'emotion': entry.emotion,
      'notes': entry.notes,
      'createdAt': entry.createdAt?.toIso8601String(),
    };
  }
}
