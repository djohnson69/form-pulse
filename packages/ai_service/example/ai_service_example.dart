import 'package:ai_service/ai_service.dart';

void main() {
  // Simple instantiation example (no network call).
  final ai = AIService(apiKey: 'demo-key');
  print('AI service ready with model: ${ai.model}');
}
