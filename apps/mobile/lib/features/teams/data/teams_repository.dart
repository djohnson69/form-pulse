import 'dart:developer' as developer;

import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamsRepository {
  TeamsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Team>> fetchTeams() async {
    try {
      final orgId = await _getOrgId();
      if (orgId == null) return const [];
      final rows = await _client
          .from('teams')
          .select()
          .eq('org_id', orgId)
          .order('name');
      return (rows as List<dynamic>)
          .map((row) => Team.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e, st) {
      developer.log('Supabase fetchTeams failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Team> createTeam({
    required String name,
    String? description,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization.');
    }
    final payload = {
      'org_id': orgId,
      'name': name,
      'description': description,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final res = await _client.from('teams').insert(payload).select().single();
    return Team.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Team> updateTeam({
    required String id,
    required String name,
    String? description,
  }) async {
    final payload = {
      'name': name,
      'description': description,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final res =
        await _client.from('teams').update(payload).eq('id', id).select().single();
    return Team.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<String>> fetchTeamMembers(String teamId) async {
    try {
      final rows = await _client
          .from('team_members')
          .select('user_id')
          .eq('team_id', teamId);
      return (rows as List<dynamic>)
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .toList();
    } catch (e, st) {
      developer.log('Supabase fetchTeamMembers failed', error: e, stackTrace: st);
      return const [];
    }
  }

  Future<void> updateTeamMembers(String teamId, List<String> userIds) async {
    try {
      await _client.from('team_members').delete().eq('team_id', teamId);
      if (userIds.isEmpty) return;
      final payload = userIds
          .map(
            (id) => {
              'team_id': teamId,
              'user_id': id,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            },
          )
          .toList();
      await _client.from('team_members').insert(payload);
    } catch (e, st) {
      developer.log('Supabase updateTeamMembers failed', error: e, stackTrace: st);
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
      developer.log('TeamsRepository org_members lookup failed',
          error: e, stackTrace: st, name: 'TeamsRepository._getOrgId');
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
      developer.log('TeamsRepository profiles lookup failed',
          error: e, stackTrace: st, name: 'TeamsRepository._getOrgId');
    }
    return null;
  }
}
