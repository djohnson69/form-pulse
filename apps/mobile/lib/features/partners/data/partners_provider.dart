import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../dashboard/data/dashboard_provider.dart';
import 'partners_repository.dart';

final partnersRepositoryProvider = Provider<PartnersRepositoryBase>((ref) {
  final client = ref.read(supabaseClientProvider);
  return SupabasePartnersRepository(client);
});

final clientsProvider = FutureProvider.autoDispose<List<Client>>((ref) async {
  final repo = ref.read(partnersRepositoryProvider);
  return repo.fetchClients();
});

final vendorsProvider = FutureProvider.autoDispose<List<Vendor>>((ref) async {
  final repo = ref.read(partnersRepositoryProvider);
  return repo.fetchVendors();
});

final messageThreadsProvider =
    FutureProvider.autoDispose<List<MessageThreadPreview>>((ref) async {
  final repo = ref.read(partnersRepositoryProvider);
  return repo.fetchThreadPreviews();
});

final threadMessagesProvider =
    FutureProvider.autoDispose.family<List<Message>, String>((ref, threadId) async {
  final repo = ref.read(partnersRepositoryProvider);
  return repo.fetchMessages(threadId);
});
