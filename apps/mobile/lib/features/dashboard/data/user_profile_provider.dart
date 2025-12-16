import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  const UserProfile({required this.id, this.orgId, this.email});

  final String id;
  final String? orgId;
  final String? email;
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
        .select('id, org_id, email')
        .eq('id', user.id)
        .maybeSingle();
    if (res != null) {
      return UserProfile(
        id: res['id'] as String,
        orgId: res['org_id'] as String?,
        email: res['email'] as String?,
      );
    }
  } catch (_) {}

  return UserProfile(id: user.id, orgId: null, email: user.email);
});
