import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../dashboard/data/dashboard_provider.dart';
import 'documents_repository.dart';

final documentsRepositoryProvider = Provider<DocumentsRepositoryBase>((ref) {
  final client = ref.read(supabaseClientProvider);
  return SupabaseDocumentsRepository(client);
});

final documentsProvider =
    FutureProvider.autoDispose.family<List<Document>, String?>((ref, projectId) async {
  final repo = ref.read(documentsRepositoryProvider);
  return repo.fetchDocuments(projectId: projectId);
});

final documentVersionsProvider =
    FutureProvider.autoDispose.family<List<DocumentVersion>, String>((
  ref,
  documentId,
) async {
  final repo = ref.read(documentsRepositoryProvider);
  return repo.fetchVersions(documentId);
});
