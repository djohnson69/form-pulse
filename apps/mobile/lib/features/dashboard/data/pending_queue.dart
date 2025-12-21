import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    this.metadata,
    DateTime? queuedAt,
  }) : queuedAt = queuedAt ?? DateTime.now();

  final String formId;
  final Map<String, dynamic> data;
  final String submittedBy;
  final List<Map<String, dynamic>> attachments;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? metadata;
  final DateTime queuedAt;

  Map<String, dynamic> toJson() => {
        'formId': formId,
        'data': data,
        'submittedBy': submittedBy,
        'attachments': attachments,
        'location': location,
        'metadata': metadata,
        'queuedAt': queuedAt.toIso8601String(),
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
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
      queuedAt: json['queuedAt'] != null
          ? DateTime.parse(json['queuedAt'] as String)
          : DateTime.now(),
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
  static const _secureKeyName = 'pending_submissions_key';
  static const _maxQueueAge = Duration(days: 7);
  static final _secureStorage = FlutterSecureStorage();

  Future<void> add(PendingSubmission item) async {
    final list = await _readQueue();
    list.add(item.toJson());
    await _writeQueue(list);
  }

  Future<void> flush() async {
    final list = await _readQueue();
    if (list.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (final item in list) {
      final pending = PendingSubmission.fromJson(item);
      if (now.difference(pending.queuedAt) > _maxQueueAge) {
        continue;
      }
      try {
        final uploaded = await _uploadAttachments(pending.attachments);
        await _repo.createSubmission(
          formId: pending.formId,
          data: pending.data,
          submittedBy: pending.submittedBy,
          attachments: uploaded,
          location: pending.location,
          metadata: pending.metadata,
        );
      } catch (_) {
        // Keep in queue on failure.
        remaining.add(item);
      }
    }

    if (remaining.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } else {
      await _writeQueue(remaining);
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

Future<List<Map<String, dynamic>>> _readQueue() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(PendingSubmissionQueue._storageKey);
  if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
  final decrypted = await _decryptQueue(raw);
  final payload = decrypted ?? raw;
  try {
    final list = jsonDecode(payload) as List<dynamic>;
    return List<Map<String, dynamic>>.from(
      list.map((e) => Map<String, dynamic>.from(e as Map)),
    );
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
}

Future<void> _writeQueue(List<Map<String, dynamic>> list) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = jsonEncode(list);
  final encrypted = await _encryptQueue(raw);
  await prefs.setString(PendingSubmissionQueue._storageKey, encrypted);
}

Future<String> _encryptQueue(String plainText) async {
  final key = await _loadKey();
  final iv = IV.fromSecureRandom(12);
  final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
  final encrypted = encrypter.encrypt(plainText, iv: iv);
  return jsonEncode({
    'iv': iv.base64,
    'cipher': encrypted.base64,
  });
}

Future<String?> _decryptQueue(String payload) async {
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    if (!data.containsKey('iv') || !data.containsKey('cipher')) return null;
    final iv = IV.fromBase64(data['iv'] as String);
    final cipher = Encrypted.fromBase64(data['cipher'] as String);
    final key = await _loadKey();
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    return encrypter.decrypt(cipher, iv: iv);
  } catch (_) {
    return null;
  }
}

Future<Key> _loadKey() async {
  final existing = await PendingSubmissionQueue._secureStorage
      .read(key: PendingSubmissionQueue._secureKeyName);
  if (existing != null && existing.isNotEmpty) {
    return Key(base64Url.decode(existing));
  }
  final key = Key.fromSecureRandom(32);
  final encoded = base64UrlEncode(key.bytes);
  await PendingSubmissionQueue._secureStorage
      .write(key: PendingSubmissionQueue._secureKeyName, value: encoded);
  return key;
}

String _hashBytes(Uint8List bytes) =>
    sha256.convert(bytes).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
