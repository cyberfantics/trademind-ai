class AiRateLimitInfo {
  final int limit;
  final int used;
  final int remaining;
  final DateTime? resetAt;

  const AiRateLimitInfo({
    required this.limit,
    required this.used,
    required this.remaining,
    this.resetAt,
  });

  factory AiRateLimitInfo.fromJson(Map<String, dynamic> json) {
    return AiRateLimitInfo(
      limit: _toInt(json['limit'], fallback: 5),
      used: _toInt(json['used'], fallback: 0),
      remaining: _toInt(json['remaining'], fallback: 0),
      resetAt: DateTime.tryParse(json['resetAt']?.toString() ?? ''),
    );
  }

  static int _toInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class AiResponseResult {
  final bool success;
  final String answer;
  final String? error;
  final AiRateLimitInfo? rateLimit;

  const AiResponseResult({
    required this.success,
    required this.answer,
    this.error,
    this.rateLimit,
  });
}
