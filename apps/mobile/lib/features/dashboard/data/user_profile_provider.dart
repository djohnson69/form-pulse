import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/error_logger.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    this.orgId,
    this.email,
    this.firstName,
    this.lastName,
    this.isActive = true,
  });

  final String id;
  final String? orgId;
  final String? email;
  final String? firstName;
  final String? lastName;
  final bool isActive;
}

final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) {
    throw Exception('Not authenticated');
  }
  // Attempt to fetch profile; fall back to auth metadata.
  try {
    final res = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (res != null) {
      return UserProfile(
        id: res['id'] as String? ?? user.id,
        orgId: res['org_id'] as String?,
        email: res['email'] as String?,
        firstName: res['first_name']?.toString(),
        lastName: res['last_name']?.toString(),
        isActive: res['is_active'] as bool? ?? true,
      );
    }
  } catch (e, st) {
    ErrorLogger.warn(
      'Failed to fetch profile from database, using auth fallback',
      context: 'userProfileProvider',
      error: e,
      stackTrace: st,
    );
  }

  return UserProfile(id: user.id, orgId: null, email: user.email);
});
