import 'dart:convert';

import 'package:http/http.dart' as http;

import 'file_loader.dart';

/// AI Service for data validation and enhancement backed by OpenAI chat APIs.
class AIService {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String? organization;
  final http.Client _client;

  AIService({
    required this.apiKey,
    String? baseUrl,
    String? model,
    this.organization,
    http.Client? client,
  })  : baseUrl = (baseUrl ?? 'https://api.openai.com/v1').replaceAll(RegExp(r'/+$'), ''),
        model = model ?? 'gpt-4o-mini',
        _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        if (organization != null) 'OpenAI-Organization': organization!,
      };

  Future<Map<String, dynamic>> _postChat({
    required List<Map<String, dynamic>> messages,
    Map<String, dynamic>? responseFormat,
    double temperature = 0.2,
  }) async {
    final uri = Uri.parse('$baseUrl/chat/completions');
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': temperature,
      if (responseFormat != null) 'response_format': responseFormat,
    });

    final response = await _client
        .post(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 45));

    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AIServiceException(
        'OpenAI request failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  String _contentToText(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      return content
          .map((chunk) =>
              chunk is Map && chunk['type'] == 'text' ? chunk['text'] ?? '' : '$chunk')
          .join('\n');
    }
    return content?.toString() ?? '';
  }

  Map<String, dynamic> _contentToJson(dynamic content) {
    if (content is Map<String, dynamic>) return content;
    final text = _contentToText(content);
    final parsed = jsonDecode(text) as Object?;
    if (parsed is Map<String, dynamic>) return parsed;
    throw AIServiceException('Expected JSON object but received: $text');
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) return [value];
    return [];
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Validate form data using OpenAI and return structured guidance.
  Future<ValidationResult> validateData({
    required Map<String, dynamic> data,
    required String context,
  }) async {
    try {
      final response = await _postChat(
        messages: [
          {
            'role': 'system',
            'content':
                'You validate form submissions. Respond with JSON: {"isValid": bool, "suggestions": string[], "confidence": number between 0 and 1, "errorMessage"?: string}. Keep suggestions concise.',
          },
          {
            'role': 'user',
            'content': 'Context: $context\nData: ${jsonEncode(data)}',
          },
        ],
        responseFormat: {'type': 'json_object'},
      );

      final content = response['choices']?[0]?['message']?['content'];
      final parsed = _contentToJson(content);

      return ValidationResult(
        isValid: parsed['isValid'] == true,
        suggestions: _stringList(parsed['suggestions']),
        errorMessage: parsed['errorMessage']?.toString(),
        confidence: _asDouble(parsed['confidence']),
      );
    } catch (error) {
      return ValidationResult(
        isValid: false,
        suggestions: ['AI validation failed'],
        errorMessage: '$error',
      );
    }
  }

  /// Validate and enhance a single field.
  Future<EnhancedValue> enhanceFieldValue({
    required String value,
    required String fieldType,
    String? context,
  }) async {
    try {
      final response = await _postChat(
        messages: [
          {
            'role': 'system',
            'content':
                'You refine individual form fields. Return JSON: {"enhancedValue": string, "suggestions": string[], "confidence": number 0-1, "metadata"?: object}. Keep changes minimal.',
          },
          {
            'role': 'user',
            'content': 'Field type: $fieldType\nContext: ${context ?? 'n/a'}\nValue: $value',
          },
        ],
        responseFormat: {'type': 'json_object'},
      );

      final content = response['choices']?[0]?['message']?['content'];
      final parsed = _contentToJson(content);

      return EnhancedValue(
        originalValue: value,
        enhancedValue: parsed['enhancedValue']?.toString() ?? value,
        confidence: _asDouble(parsed['confidence']) ?? 0.0,
        suggestions: _stringList(parsed['suggestions']),
        metadata: parsed['metadata'] as Map<String, dynamic>?,
      );
    } catch (error) {
      return EnhancedValue(
        originalValue: value,
        enhancedValue: value,
        confidence: 0.0,
        suggestions: ['AI enhancement failed'],
        metadata: {'error': '$error'},
      );
    }
  }

  /// Generate field-level suggestions for builders.
  Future<List<String>> generateSuggestions({
    required String fieldType,
    required String context,
  }) async {
    try {
      final response = await _postChat(
        messages: [
          {
            'role': 'system',
            'content':
                'You propose short suggestions for form fields. Reply with a JSON array of strings, ordered by usefulness.',
          },
          {
            'role': 'user',
            'content': 'Field type: $fieldType\nContext: $context',
          },
        ],
        responseFormat: {'type': 'json_object'},
      );

      final content = response['choices']?[0]?['message']?['content'];
      final parsed = _contentToJson(content);
      final suggestions = parsed.values.firstWhere(
        (value) => value is List || value is String,
        orElse: () => parsed,
      );
      return _stringList(suggestions);
    } catch (_) {
      return [];
    }
  }

  /// Extract text from an image using a vision-capable model.
  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final base64Image = await loadBase64Image(imagePath);
      final response = await _postChat(
        messages: [
          {
            'role': 'system',
            'content': 'You perform OCR and return only the extracted text.',
          },
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Extract all visible text.'},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/png;base64,$base64Image'},
              },
            ],
          },
        ],
      );

      final content = response['choices']?[0]?['message']?['content'];
      return _contentToText(content).trim();
    } catch (error) {
      return 'OCR failed: $error';
    }
  }

  /// Extract structured data from unstructured text.
  Future<Map<String, dynamic>> extractStructuredData({
    required String text,
    String? schemaHint,
  }) async {
    try {
      final response = await _postChat(
        messages: [
          {
            'role': 'system',
            'content':
                'Extract structured data. Return JSON matching the requested schema when provided. Include only fields you can infer confidently.',
          },
          {
            'role': 'user',
            'content': 'Schema hint: ${schemaHint ?? 'none'}\nText: $text',
          },
        ],
        responseFormat: {'type': 'json_object'},
      );

      final content = response['choices']?[0]?['message']?['content'];
      return _contentToJson(content);
    } catch (error) {
      return {'error': '$error'};
    }
  }

  /// Extract a fixed set of fields from text.
  Future<Map<String, String>> extractFields({
    required String text,
    required List<String> fields,
  }) async {
    try {
      final response = await _postChat(
        messages: [
          {
            'role': 'system',
            'content':
                'Return a JSON object with the requested keys only. Values should be strings; leave missing fields empty strings.',
          },
          {
            'role': 'user',
            'content': 'Fields: ${fields.join(', ')}\nText: $text',
          },
        ],
        responseFormat: {'type': 'json_object'},
      );

      final content = response['choices']?[0]?['message']?['content'];
      final parsed = _contentToJson(content);
      return parsed.map((key, value) => MapEntry(key, value?.toString() ?? ''));
    } catch (error) {
      return {'error': '$error'};
    }
  }

  /// Analyze image content for description and tags.
  Future<ImageAnalysis> analyzeImage(String imagePath) async {
    try {
      final base64Image = await loadBase64Image(imagePath);
      final response = await _postChat(
        messages: [
          {
            'role': 'system',
            'content':
                'You are an image analyst. Respond with JSON: {"description": string, "tags": string[], "confidence": number 0-1, "metadata"?: object}.',
          },
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Describe this image and list key tags.'},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/png;base64,$base64Image'},
              },
            ],
          },
        ],
        responseFormat: {'type': 'json_object'},
      );

      final content = response['choices']?[0]?['message']?['content'];
      final parsed = _contentToJson(content);

      return ImageAnalysis(
        description: parsed['description']?.toString() ?? 'No description',
        tags: _stringList(parsed['tags']),
        confidence: _asDouble(parsed['confidence']) ?? 0.0,
        metadata: parsed['metadata'] as Map<String, dynamic>?,
      );
    } catch (error) {
      return ImageAnalysis(
        description: 'Image analysis failed: $error',
        tags: const [],
        confidence: 0.0,
        metadata: {'error': '$error'},
      );
    }
  }

  /// Detect objects in an image.
  Future<List<DetectedObject>> detectObjects(String imagePath) async {
    try {
      final base64Image = await loadBase64Image(imagePath);
      final response = await _postChat(
        messages: [
          {
            'role': 'system',
            'content':
                'Identify objects. Return JSON array of {"label": string, "confidence": number, "boundingBox": {"x": number, "y": number, "width": number, "height": number}}.',
          },
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Detect objects in this image.'},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/png;base64,$base64Image'},
              },
            ],
          },
        ],
        responseFormat: {'type': 'json_object'},
      );

      final content = response['choices']?[0]?['message']?['content'];
      final parsed = _contentToJson(content);
      final rawList = parsed.values.firstWhere(
        (value) => value is List,
        orElse: () => parsed['objects'] ?? [],
      );

      if (rawList is List) {
        return rawList
            .whereType<Map>()
            .map((item) => DetectedObject(
                  label: item['label']?.toString() ?? 'unknown',
                  confidence: _asDouble(item['confidence']) ?? 0.0,
                    boundingBox: (item['boundingBox'] as Map?)?.map(
                      (k, v) => MapEntry(k.toString(), _asDouble(v) ?? 0.0),
                      ) ??
                      {},
                ))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Check image quality for form submissions.
  Future<QualityCheck> checkImageQuality(String imagePath) async {
    try {
      final base64Image = await loadBase64Image(imagePath);
      final response = await _postChat(
        messages: [
          {
            'role': 'system',
            'content':
                'Assess if an image is acceptable for documentation. Return JSON: {"isAcceptable": bool, "issues": string[], "score": number 0-1}.',
          },
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Check sharpness, lighting, and legibility.'},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/png;base64,$base64Image'},
              },
            ],
          },
        ],
        responseFormat: {'type': 'json_object'},
      );

      final content = response['choices']?[0]?['message']?['content'];
      final parsed = _contentToJson(content);

      return QualityCheck(
        isAcceptable: parsed['isAcceptable'] == true,
        issues: _stringList(parsed['issues']),
        score: _asDouble(parsed['score']) ?? 0.0,
      );
    } catch (error) {
      return QualityCheck(
        isAcceptable: false,
        issues: ['Quality check failed: $error'],
        score: 0.0,
      );
    }
  }
}

class AIServiceException implements Exception {
  final String message;
  AIServiceException(this.message);
  @override
  String toString() => message;
}

/// Validation result from AI service.
class ValidationResult {
  final bool isValid;
  final List<String> suggestions;
  final String? errorMessage;
  final double? confidence;

  ValidationResult({
    required this.isValid,
    required this.suggestions,
    this.errorMessage,
    this.confidence,
  });
}

/// Image analysis result.
class ImageAnalysis {
  final String description;
  final List<String> tags;
  final double confidence;
  final Map<String, dynamic>? metadata;

  ImageAnalysis({
    required this.description,
    required this.tags,
    required this.confidence,
    this.metadata,
  });
}

/// Enhanced field value with AI suggestions.
class EnhancedValue {
  final String originalValue;
  final String enhancedValue;
  final double confidence;
  final List<String> suggestions;
  final Map<String, dynamic>? metadata;

  EnhancedValue({
    required this.originalValue,
    required this.enhancedValue,
    required this.confidence,
    required this.suggestions,
    this.metadata,
  });
}

/// Detected object details.
class DetectedObject {
  final String label;
  final double confidence;
  final Map<String, double> boundingBox;

  DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
}

/// Image quality assessment result.
class QualityCheck {
  final bool isAcceptable;
  final List<String> issues;
  final double score;

  QualityCheck({
    required this.isAcceptable,
    required this.issues,
    required this.score,
  });
}
