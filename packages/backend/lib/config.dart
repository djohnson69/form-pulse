import 'dart:io';

class AppConfig {
  AppConfig({
    required this.supabaseUrl,
    required this.supabaseServiceKey,
    required this.adminApiKey,
    required this.port,
  });

  final String supabaseUrl;
  final String supabaseServiceKey;
  final String adminApiKey;
  final int port;

  factory AppConfig.fromEnv() {
    final url = _require('SUPABASE_URL');
    final serviceKey = _require('SUPABASE_SERVICE_ROLE_KEY');
    final adminKey = _require('ADMIN_API_KEY');
    final port = int.tryParse(_optional('PORT') ?? '') ?? 8080;

    return AppConfig(
      supabaseUrl: url,
      supabaseServiceKey: serviceKey,
      adminApiKey: adminKey,
      port: port,
    );
  }
}

String _require(String key) {
  final value = _optional(key);
  if (value == null || value.isEmpty) {
    throw StateError('Missing required environment variable: $key');
  }
  return value;
}

String? _optional(String key) {
  return Platform.environment[key] ?? Platform.environment[key.toLowerCase()];
}
