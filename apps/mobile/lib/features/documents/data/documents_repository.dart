import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/storage_utils.dart';

class DocumentSignature {
  DocumentSignature({
    required this.url,
    required this.signedAt,
    this.signerName,
    this.signerId,
    this.storagePath,
    this.bucket,
  });

  final String url;
  final DateTime signedAt;
  final String? signerName;
  final String? signerId;
  final String? storagePath;
  final String? bucket;

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'signedAt': signedAt.toIso8601String(),
      'signerName': signerName,
      'signerId': signerId,
      'storagePath': storagePath,
      'bucket': bucket,
    };
  }

  factory DocumentSignature.fromJson(Map<String, dynamic> json) {
    return DocumentSignature(
      url: json['url'] as String,
      signedAt: DateTime.parse(json['signedAt'] as String),
      signerName: json['signerName'] as String?,
      signerId: json['signerId'] as String?,
      storagePath: json['storagePath'] as String? ?? json['path'] as String?,
      bucket: json['bucket'] as String?,
    );
  }
}

abstract class DocumentsRepositoryBase {
  Future<List<Document>> fetchDocuments({String? projectId});
  Future<List<DocumentVersion>> fetchVersions(String documentId);
  Future<Document> createDocument({
    required String title,
    String? description,
    String? category,
    String? projectId,
    List<String>? tags,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required int fileSize,
    String? version,
    bool isTemplate,
    bool isPublished,
    Map<String, dynamic>? metadata,
    bool notifyOrg,
  });
  Future<Document> addVersion({
    required Document document,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required int fileSize,
    required String version,
    String? title,
    String? description,
    String? category,
    String? projectId,
    List<String>? tags,
    bool? isTemplate,
    bool? isPublished,
    Map<String, dynamic>? metadata,
    bool notifyOrg,
  });
  Future<Document> updateDocument({
    required String documentId,
    String? title,
    String? description,
    String? category,
    String? projectId,
    List<String>? tags,
    bool? isTemplate,
    bool? isPublished,
    Map<String, dynamic>? metadata,
  });
  Future<Document> addSignature({
    required Document document,
    required Uint8List bytes,
    String? signerName,
  });
  Future<void> deleteDocument({required Document document});
}

class SupabaseDocumentsRepository implements DocumentsRepositoryBase {
  SupabaseDocumentsRepository(this._client);

  final SupabaseClient _client;
  static final _uuid = Uuid();
  static const _bucketName =
      String.fromEnvironment('SUPABASE_BUCKET', defaultValue: 'formbridge-attachments');

  @override
  Future<List<Document>> fetchDocuments({String? projectId}) async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    try {
      final query = _client.from('documents').select().eq('org_id', orgId);
      final res = projectId == null
          ? await query.order('updated_at', ascending: false)
          : await query.eq('project_id', projectId).order(
              'updated_at',
              ascending: false,
            );
      final docs = (res as List<dynamic>)
          .map((row) => _mapDocument(Map<String, dynamic>.from(row as Map)))
          .toList();
      return Future.wait(docs.map(_signDocument));
    } catch (e, st) {
      developer.log(
        'Supabase fetchDocuments failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<DocumentVersion>> fetchVersions(String documentId) async {
    try {
      final res = await _client
          .from('document_versions')
          .select()
          .eq('document_id', documentId)
          .order('created_at', ascending: false);
      final versions = (res as List<dynamic>)
          .map((row) => _mapVersion(Map<String, dynamic>.from(row as Map)))
          .toList();
      return Future.wait(versions.map(_signVersion));
    } catch (e, st) {
      developer.log(
        'Supabase fetchVersions failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Document> createDocument({
    required String title,
    String? description,
    String? category,
    String? projectId,
    List<String>? tags,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required int fileSize,
    String? version,
    bool isTemplate = false,
    bool isPublished = true,
    Map<String, dynamic>? metadata,
    bool notifyOrg = false,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization to upload documents.');
    }
    final documentId = _uuid.v4();
    final versionLabel = version ?? 'v1';
    final path = await _uploadFile(
      orgId: orgId,
      documentId: documentId,
      filename: filename,
      mimeType: mimeType,
      bytes: bytes,
    );
    final mergedMetadata = {
      ...?metadata,
      'storagePath': path,
      'bucket': _bucketName,
    };
    final payload = {
      'id': documentId,
      'org_id': orgId,
      'project_id': projectId,
      'title': title,
      'description': description,
      'category': category,
      'file_url': path,
      'filename': filename,
      'mime_type': mimeType,
      'file_size': fileSize,
      'version': versionLabel,
      'is_template': isTemplate,
      'is_published': isPublished,
      'tags': tags ?? const <String>[],
      'uploaded_by': _client.auth.currentUser?.id,
      'metadata': mergedMetadata,
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      final res = await _client.from('documents').insert(payload).select().single();
      await _client.from('document_versions').insert({
        'org_id': orgId,
        'document_id': documentId,
        'version': versionLabel,
        'file_url': path,
        'filename': filename,
        'mime_type': mimeType,
        'file_size': fileSize,
        'uploaded_by': _client.auth.currentUser?.id,
        'metadata': mergedMetadata,
      });
      final doc = _mapDocument(Map<String, dynamic>.from(res as Map));
      if (notifyOrg) {
        await _notifyOrgMembers(
          orgId: orgId,
          title: 'New document uploaded',
          body: doc.title,
          type: 'document',
        );
      }
      return doc;
    } catch (e, st) {
      developer.log(
        'Supabase createDocument failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Document> addVersion({
    required Document document,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required int fileSize,
    required String version,
    String? title,
    String? description,
    String? category,
    String? projectId,
    List<String>? tags,
    bool? isTemplate,
    bool? isPublished,
    Map<String, dynamic>? metadata,
    bool notifyOrg = false,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization to upload documents.');
    }
    final path = await _uploadFile(
      orgId: orgId,
      documentId: document.id,
      filename: filename,
      mimeType: mimeType,
      bytes: bytes,
    );
    final mergedMetadata = {
      ...?metadata,
      'storagePath': path,
      'bucket': _bucketName,
    };
    final updatePayload = <String, dynamic>{
      'file_url': path,
      'filename': filename,
      'mime_type': mimeType,
      'file_size': fileSize,
      'version': version,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) updatePayload['title'] = title;
    if (description != null) updatePayload['description'] = description;
    if (category != null) updatePayload['category'] = category;
    if (projectId != null) updatePayload['project_id'] = projectId;
    if (tags != null) updatePayload['tags'] = tags;
    if (isTemplate != null) updatePayload['is_template'] = isTemplate;
    if (isPublished != null) updatePayload['is_published'] = isPublished;
    updatePayload['metadata'] = mergedMetadata;
    try {
      final res = await _client
          .from('documents')
          .update(updatePayload)
          .eq('id', document.id)
          .select()
          .single();
      await _client.from('document_versions').insert({
        'org_id': orgId,
        'document_id': document.id,
        'version': version,
        'file_url': path,
        'filename': filename,
        'mime_type': mimeType,
        'file_size': fileSize,
        'uploaded_by': _client.auth.currentUser?.id,
        'metadata': mergedMetadata,
      });
      final doc = _mapDocument(Map<String, dynamic>.from(res as Map));
      if (notifyOrg) {
        await _notifyOrgMembers(
          orgId: orgId,
          title: 'Document updated',
          body: doc.title,
          type: 'document',
        );
      }
      return doc;
    } catch (e, st) {
      developer.log(
        'Supabase addVersion failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Document> updateDocument({
    required String documentId,
    String? title,
    String? description,
    String? category,
    String? projectId,
    List<String>? tags,
    bool? isTemplate,
    bool? isPublished,
    Map<String, dynamic>? metadata,
  }) async {
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (category != null) payload['category'] = category;
    if (projectId != null) payload['project_id'] = projectId;
    if (tags != null) payload['tags'] = tags;
    if (isTemplate != null) payload['is_template'] = isTemplate;
    if (isPublished != null) payload['is_published'] = isPublished;
    if (metadata != null) payload['metadata'] = metadata;
    try {
      final res = await _client
          .from('documents')
          .update(payload)
          .eq('id', documentId)
          .select()
          .single();
      return _mapDocument(Map<String, dynamic>.from(res as Map));
    } catch (e, st) {
      developer.log(
        'Supabase updateDocument failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Document> addSignature({
    required Document document,
    required Uint8List bytes,
    String? signerName,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization to sign documents.');
    }
    final filename =
        'signature_${DateTime.now().millisecondsSinceEpoch}.png';
    final path = await _uploadFile(
      orgId: orgId,
      documentId: document.id,
      filename: filename,
      mimeType: 'image/png',
      bytes: bytes,
      folder: 'signatures',
    );
    final signatures = _extractSignatures(document);
    final signature = DocumentSignature(
      url: path,
      signedAt: DateTime.now(),
      signerName: signerName,
      signerId: _client.auth.currentUser?.id,
      storagePath: path,
      bucket: _bucketName,
    );
    signatures.add(signature);
    final updatedMetadata = {
      ...?document.metadata,
      'signatures': signatures.map((s) => s.toJson()).toList(),
    };
    return updateDocument(
      documentId: document.id,
      metadata: updatedMetadata,
    );
  }

  @override
  Future<void> deleteDocument({required Document document}) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization to delete documents.');
    }
    try {
      final path = resolveStoragePath(document.fileUrl, document.metadata);
      final bucket =
          resolveBucket(_bucketName, document.fileUrl, document.metadata);
      if (path != null && path.isNotEmpty) {
        await _client.storage.from(bucket).remove([path]);
      }
      await _client
          .from('documents')
          .delete()
          .eq('id', document.id)
          .eq('org_id', orgId);
    } catch (e, st) {
      developer.log(
        'Supabase deleteDocument failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<String> _uploadFile({
    required String orgId,
    required String documentId,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
    String? folder,
  }) async {
    final prefix = orgId.isNotEmpty ? 'org-$orgId' : 'public';
    final safeName = filename.replaceAll(' ', '_');
    final subfolder = folder ?? 'versions';
    final path =
        '$prefix/documents/$documentId/$subfolder/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _client.storage.from(_bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: mimeType,
          ),
        );
    return path;
  }

  List<DocumentSignature> _extractSignatures(Document document) {
    final raw = document.metadata?['signatures'];
    if (raw is List) {
      return raw
          .map((entry) =>
              DocumentSignature.fromJson(Map<String, dynamic>.from(entry as Map)))
          .toList();
    }
    return <DocumentSignature>[];
  }

  Future<Document> _signDocument(Document document) async {
    try {
      final signedUrl = await createSignedStorageUrl(
        client: _client,
        url: document.fileUrl,
        defaultBucket: _bucketName,
        metadata: document.metadata,
        expiresInSeconds: kSignedUrlExpirySeconds,
      );
      if (signedUrl == null || signedUrl.isEmpty) return document;
      return Document(
        id: document.id,
        title: document.title,
        description: document.description,
        category: document.category,
        projectId: document.projectId,
        fileUrl: signedUrl,
        localPath: document.localPath,
        filename: document.filename,
        mimeType: document.mimeType,
        fileSize: document.fileSize,
        version: document.version,
        uploadedBy: document.uploadedBy,
        uploadedAt: document.uploadedAt,
        updatedAt: document.updatedAt,
        isPublished: document.isPublished,
        isTemplate: document.isTemplate,
        tags: document.tags,
        companyId: document.companyId,
        metadata: document.metadata,
      );
    } catch (_) {
      return document;
    }
  }

  Future<DocumentVersion> _signVersion(DocumentVersion version) async {
    try {
      final signedUrl = await createSignedStorageUrl(
        client: _client,
        url: version.fileUrl,
        defaultBucket: _bucketName,
        metadata: version.metadata,
        expiresInSeconds: kSignedUrlExpirySeconds,
      );
      if (signedUrl == null || signedUrl.isEmpty) return version;
      return DocumentVersion(
        id: version.id,
        documentId: version.documentId,
        version: version.version,
        fileUrl: signedUrl,
        filename: version.filename,
        mimeType: version.mimeType,
        fileSize: version.fileSize,
        uploadedBy: version.uploadedBy,
        createdAt: version.createdAt,
        metadata: version.metadata,
      );
    } catch (_) {
      return version;
    }
  }

  Document _mapDocument(Map<String, dynamic> row) {
    final tags = row['tags'];
    return Document(
      id: row['id'].toString(),
      title: row['title'] as String? ?? 'Untitled document',
      description: row['description'] as String?,
      category: row['category'] as String?,
      projectId: row['project_id']?.toString(),
      fileUrl: row['file_url'] as String? ?? '',
      filename: row['filename'] as String? ?? '',
      mimeType: row['mime_type'] as String? ?? '',
      fileSize: _parseInt(row['file_size']) ?? 0,
      version: row['version'] as String? ?? 'v1',
      uploadedBy: row['uploaded_by']?.toString() ?? '',
      uploadedAt: _parseDate(row['created_at']),
      updatedAt: _parseNullableDate(row['updated_at']),
      isPublished: row['is_published'] as bool? ?? true,
      isTemplate: row['is_template'] as bool? ?? false,
      tags: tags is List ? tags.map((e) => e.toString()).toList() : null,
      companyId: row['org_id']?.toString(),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  DocumentVersion _mapVersion(Map<String, dynamic> row) {
    return DocumentVersion(
      id: row['id'].toString(),
      documentId: row['document_id']?.toString() ?? '',
      version: row['version'] as String? ?? '',
      fileUrl: row['file_url'] as String? ?? '',
      filename: row['filename'] as String? ?? '',
      mimeType: row['mime_type'] as String? ?? '',
      fileSize: _parseInt(row['file_size']) ?? 0,
      uploadedBy: row['uploaded_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.parse(value.toString());
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Future<void> _notifyOrgMembers({
    required String orgId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final members = await _client
          .from('org_members')
          .select('user_id')
          .eq('org_id', orgId);
      for (final member in members as List<dynamic>) {
        await _client.from('notifications').insert({
          'org_id': orgId,
          'user_id': member['user_id'],
          'title': title,
          'body': body,
          'type': type,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e, st) {
      developer.log(
        'Supabase notifyOrgMembers failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<String?> _getOrgId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final res = await _client
          .from('org_members')
          .select('org_id')
          .eq('user_id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    try {
      final res = await _client
          .from('profiles')
          .select('org_id')
          .eq('id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    developer.log('No org_id found for user $userId in org_members or profiles');
    return null;
  }
}
