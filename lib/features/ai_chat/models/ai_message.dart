import 'package:cloud_firestore/cloud_firestore.dart';

class AiMessage {
  final String? id;
  final String? turnId;

  final String role;
  final String text;
  final DateTime createdAt;

  final bool isPinned;
  final String? category;

  /// sent, sending, failed
  final String status;

  /// freshJournal, followUp, system, none
  final String source;

  final bool usedJournal;

  /// Stores remaining request count after this AI answer.
  final int? aiRemaining;
  final int? aiLimit;

  const AiMessage({
    this.id,
    this.turnId,
    required this.role,
    required this.text,
    required this.createdAt,
    this.isPinned = false,
    this.category,
    this.status = 'sent',
    this.source = 'none',
    this.usedJournal = false,
    this.aiRemaining,
    this.aiLimit,
  });

  bool get isUser => role == 'user';

  AiMessage copyWith({
    String? id,
    String? turnId,
    String? role,
    String? text,
    DateTime? createdAt,
    bool? isPinned,
    String? category,
    String? status,
    String? source,
    bool? usedJournal,
    int? aiRemaining,
    int? aiLimit,
  }) {
    return AiMessage(
      id: id ?? this.id,
      turnId: turnId ?? this.turnId,
      role: role ?? this.role,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
      category: category ?? this.category,
      status: status ?? this.status,
      source: source ?? this.source,
      usedJournal: usedJournal ?? this.usedJournal,
      aiRemaining: aiRemaining ?? this.aiRemaining,
      aiLimit: aiLimit ?? this.aiLimit,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'turnId': turnId,
      'role': role,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPinned': isPinned,
      'category': category,
      'status': status,
      'source': source,
      'usedJournal': usedJournal,
      'aiRemaining': aiRemaining,
      'aiLimit': aiLimit,
    };
  }

  factory AiMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final timestamp = data['createdAt'];

    return AiMessage(
      id: doc.id,
      turnId: data['turnId']?.toString(),
      role: data['role']?.toString() ?? 'assistant',
      text: data['text']?.toString() ?? '',
      createdAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
              DateTime.now(),
      isPinned: data['isPinned'] == true,
      category: data['category']?.toString(),
      status: data['status']?.toString() ?? 'sent',
      source: data['source']?.toString() ?? 'none',
      usedJournal: data['usedJournal'] == true,
      aiRemaining: _toNullableInt(data['aiRemaining']),
      aiLimit: _toNullableInt(data['aiLimit']),
    );
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
