import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sop_repository.dart';

final sopRepositoryProvider = Provider<SopRepositoryBase>((ref) {
  return SupabaseSopRepository(Supabase.instance.client);
});

final sopDocumentsProvider = FutureProvider<List<SopDocument>>((ref) async {
  return ref.read(sopRepositoryProvider).fetchDocuments();
});

final sopVersionsProvider =
    FutureProvider.family<List<SopVersion>, String>((ref, sopId) async {
  return ref.read(sopRepositoryProvider).fetchVersions(sopId);
});

final sopApprovalsProvider =
    FutureProvider.family<List<SopApproval>, String>((ref, sopId) async {
  return ref.read(sopRepositoryProvider).fetchApprovals(sopId);
});

final sopAcknowledgementsProvider =
    FutureProvider.family<List<SopAcknowledgement>, String>((ref, sopId) async {
  return ref.read(sopRepositoryProvider).fetchAcknowledgements(sopId);
});
