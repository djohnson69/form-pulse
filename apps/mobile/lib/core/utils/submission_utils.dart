import 'package:shared/shared.dart';

const Map<String, String> submissionInputTypeLabels = {
  'text': 'Text',
  'photo': 'Photo',
  'video': 'Video',
  'audio': 'Audio',
  'signature': 'Signature',
  'document': 'Document',
  'geo': 'Geo',
};

const Map<String, String> submissionAccessLevelLabels = {
  'org': 'Internal',
  'team': 'Team',
  'client': 'Client',
  'vendor': 'Vendor',
};

String resolveSubmissionProvider(FormSubmission submission) {
  final value =
      submission.metadata?['provider'] ?? submission.metadata?['authProvider'];
  final provider = value?.toString().trim() ?? '';
  return provider;
}

List<String> resolveSubmissionInputTypes(FormSubmission submission) {
  final metaTypes = submission.metadata?['inputTypes'];
  if (metaTypes is List) {
    final normalized = metaTypes
        .map((item) => item.toString().trim())
        .map((item) => item == 'file' ? 'document' : item)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  final types = <String>{};
  final hasText = submission.data.values.any((value) {
    if (value == null) return false;
    final text = value.toString().trim();
    return text.isNotEmpty && text != 'null';
  });
  if (hasText) {
    types.add('text');
  }
  for (final attachment in submission.attachments ?? const []) {
    switch (attachment.type) {
      case 'photo':
        types.add('photo');
        break;
      case 'video':
        types.add('video');
        break;
      case 'audio':
        types.add('audio');
        break;
      case 'signature':
        types.add('signature');
        break;
      case 'file':
        types.add('document');
        break;
      default:
        types.add(attachment.type);
        break;
    }
  }
  if (submission.location != null) {
    types.add('geo');
  }
  if (types.isEmpty) {
    types.add('text');
  }
  return types.toList();
}

String resolveSubmissionAccessLevel(FormSubmission submission) {
  final raw =
      submission.metadata?['visibility'] ?? submission.metadata?['accessLevel'];
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) {
    return 'org';
  }
  return value;
}

String submissionInputTypeLabel(String type) =>
    submissionInputTypeLabels[type] ?? type;

String submissionAccessLevelLabel(String type) =>
    submissionAccessLevelLabels[type] ?? type;
