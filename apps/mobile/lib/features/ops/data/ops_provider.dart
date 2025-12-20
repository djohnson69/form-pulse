import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../dashboard/data/dashboard_provider.dart';
import 'ops_repository.dart';

final opsRepositoryProvider = Provider<OpsRepositoryBase>((ref) {
  final client = ref.read(supabaseClientProvider);
  return SupabaseOpsRepository(client);
});

final newsPostsProvider = FutureProvider.autoDispose<List<NewsPost>>((ref) {
  return ref.read(opsRepositoryProvider).fetchNewsPosts();
});

final notificationRulesProvider =
    FutureProvider.autoDispose<List<NotificationRule>>((ref) {
  return ref.read(opsRepositoryProvider).fetchNotificationRules();
});

final notebookPagesProvider = FutureProvider.autoDispose
    .family<List<NotebookPage>, String?>((ref, projectId) {
  return ref.read(opsRepositoryProvider).fetchNotebookPages(projectId: projectId);
});

final notebookReportsProvider = FutureProvider.autoDispose
    .family<List<NotebookReport>, String?>((ref, projectId) {
  return ref.read(opsRepositoryProvider).fetchNotebookReports(projectId: projectId);
});

final signatureRequestsProvider = FutureProvider.autoDispose
    .family<List<SignatureRequest>, String?>((ref, documentId) {
  return ref
      .read(opsRepositoryProvider)
      .fetchSignatureRequests(documentId: documentId);
});

final projectPhotosProvider = FutureProvider.autoDispose
    .family<List<ProjectPhoto>, String?>((ref, projectId) {
  return ref
      .read(opsRepositoryProvider)
      .fetchProjectPhotos(projectId: projectId);
});

final photoCommentsProvider =
    FutureProvider.autoDispose.family<List<PhotoComment>, String>((
  ref,
  photoId,
) {
  return ref.read(opsRepositoryProvider).fetchPhotoComments(photoId);
});

final webhookEndpointsProvider =
    FutureProvider.autoDispose<List<WebhookEndpoint>>((ref) {
  return ref.read(opsRepositoryProvider).fetchWebhookEndpoints();
});

final exportJobsProvider = FutureProvider.autoDispose<List<ExportJob>>((ref) {
  return ref.read(opsRepositoryProvider).fetchExportJobs();
});

final aiJobsProvider = FutureProvider.autoDispose<List<AiJob>>((ref) {
  return ref.read(opsRepositoryProvider).fetchAiJobs();
});

final guestInvitesProvider = FutureProvider.autoDispose<List<GuestInvite>>((ref) {
  return ref.read(opsRepositoryProvider).fetchGuestInvites();
});

final paymentRequestsProvider =
    FutureProvider.autoDispose<List<PaymentRequest>>((ref) {
  return ref.read(opsRepositoryProvider).fetchPaymentRequests();
});

final reviewsProvider = FutureProvider.autoDispose<List<Review>>((ref) {
  return ref.read(opsRepositoryProvider).fetchReviews();
});

final portfolioItemsProvider =
    FutureProvider.autoDispose<List<PortfolioItem>>((ref) {
  return ref.read(opsRepositoryProvider).fetchPortfolioItems();
});
