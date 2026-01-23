import 'dart:developer' as developer;

import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class TemplatesRepositoryBase {
  Future<List<AppTemplate>> fetchTemplates({String? type});
  Future<AppTemplate> createTemplate({
    required String type,
    required String name,
    String? description,
    Map<String, dynamic> payload,
    List<String> assignedUserIds,
    List<String> assignedRoles,
    bool isActive,
  });
  Future<AppTemplate> updateTemplate({
    required AppTemplate template,
    String? name,
    String? description,
    Map<String, dynamic>? payload,
    List<String>? assignedUserIds,
    List<String>? assignedRoles,
    bool? isActive,
  });
}

class SupabaseTemplatesRepository implements TemplatesRepositoryBase {
  SupabaseTemplatesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AppTemplate>> fetchTemplates({String? type}) async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    var query = _client.from('app_templates').select().eq('org_id', orgId);
    if (type != null && type.isNotEmpty) {
      query = query.eq('type', type);
    }
    final rows = await query.order('updated_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => AppTemplate.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<AppTemplate> createTemplate({
    required String type,
    required String name,
    String? description,
    Map<String, dynamic> payload = const {},
    List<String> assignedUserIds = const [],
    List<String> assignedRoles = const [],
    bool isActive = true,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization.');
    }
    final res = await _client.from('app_templates').insert({
      'org_id': orgId,
      'type': type,
      'name': name,
      'description': description,
      'payload': payload,
      'assigned_user_ids': assignedUserIds,
      'assigned_roles': assignedRoles,
      'is_active': isActive,
      'created_by': _client.auth.currentUser?.id,
      'updated_at': DateTime.now().toIso8601String(),
    }).select().single();
    return AppTemplate.fromJson(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<AppTemplate> updateTemplate({
    required AppTemplate template,
    String? name,
    String? description,
    Map<String, dynamic>? payload,
    List<String>? assignedUserIds,
    List<String>? assignedRoles,
    bool? isActive,
  }) async {
    final update = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) update['name'] = name;
    if (description != null) update['description'] = description;
    if (payload != null) update['payload'] = payload;
    if (assignedUserIds != null) update['assigned_user_ids'] = assignedUserIds;
    if (assignedRoles != null) update['assigned_roles'] = assignedRoles;
    if (isActive != null) update['is_active'] = isActive;
    try {
      final res = await _client
          .from('app_templates')
          .update(update)
          .eq('id', template.id)
          .select()
          .single();
      return AppTemplate.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e, st) {
      developer.log('Supabase updateTemplate failed', error: e, stackTrace: st);
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
    return null;
  }
}
