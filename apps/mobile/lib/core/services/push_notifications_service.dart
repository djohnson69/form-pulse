import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../firebase_options.dart';

const String _kWebVapidKey =
    String.fromEnvironment('FIREBASE_WEB_VAPID_KEY', defaultValue: '');

class PushNotificationsService {
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      developer.log('Firebase init skipped: $e');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = kIsWeb
          ? await _getWebToken(messaging)
          : await messaging.getToken();
      if (token != null) {
        await _storeToken(token);
      }
      messaging.onTokenRefresh.listen(_storeToken);
    } catch (e) {
      developer.log('Push registration failed: $e');
    }
  }

  Future<void> _storeToken(String token) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    final orgId = await _resolveOrgId(client, user.id);
    final payload = {
      'org_id': orgId,
      'user_id': user.id,
      'token': token,
      'platform': _platformLabel(),
      'is_active': true,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      await client.from('device_tokens').upsert(payload, onConflict: 'token');
    } catch (e) {
      developer.log('Failed to store device token: $e');
    }
  }

  Future<String?> _resolveOrgId(SupabaseClient client, String userId) async {
    try {
      final res = await client
          .from('org_members')
          .select('org_id')
          .eq('user_id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    try {
      final res = await client
          .from('profiles')
          .select('org_id')
          .eq('id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    return null;
  }

  Future<String?> _getWebToken(FirebaseMessaging messaging) async {
    if (_kWebVapidKey.isEmpty) {
      developer.log('Web push requires FIREBASE_WEB_VAPID_KEY.');
      return null;
    }
    return messaging.getToken(vapidKey: _kWebVapidKey);
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
