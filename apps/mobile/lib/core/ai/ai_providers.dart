import 'package:ai_service/ai_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_function_service.dart';
import 'ai_job_runner.dart';

const String _kOpenAIApiKey = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
const String _kOpenAIBaseUrl = String.fromEnvironment(
  'OPENAI_BASE_URL',
  defaultValue: 'https://api.openai.com/v1',
);
const String _kOpenAIModel = String.fromEnvironment(
  'OPENAI_MODEL',
  defaultValue: 'gpt-4o-mini',
);
const String _kOpenAIOrg = String.fromEnvironment('OPENAI_ORG', defaultValue: '');
const String _kOpenAIClientFallback =
    String.fromEnvironment('OPENAI_CLIENT_FALLBACK', defaultValue: '');

/// Provides a singleton AIService configured via --dart-define or env.
final aiServiceProvider = Provider<AIService>((ref) {
  if (_kOpenAIApiKey.isEmpty) {
    throw StateError('OPENAI_API_KEY is missing. Pass via --dart-define or environment.');
  }
  final org = _kOpenAIOrg.isEmpty ? null : _kOpenAIOrg;
  return AIService(
    apiKey: _kOpenAIApiKey,
    baseUrl: _kOpenAIBaseUrl,
    model: _kOpenAIModel,
    organization: org,
  );
});

final aiFunctionServiceProvider = Provider<AiFunctionService>((ref) {
  return AiFunctionService(Supabase.instance.client);
});

final aiJobRunnerProvider = Provider<AiJobRunner>((ref) {
  final functionService = ref.read(aiFunctionServiceProvider);
  AIService? directService;
  final allowFallback = _kOpenAIClientFallback.toLowerCase() == 'true';
  if (allowFallback) {
    try {
      directService = ref.read(aiServiceProvider);
    } catch (_) {
      directService = null;
    }
  }
  return AiJobRunner(
    functionService: functionService,
    directService: directService,
  );
});
