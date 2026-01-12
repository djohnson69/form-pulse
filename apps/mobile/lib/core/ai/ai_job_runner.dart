import 'dart:typed_data';

import 'package:ai_service/ai_service.dart';

import 'ai_function_service.dart';

class AiJobRunner {
  AiJobRunner({
    required this.functionService,
    AIService? directService,
  }) : _directService = directService;

  final AiFunctionService functionService;
  final AIService? _directService;

  bool get hasDirectFallback => _directService != null;

  Future<String> runJob({
    required String type,
    String? inputText,
    Uint8List? imageBytes,
    Uint8List? audioBytes,
    String? audioMimeType,
    String? targetLanguage,
    int? checklistCount,
  }) async {
    try {
      return await functionService.runJob(
        type: type,
        inputText: inputText,
        imageBytes: imageBytes,
        audioBytes: audioBytes,
        audioMimeType: audioMimeType,
        targetLanguage: targetLanguage,
        checklistCount: checklistCount,
      );
    } catch (error) {
      if (_directService == null) {
        throw Exception(
          'AI function failed. Deploy the Supabase ai function and set OPENAI_API_KEY, or enable client fallback with OPENAI_API_KEY and OPENAI_CLIENT_FALLBACK=true. Details: $error',
        );
      }
      return _runDirect(
        type: type,
        inputText: inputText,
        imageBytes: imageBytes,
        audioBytes: audioBytes,
        targetLanguage: targetLanguage,
        checklistCount: checklistCount,
        originalError: error,
      );
    }
  }

  Future<String> _runDirect({
    required String type,
    String? inputText,
    Uint8List? imageBytes,
    Uint8List? audioBytes,
    String? targetLanguage,
    int? checklistCount,
    Object? originalError,
  }) async {
    if (audioBytes != null && audioBytes.isNotEmpty) {
      throw Exception(
        'Audio AI requires the Supabase ai function. Details: $originalError',
      );
    }
    final ai = _directService!;
    final imageAnalysis = await _analyzeImage(ai, imageBytes);
    final imageContext = _buildImageContextFromAnalysis(imageAnalysis);
    final combinedInput = _combineInput(inputText, imageContext);

    switch (type) {
      case 'photo_caption':
        return _runPhotoCaption(
          ai: ai,
          inputText: inputText,
          imageBytes: imageBytes,
          imageAnalysis: imageAnalysis,
        );
      case 'progress_recap':
        _ensureInput(combinedInput);
        return ai.generateProgressRecap(text: combinedInput!);
      case 'translation':
        _ensureInput(combinedInput);
        return ai.translateText(
          text: combinedInput!,
          targetLanguage: targetLanguage?.trim().isNotEmpty == true
              ? targetLanguage!.trim()
              : 'Spanish',
        );
      case 'checklist_builder':
        _ensureInput(combinedInput);
        final items = await ai.generateChecklist(
          context: combinedInput!,
          itemCount: checklistCount ?? 8,
        );
        return items.map((item) => '- $item').join('\n');
      case 'daily_log':
        _ensureInput(combinedInput);
        return ai.generateDailyLog(text: combinedInput!);
      case 'walkthrough_notes':
        _ensureInput(combinedInput);
        return ai.generateWalkthroughNotes(text: combinedInput!);
      case 'field_report':
        final notes = inputText?.trim() ?? '';
        if (notes.isEmpty && (imageContext == null || imageContext.isEmpty)) {
          throw Exception('Provide input text or attach an image.');
        }
        return ai.generateFieldReport(
          notes: notes.isEmpty ? imageContext! : notes,
          imageContext: notes.isEmpty ? null : imageContext,
        );
      case 'assistant':
        _ensureInput(combinedInput);
        return ai.assistantReply(prompt: combinedInput!);
      case 'summary':
      default:
        _ensureInput(combinedInput);
        return ai.summarizeText(text: combinedInput!);
    }
  }

  String? _combineInput(String? inputText, String? imageContext) {
    final input = inputText?.trim() ?? '';
    if (input.isEmpty && (imageContext == null || imageContext.isEmpty)) {
      return null;
    }
    if (imageContext == null || imageContext.isEmpty) {
      return input.isEmpty ? null : input;
    }
    if (input.isEmpty) return imageContext;
    return '$input\n\n$imageContext';
  }

  void _ensureInput(String? input) {
    if (input == null || input.trim().isEmpty) {
      throw Exception('Provide input text or attach an image.');
    }
  }

  Future<String> _runPhotoCaption({
    required AIService ai,
    String? inputText,
    Uint8List? imageBytes,
    ImageAnalysis? imageAnalysis,
  }) async {
    if (inputText != null && inputText.trim().isNotEmpty) {
      return ai.composeCaption(
        description: inputText.trim(),
        tags: imageAnalysis?.tags ?? const [],
      );
    }
    if (imageBytes == null || imageBytes.isEmpty) {
      throw Exception('Provide input text or attach an image.');
    }
    final analysis = imageAnalysis ?? await ai.analyzeImageBytes(imageBytes);
    return ai.composeCaption(
      description: analysis.description,
      tags: analysis.tags,
    );
  }

  Future<ImageAnalysis?> _analyzeImage(
    AIService ai,
    Uint8List? imageBytes,
  ) async {
    if (imageBytes == null || imageBytes.isEmpty) return null;
    return ai.analyzeImageBytes(imageBytes);
  }

  String? _buildImageContextFromAnalysis(ImageAnalysis? analysis) {
    if (analysis == null) return null;
    final tags = analysis.tags.isEmpty ? '' : ' Tags: ${analysis.tags.join(', ')}';
    return 'Image description: ${analysis.description}.$tags';
  }
}
