import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    this.orgId,
    this.email,
    this.isActive = true,
  });

  final String id;
  final String? orgId;
  final String? email;
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
        .select('id, org_id, email, is_active')
        .eq('id', user.id)
        .maybeSingle();
    if (res != null) {
      return UserProfile(
        id: res['id'] as String,
        orgId: res['org_id'] as String?,
        email: res['email'] as String?,
        isActive: res['is_active'] as bool? ?? true,
      );
    }
  } on PostgrestException catch (e) {
    if (e.message.contains('is_active') || e.code == '42703') {
      try {
        final res = await client
            .from('profiles')
            .select('id, org_id, email')
            .eq('id', user.id)
            .maybeSingle();
        if (res != null) {
          return UserProfile(
            id: res['id'] as String,
            orgId: res['org_id'] as String?,
            email: res['email'] as String?,
            isActive: true,
          );
        }
      } catch (_) {}
    }
  } catch (_) {}

  return UserProfile(id: user.id, orgId: null, email: user.email);
});
