import 'package:supabase_flutter/supabase_flutter.dart';

const int kSignedUrlExpirySeconds = 3600;

class StoragePathInfo {
  StoragePathInfo({required this.bucket, required this.path});

  final String bucket;
  final String path;
}

StoragePathInfo? _extractStorageInfo(String url) {
  if (!url.startsWith('http')) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final segments = uri.pathSegments;
  final objectIndex = segments.indexOf('object');
  if (objectIndex == -1 || segments.length <= objectIndex + 3) return null;
  final bucket = segments[objectIndex + 2];
  final path = segments.sublist(objectIndex + 3).join('/');
  return StoragePathInfo(bucket: bucket, path: path);
}

String? resolveStoragePath(String url, Map<String, dynamic>? metadata) {
  final fromMetadata =
      metadata?['storagePath']?.toString() ?? metadata?['path']?.toString();
  if (fromMetadata != null && fromMetadata.isNotEmpty) return fromMetadata;
  if (url.isEmpty || url.startsWith('data:')) return null;
  if (!url.startsWith('http')) return url;
  return _extractStorageInfo(url)?.path;
}

String resolveBucket(
  String defaultBucket,
  String url,
  Map<String, dynamic>? metadata,
) {
  final fromMetadata = metadata?['bucket']?.toString();
  if (fromMetadata != null && fromMetadata.isNotEmpty) return fromMetadata;
  final parsed = _extractStorageInfo(url);
  if (parsed != null && parsed.bucket.isNotEmpty) return parsed.bucket;
  return defaultBucket;
}

Future<String?> createSignedStorageUrl({
  required SupabaseClient client,
  required String url,
  required String defaultBucket,
  Map<String, dynamic>? metadata,
  int expiresInSeconds = kSignedUrlExpirySeconds,
}) async {
  final path = resolveStoragePath(url, metadata);
  if (path == null || path.isEmpty) return null;
  final bucket = resolveBucket(defaultBucket, url, metadata);
  final signed =
      await client.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
  if (!signed.startsWith('https://')) return null;
  return signed;
}
