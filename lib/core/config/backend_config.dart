class BackendConfig {
  static const String aiBackendUrl = String.fromEnvironment(
    'AI_BACKEND_URL',
    defaultValue: 'https://trademind-ai-zm2c.vercel.app/api/gemini-journal',
  );

  static const String debugTokenUrl = String.fromEnvironment(
    'AI_DEBUG_TOKEN_URL',
    defaultValue: 'https://trademind-ai-zm2c.vercel.app/debug/check-token',
  );

  static bool get hasBackendUrl => aiBackendUrl.trim().isNotEmpty;
}
