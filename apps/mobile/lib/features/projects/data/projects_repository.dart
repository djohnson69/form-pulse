import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/storage_utils.dart';

abstract class ProjectsRepositoryBase {
  Future<List<Project>> fetchProjects();
  Future<Project> createProject({
    required String name,
    String? description,
    List<String>? labels,
    String? status,
  });
  Future<Project> ensureShareToken(Project project);
  Future<List<ProjectUpdate>> fetchUpdates(String projectId);
  Future<ProjectUpdate> addUpdate({
    required String projectId,
    required String type,
    String? title,
    String? body,
    List<String>? tags,
    List<MediaAttachment>? attachments,
    String? parentId,
    bool isShared,
  });
  Future<void> toggleUpdateShared(String updateId, bool isShared);
}

class SupabaseProjectsRepository implements ProjectsRepositoryBase {
  SupabaseProjectsRepository(this._client);

  final SupabaseClient _client;
  static final _uuid = Uuid();
  static const _bucketName =
      String.fromEnvironment('SUPABASE_BUCKET', defaultValue: 'formbridge-attachments');

  @override
  Future<List<Project>> fetchProjects() async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      return const [];
    }
    try {
      final res = await _client
          .from('projects')
          .select()
          .eq('org_id', orgId)
          .order('updated_at', ascending: false);
      return (res as List<dynamic>)
          .map((row) => _mapProject(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e, st) {
      developer.log(
        'Supabase fetchProjects failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Project> createProject({
    required String name,
    String? description,
    List<String>? labels,
    String? status,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization to create projects.');
    }
    final payload = {
      'org_id': orgId,
      'name': name,
      'description': description,
      'status': status ?? 'active',
      'labels': labels ?? const <String>[],
      'share_token': _uuid.v4(),
      'created_by': _client.auth.currentUser?.id,
    };
    try {
      final res = await _client.from('projects').insert(payload).select().single();
      return _mapProject(Map<String, dynamic>.from(res as Map));
    } catch (e, st) {
      developer.log(
        'Supabase createProject failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Project> ensureShareToken(Project project) async {
    if (project.shareToken != null && project.shareToken!.isNotEmpty) {
      return project;
    }
    final token = _uuid.v4();
    try {
      final res = await _client
          .from('projects')
          .update({'share_token': token, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', project.id)
          .select()
          .single();
      return _mapProject(Map<String, dynamic>.from(res as Map));
    } catch (e, st) {
      developer.log(
        'Supabase ensureShareToken failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<ProjectUpdate>> fetchUpdates(String projectId) async {
    try {
      final res = await _client
          .from('project_updates')
          .select()
          .eq('project_id', projectId)
          .order('created_at', ascending: false);
      final updates = (res as List<dynamic>)
          .map((row) => _mapUpdate(Map<String, dynamic>.from(row as Map)))
          .toList();
      return Future.wait(updates.map(_withSignedAttachments));
    } catch (e, st) {
      developer.log(
        'Supabase fetchUpdates failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<ProjectUpdate> addUpdate({
    required String projectId,
    required String type,
    String? title,
    String? body,
    List<String>? tags,
    List<MediaAttachment>? attachments,
    String? parentId,
    bool isShared = false,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization to add updates.');
    }
    final payload = {
      'org_id': orgId,
      'project_id': projectId,
      'user_id': _client.auth.currentUser?.id,
      'type': type,
      'title': title,
      'body': body,
      'tags': tags ?? const <String>[],
      'attachments': attachments?.map((a) => a.toJson()).toList() ?? const [],
      'parent_id': parentId,
      'is_shared': isShared,
    };
    try {
      final res = await _client
          .from('project_updates')
          .insert(payload)
          .select()
          .single();
      await _client
          .from('projects')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', projectId);
      return _mapUpdate(Map<String, dynamic>.from(res as Map));
    } catch (e, st) {
      developer.log(
        'Supabase addUpdate failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> toggleUpdateShared(String updateId, bool isShared) async {
    try {
      final res = await _client
          .from('project_updates')
          .update({'is_shared': isShared})
          .eq('id', updateId)
          .select('project_id')
          .maybeSingle();
      final projectId = res?['project_id'];
      if (projectId != null) {
        await _client
            .from('projects')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', projectId);
      }
    } catch (e, st) {
      developer.log(
        'Supabase toggleUpdateShared failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
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
    } catch (e, st) {
      developer.log('org_members lookup failed, trying profiles', error: e, stackTrace: st);
    }
    try {
      final res = await _client
          .from('profiles')
          .select('org_id')
          .eq('id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (e, st) {
      developer.log('profiles lookup also failed for user $userId', error: e, stackTrace: st);
    }
    developer.log('No org_id found for user $userId in org_members or profiles');
    return null;
  }

  Project _mapProject(Map<String, dynamic> row) {
    final labels = row['labels'];
    return Project(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString(),
      name: row['name'] as String? ?? 'Untitled project',
      description: row['description'] as String?,
      status: row['status'] as String? ?? 'active',
      labels: labels is List ? labels.map((e) => e.toString()).toList() : const [],
      coverUrl: row['cover_url'] as String?,
      shareToken: row['share_token'] as String?,
      createdBy: row['created_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseNullableDate(row['updated_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  ProjectUpdate _mapUpdate(Map<String, dynamic> row) {
    final rawTags = row['tags'];
    final rawAttachments = row['attachments'];
    final parsedTags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : const <String>[];
    final parsedAttachments = rawAttachments is String
        ? jsonDecode(rawAttachments)
        : rawAttachments ?? <dynamic>[];
    return ProjectUpdate(
      id: row['id'].toString(),
      projectId: row['project_id']?.toString() ?? '',
      orgId: row['org_id']?.toString(),
      userId: row['user_id']?.toString(),
      type: row['type'] as String? ?? 'note',
      title: row['title'] as String?,
      body: row['body'] as String?,
      tags: parsedTags,
      attachments: (parsedAttachments as List)
          .map(
            (a) => MediaAttachment.fromJson(
              Map<String, dynamic>.from(a as Map),
            ),
          )
          .toList(),
      parentId: row['parent_id']?.toString(),
      isShared: row['is_shared'] as bool? ?? false,
      createdAt: _parseDate(row['created_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  Future<ProjectUpdate> _withSignedAttachments(ProjectUpdate update) async {
    if (update.attachments.isEmpty) return update;
    final signed = await Future.wait(update.attachments.map(_signAttachment));
    return ProjectUpdate(
      id: update.id,
      projectId: update.projectId,
      orgId: update.orgId,
      userId: update.userId,
      type: update.type,
      title: update.title,
      body: update.body,
      tags: update.tags,
      attachments: signed,
      parentId: update.parentId,
      isShared: update.isShared,
      createdAt: update.createdAt,
      metadata: update.metadata,
    );
  }

  Future<MediaAttachment> _signAttachment(MediaAttachment attachment) async {
    try {
      final signedUrl = await createSignedStorageUrl(
        client: _client,
        url: attachment.url,
        defaultBucket: _bucketName,
        metadata: attachment.metadata,
        expiresInSeconds: kSignedUrlExpirySeconds,
      );
      if (signedUrl == null || signedUrl.isEmpty) return attachment;
      return MediaAttachment(
        id: attachment.id,
        type: attachment.type,
        url: signedUrl,
        localPath: attachment.localPath,
        filename: attachment.filename,
        fileSize: attachment.fileSize,
        mimeType: attachment.mimeType,
        capturedAt: attachment.capturedAt,
        location: attachment.location,
        metadata: attachment.metadata,
      );
    } catch (e, st) {
      developer.log('ProjectsRepository sign attachment failed',
          error: e, stackTrace: st, name: 'ProjectsRepository._signAttachment');
      return attachment;
    }
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
}
