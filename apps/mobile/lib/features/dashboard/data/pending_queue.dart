import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard_repository.dart';
import '../../../core/utils/file_bytes_loader.dart';

class PendingSubmission {
  PendingSubmission({
    required this.formId,
    required this.data,
    required this.submittedBy,
    this.attachments = const [],
    this.location,
  });

  final String formId;
  final Map<String, dynamic> data;
  final String submittedBy;
  final List<Map<String, dynamic>> attachments;
  final Map<String, dynamic>? location;

  Map<String, dynamic> toJson() => {
        'formId': formId,
        'data': data,
        'submittedBy': submittedBy,
        'attachments': attachments,
        'location': location,
      };

  factory PendingSubmission.fromJson(Map<String, dynamic> json) {
    return PendingSubmission(
      formId: json['formId'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      submittedBy: json['submittedBy'] as String,
      attachments: (json['attachments'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      location: json['location'] == null
          ? null
          : Map<String, dynamic>.from(json['location'] as Map),
    );
  }
}

class PendingSubmissionQueue {
  PendingSubmissionQueue(
    this._repo,
    this._supabase, {
    required this.bucketName,
    this.orgId,
  });

  final DashboardRepositoryBase _repo;
  final SupabaseClient _supabase;
  final String bucketName;
  final String? orgId;

  static const _storageKey = 'pending_submissions';

  Future<void> add(PendingSubmission item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final list = raw == null
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
    list.add(item.toJson());
    await prefs.setString(_storageKey, jsonEncode(list));
  }

  Future<void> flush() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    final list = List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final remaining = <Map<String, dynamic>>[];

    for (final item in list) {
      final pending = PendingSubmission.fromJson(item);
      try {
        final uploaded = await _uploadAttachments(pending.attachments);
        await _repo.createSubmission(
          formId: pending.formId,
          data: pending.data,
          submittedBy: pending.submittedBy,
          attachments: uploaded,
          location: pending.location,
        );
      } catch (_) {
        // Keep in queue on failure.
        remaining.add(item);
      }
    }

    if (remaining.isEmpty) {
      await prefs.remove(_storageKey);
    } else {
      await prefs.setString(_storageKey, jsonEncode(remaining));
    }
  }

  Future<List<Map<String, dynamic>>> _uploadAttachments(
    List<Map<String, dynamic>> attachments,
  ) async {
    final results = <Map<String, dynamic>>[];
    for (final att in attachments) {
      final bytesBase64 = att['bytes'] as String?;
      final pathValue = att['path'] as String?;
      Uint8List? bytes;
      if (bytesBase64 != null) {
        bytes = base64Decode(bytesBase64);
      } else if (pathValue != null) {
        bytes = await loadFileBytes(pathValue);
      }
      if (bytes == null) {
        results.add(att);
        continue;
      }
      final prefix = orgId != null ? 'org-$orgId' : 'public';
      final path =
          '$prefix/submissions/${DateTime.now().microsecondsSinceEpoch}_${att['filename'] ?? 'file'}';
      await _supabase.storage
          .from(bucketName)
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
      final url = _supabase.storage.from(bucketName).getPublicUrl(path);
      final nextMetadata = <String, dynamic>{
        ...(att['metadata'] as Map? ?? const <String, dynamic>{}),
        'storagePath': path,
        'bucket': bucketName,
      };
      results.add({
        ...att,
        'url': url,
        'hash': _hashBytes(bytes),
        'bytes': null,
        'metadata': nextMetadata,
      });
    }
    return results;
  }
}

String _hashBytes(Uint8List bytes) =>
    sha256.convert(bytes).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
