import 'ai_service_base.dart';

/// Text extraction service using the AIService backend.
class TextExtractor {
  final AIService ai;

  TextExtractor(this.ai);

  /// Extract text from an image using vision models.
  Future<String> extractFromImage(String imagePath) => ai.extractTextFromImage(imagePath);

  /// Extract structured data from free text.
  Future<Map<String, dynamic>> extractStructuredData(String text, {String? schemaHint}) {
    return ai.extractStructuredData(text: text, schemaHint: schemaHint);
  }

  /// Extract a specific list of fields from text.
  Future<Map<String, String>> extractFields({
    required String text,
    required List<String> fields,
  }) {
    return ai.extractFields(text: text, fields: fields);
  }
}
