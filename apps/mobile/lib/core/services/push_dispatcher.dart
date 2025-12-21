import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

class PushDispatcher {
  PushDispatcher(this._client);

  final SupabaseClient _client;

  Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? orgId,
  }) async {
    try {
      await _client.functions.invoke(
        'push',
        body: {
          if (orgId != null) 'orgId': orgId,
          'userId': userId,
          'title': title,
          'body': body,
          'data': data ?? const {},
        },
      );
    } catch (e, st) {
      developer.log('Push dispatch failed', error: e, stackTrace: st);
    }
  }

  Future<void> sendToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? orgId,
  }) async {
    final unique = userIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (unique.isEmpty) return;
    await Future.wait(
      unique.map(
        (userId) => sendToUser(
          userId: userId,
          title: title,
          body: body,
          data: data,
          orgId: orgId,
        ),
      ),
    );
  }

  Future<void> sendToOrg({
    required String orgId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.functions.invoke(
        'push',
        body: {
          'orgId': orgId,
          'title': title,
          'body': body,
          'data': data ?? const {},
        },
      );
    } catch (e, st) {
      developer.log('Push dispatch failed', error: e, stackTrace: st);
    }
  }
}
