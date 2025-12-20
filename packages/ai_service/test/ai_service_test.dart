import 'dart:convert';

import 'package:ai_service/ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('AIService configuration', () {
    test('normalizes baseUrl and model', () {
      final ai = AIService(apiKey: 'test', baseUrl: 'https://api.openai.com/v1/');
      expect(ai.baseUrl, equals('https://api.openai.com/v1'));
      expect(ai.model.isNotEmpty, isTrue);
    });
  });

  group('AIService parsing', () {
    test('validateData handles JSON content', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, contains('/chat/completions'));
        final body = jsonDecode(request.body) as Map;
        expect(body['model'], equals('gpt-4o-mini'));

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': '{"isValid":true,"suggestions":["ok"],"confidence":0.9}'
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final ai = AIService(apiKey: 'test', client: mock);
      final result = await ai.validateData(data: {'email': 'a@b.com'}, context: 'signup');

      expect(result.isValid, isTrue);
      expect(result.suggestions, contains('ok'));
      expect(result.confidence, closeTo(0.9, 1e-6));
    });

    test('enhanceFieldValue falls back on errors', () async {
      final mock = MockClient((_) async => http.Response('oops', 500));
      final ai = AIService(apiKey: 'test', client: mock);
      final result = await ai.enhanceFieldValue(value: 'Main st', fieldType: 'address');

      expect(result.enhancedValue, equals('Main st'));
      expect(result.suggestions, isNotEmpty);
      expect(result.confidence, equals(0.0));
    });
  });
}
