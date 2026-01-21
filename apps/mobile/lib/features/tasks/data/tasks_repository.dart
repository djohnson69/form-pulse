import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskAssignee {
  final String id;
  final String name;
  final String? email;
  final String? role;
  final bool isActive;
  final DateTime? createdAt;

  TaskAssignee({
    required this.id,
    required this.name,
    this.email,
    this.role,
    this.isActive = true,
    this.createdAt,
  });
}

abstract class TasksRepositoryBase {
  Future<List<Task>> fetchTasks({UserRole? role});
  Future<List<TaskAssignee>> fetchAssignees();
  Future<Task> createTask({
    required String title,
    String? description,
    String? instructions,
    DateTime? dueDate,
    String? priority,
    String? assignedTo,
    String? assignedToName,
    String? assignedTeam,
    Map<String, dynamic>? metadata,
  });
  Future<Task> updateTask({
    required String taskId,
    String? title,
    TaskStatus? status,
    int? progress,
    DateTime? dueDate,
    String? priority,
    String? description,
    String? instructions,
    String? assignedTo,
    String? assignedToName,
    String? assignedTeam,
    Map<String, dynamic>? metadata,
  });
  Future<void> sendReminder(Task task, {String? message});
}

class SupabaseTasksRepository implements TasksRepositoryBase {
  SupabaseTasksRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Task>> fetchTasks({UserRole? role}) async {
    // Only developer and tech support can see across orgs; all other roles
    // are scoped to their organization.
    final isGlobalView = role?.canViewAcrossOrgs ?? false;
    final orgId = await _getOrgId();
    if (!isGlobalView && orgId == null) return const [];
    try {
      dynamic query = _client.from('tasks').select();
      if (!isGlobalView && orgId != null) {
        query = query.eq('org_id', orgId);
      }
      query = query
          .order('due_date', ascending: true)
          .order('updated_at', ascending: false);
      final res = await query;
      return (res as List<dynamic>)
          .map((row) => _mapTask(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e, st) {
      developer.log(
        'Supabase fetchTasks failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<TaskAssignee>> fetchAssignees() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    try {
      final res = await _client
          .from('profiles')
          .select()
          .eq('org_id', orgId)
          .order('last_name', ascending: true);
      return (res as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .where((data) => data['is_active'] != false)
          .map((data) {
            final first = (data['first_name'] as String?)?.trim() ?? '';
            final last = (data['last_name'] as String?)?.trim() ?? '';
            final email = data['email'] as String?;
            final name = [first, last].where((p) => p.isNotEmpty).join(' ');
            return TaskAssignee(
              id: data['id'].toString(),
              name: name.isNotEmpty ? name : (email ?? 'User'),
              email: email,
              role: data['role'] as String?,
              isActive: data['is_active'] as bool? ?? true,
              createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
            );
          })
          .toList();
    } catch (e, st) {
      developer.log(
        'Supabase fetchAssignees failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Task> createTask({
    required String title,
    String? description,
    String? instructions,
    DateTime? dueDate,
    String? priority,
    String? assignedTo,
    String? assignedToName,
    String? assignedTeam,
    Map<String, dynamic>? metadata,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization to create tasks.');
    }
    final payload = {
      'org_id': orgId,
      'title': title,
      'description': description,
      'instructions': instructions,
      'status': TaskStatus.todo.name,
      'progress': 0,
      'due_date': dueDate?.toIso8601String(),
      'priority': priority ?? 'normal',
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
      'assigned_team': assignedTeam,
      'created_by': _client.auth.currentUser?.id,
      'updated_at': DateTime.now().toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
    try {
      final res = await _client.from('tasks').insert(payload).select().single();
      final task = _mapTask(Map<String, dynamic>.from(res as Map));
      if (assignedTo != null) {
        await _createNotification(
          orgId: orgId,
          userId: assignedTo,
          title: 'New task assigned',
          body: 'Task: ${task.title}',
          type: 'task',
        );
      }
      if (assignedTeam != null && assignedTeam.trim().isNotEmpty) {
        final members = await _resolveTeamMembers(
          orgId: orgId,
          teamName: assignedTeam,
        );
        for (final userId in members) {
          if (userId == assignedTo) continue;
          await _createNotification(
            orgId: orgId,
            userId: userId,
            title: 'Team task assigned',
            body: 'Task: ${task.title}',
            type: 'task',
          );
        }
      }
      final approval = metadata?['approval'] as Map?;
      if (approval?['required'] == true) {
        final approverRole = approval?['approverRole']?.toString();
        final approvers = await _fetchApprovers(orgId, approverRole);
        for (final userId in approvers) {
          await _createNotification(
            orgId: orgId,
            userId: userId,
            title: 'Task approval requested',
            body: 'Task: ${task.title}',
            type: 'task_approval',
          );
        }
      }
      return task;
    } catch (e, st) {
      developer.log(
        'Supabase createTask failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Task> updateTask({
    required String taskId,
    String? title,
    TaskStatus? status,
    int? progress,
    DateTime? dueDate,
    String? priority,
    String? description,
    String? instructions,
    String? assignedTo,
    String? assignedToName,
    String? assignedTeam,
    Map<String, dynamic>? metadata,
  }) async {
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) payload['title'] = title;
    if (status != null) payload['status'] = status.name;
    if (progress != null) {
      payload['progress'] = progress.clamp(0, 100);
    }
    if (dueDate != null) payload['due_date'] = dueDate.toIso8601String();
    if (priority != null) payload['priority'] = priority;
    if (description != null) payload['description'] = description;
    if (instructions != null) payload['instructions'] = instructions;
    if (assignedTo != null) payload['assigned_to'] = assignedTo;
    if (assignedToName != null) payload['assigned_to_name'] = assignedToName;
    if (assignedTeam != null) payload['assigned_team'] = assignedTeam;
    if (metadata != null) payload['metadata'] = metadata;

    final completing = status == TaskStatus.completed;
    if (completing) {
      payload['completed_at'] = DateTime.now().toIso8601String();
      payload['progress'] = 100;
    }

    try {
      final res = await _client
          .from('tasks')
          .update(payload)
          .eq('id', taskId)
          .select()
          .single();
      final task = _mapTask(Map<String, dynamic>.from(res as Map));
      if (completing) {
        await _notifySupervisors(task);
      }
      if (assignedTeam != null && assignedTeam.trim().isNotEmpty) {
        final effectiveOrgId = task.orgId ?? await _getOrgId();
        if (effectiveOrgId == null) return task;
        final members = await _resolveTeamMembers(
          orgId: effectiveOrgId,
          teamName: assignedTeam,
        );
        for (final userId in members) {
          if (userId == assignedTo) continue;
          await _createNotification(
            orgId: effectiveOrgId,
            userId: userId,
            title: 'Team task updated',
            body: 'Task: ${task.title}',
            type: 'task',
          );
        }
      }
      return task;
    } catch (e, st) {
      developer.log(
        'Supabase updateTask failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> sendReminder(Task task, {String? message}) async {
    final orgId = task.orgId ?? await _getOrgId();
    if (orgId == null || task.assignedTo == null) return;
    final dueText =
        task.dueDate != null ? 'Due ${task.dueDate!.toLocal()}' : 'No due date';
    await _createNotification(
      orgId: orgId,
      userId: task.assignedTo!,
      title: 'Task reminder',
      body: message ?? '${task.title} • $dueText',
      type: 'task',
    );
  }

  Future<void> _notifySupervisors(Task task) async {
    final orgId = task.orgId ?? await _getOrgId();
    if (orgId == null) return;
    final supervisors = await _fetchSupervisors(orgId);
    if (supervisors.isEmpty) return;
    for (final userId in supervisors) {
      await _createNotification(
        orgId: orgId,
        userId: userId,
        title: 'Task completed',
        body: 'Task: ${task.title}',
        type: 'task',
      );
    }
  }

  Future<List<String>> _fetchSupervisors(String orgId) async {
    const roles = ['owner', 'admin', 'manager', 'supervisor'];
    try {
      final res = await _client
          .from('org_members')
          .select('user_id, role')
          .eq('org_id', orgId)
          .inFilter('role', roles);
      return (res as List<dynamic>)
          .map((row) => row['user_id'].toString())
          .toSet()
          .toList();
    } catch (e, st) {
      developer.log(
        'Supabase fetchSupervisors failed',
        error: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  Future<List<String>> _fetchApprovers(
    String orgId,
    String? requiredRole,
  ) async {
    if (requiredRole == null || requiredRole.trim().isEmpty) {
      return _fetchSupervisors(orgId);
    }
    try {
      final res = await _client
          .from('org_members')
          .select('user_id, role')
          .eq('org_id', orgId)
          .eq('role', requiredRole);
      return (res as List<dynamic>)
          .map((row) => row['user_id'].toString())
          .toSet()
          .toList();
    } catch (e, st) {
      developer.log(
        'Supabase fetchApprovers failed',
        error: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  Future<void> _createNotification({
    required String orgId,
    required String userId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      await _client.from('notifications').insert({
        'org_id': orgId,
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _client.functions.invoke(
        'push',
        body: {
          'orgId': orgId,
          'userId': userId,
          'title': title,
          'body': body,
          'data': {'type': type},
        },
      );
    } catch (e, st) {
      developer.log(
        'Supabase createNotification failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<List<String>> _resolveTeamMembers({
    required String? orgId,
    required String teamName,
  }) async {
    if (orgId == null || orgId.isEmpty) return const [];
    try {
      final teamRow = await _client
          .from('teams')
          .select('id')
          .eq('org_id', orgId)
          .eq('name', teamName)
          .maybeSingle();
      final teamId = teamRow?['id']?.toString();
      if (teamId == null) return const [];
      final members = await _client
          .from('team_members')
          .select('user_id')
          .eq('team_id', teamId);
      return (members as List<dynamic>)
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .toList();
    } catch (e, st) {
      developer.log(
        'Supabase resolveTeamMembers failed',
        error: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  Task _mapTask(Map<String, dynamic> row) {
    final rawMetadata = row['metadata'];
    final metadata = rawMetadata is String
        ? jsonDecode(rawMetadata)
        : rawMetadata as Map<String, dynamic>?;
    final status = _parseStatus(row['status']);
    return Task(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString(),
      title: row['title'] as String? ?? 'Untitled task',
      description: row['description'] as String?,
      instructions: row['instructions'] as String?,
      status: status,
      progress: _parseInt(row['progress']) ?? 0,
      dueDate: _parseNullableDate(row['due_date']),
      priority: row['priority'] as String?,
      assignedTo: row['assigned_to']?.toString(),
      assignedToName: row['assigned_to_name'] as String?,
      assignedTeam: row['assigned_team'] as String?,
      createdBy: row['created_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseNullableDate(row['updated_at']),
      completedAt: _parseNullableDate(row['completed_at']),
      metadata: metadata,
    );
  }

  TaskStatus _parseStatus(dynamic raw) {
    final value = raw?.toString().toLowerCase().trim() ?? '';
    switch (value) {
      case 'completed':
      case 'complete':
      case 'done':
      case 'resolved':
      case 'closed':
        return TaskStatus.completed;
      case 'in-progress':
      case 'in_progress':
      case 'progress':
      case 'active':
      case 'working':
      case 'ongoing':
        return TaskStatus.inProgress;
      case 'blocked':
      case 'on_hold':
      case 'on-hold':
      case 'paused':
      case 'waiting':
        return TaskStatus.blocked;
      case 'todo':
      case 'to-do':
      case 'pending':
      case 'open':
      default:
        return TaskStatus.todo;
    }
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
