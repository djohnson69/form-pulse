import 'package:http/http.dart' as http;

import 'ai_service_base.dart';
import 'env_loader.dart';

const String _kApiKeyConst = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
const String _kBaseUrlConst = String.fromEnvironment('OPENAI_BASE_URL', defaultValue: '');
const String _kModelConst = String.fromEnvironment('OPENAI_MODEL', defaultValue: '');
const String _kOrgConst = String.fromEnvironment('OPENAI_ORG', defaultValue: '');

String? _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String? _envLookup(Map<String, String> env, String key) {
  final direct = env[key];
  if (direct != null && direct.trim().isNotEmpty) return direct.trim();
  final lowerKey = key.toLowerCase();
  for (final entry in env.entries) {
    if (entry.key.toLowerCase() == lowerKey && entry.value.trim().isNotEmpty) {
      return entry.value.trim();
    }
  }
  return null;
}

/// Holds OpenAI connection details loaded from env or build-time defines.
class AIServiceConfig {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String? organization;

  const AIServiceConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o-mini',
    this.organization,
  });

  /// Build configuration using (priority): env vars -> dart-define -> fallback.
  factory AIServiceConfig.fromEnvironment({
    String? fallbackApiKey,
    String? fallbackBaseUrl,
    String? fallbackModel,
    String? fallbackOrganization,
  }) {
    final env = loadEnv();
    final apiKey = _firstNonEmpty([
      _envLookup(env, 'OPENAI_API_KEY'),
      _kApiKeyConst.isEmpty ? null : _kApiKeyConst,
      fallbackApiKey,
    ]);

    if (apiKey == null) {
      throw StateError('OPENAI_API_KEY is missing; set it via env or --dart-define.');
    }

    final baseUrl = _firstNonEmpty([
          _envLookup(env, 'OPENAI_BASE_URL'),
          _kBaseUrlConst.isEmpty ? null : _kBaseUrlConst,
          fallbackBaseUrl,
        ]) ??
        'https://api.openai.com/v1';

    final model = _firstNonEmpty([
          _envLookup(env, 'OPENAI_MODEL'),
          _kModelConst.isEmpty ? null : _kModelConst,
          fallbackModel,
        ]) ??
        'gpt-4o-mini';

    final organization = _firstNonEmpty([
      _envLookup(env, 'OPENAI_ORG'),
      _kOrgConst.isEmpty ? null : _kOrgConst,
      fallbackOrganization,
    ]);

    return AIServiceConfig(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      organization: organization,
    );
  }

  /// Convenience factory when you want to pass in a mock HTTP client for tests.
  AIService toService({http.Client? client}) => AIService(
        apiKey: apiKey,
        baseUrl: baseUrl,
        model: model,
        organization: organization,
        client: client,
      );
}
