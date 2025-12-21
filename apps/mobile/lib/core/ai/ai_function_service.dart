import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AiFunctionService {
  AiFunctionService(this._client);

  final SupabaseClient _client;

  Future<String> runJob({
    required String type,
    String? inputText,
    Uint8List? imageBytes,
    Uint8List? audioBytes,
    String? audioMimeType,
    String? targetLanguage,
    int? checklistCount,
  }) async {
    final payload = <String, dynamic>{
      'type': type,
      if (inputText != null) 'inputText': inputText,
      if (targetLanguage != null && targetLanguage.isNotEmpty)
        'targetLanguage': targetLanguage,
      if (checklistCount != null) 'checklistCount': checklistCount,
    };
    if (imageBytes != null) {
      payload['imageBase64'] = base64Encode(imageBytes);
    }
    if (audioBytes != null) {
      payload['audioBase64'] = base64Encode(audioBytes);
      if (audioMimeType != null && audioMimeType.isNotEmpty) {
        payload['audioMimeType'] = audioMimeType;
      }
    }

    final FunctionResponse response;
    try {
      response = await _client.functions.invoke('ai', body: payload);
    } on FunctionException catch (error) {
      final data = _normalizeData(error.details);
      final rawDetails = error.details?.toString();
      final message = data['error']?.toString() ??
          (rawDetails == null || rawDetails.isEmpty ? null : rawDetails);
      if (error.status == 401 && (message == null || message.isEmpty)) {
        throw Exception('AI requires authentication. Sign in and try again.');
      }
      throw Exception(
        message ?? 'AI function failed (status ${error.status}).',
      );
    }
    final data = _normalizeData(response.data);
    if (response.status != 200) {
      throw Exception('AI function failed (status ${response.status}).');
    }
    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    final output = data['outputText']?.toString() ?? '';
    if (output.trim().isEmpty) {
      throw Exception('AI returned an empty response.');
    }
    return output;
  }

  Map<String, dynamic> _normalizeData(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return <String, dynamic>{};
  }
}
