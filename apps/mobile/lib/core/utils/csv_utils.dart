import 'dart:convert';

import 'package:shared/shared.dart';

String buildSubmissionsCsv(List<FormSubmission> submissions) {
  final fieldKeys = <String>{};
  for (final submission in submissions) {
    fieldKeys.addAll(submission.data.keys.map((k) => k.toString()));
  }
  final sortedKeys = fieldKeys.toList()..sort();
  final rows = <List<String>>[];
  rows.add([
    'id',
    'form_title',
    'submitted_by',
    'submitted_by_name',
    'submitted_at',
    'status',
    'location_lat',
    'location_lng',
    'location_accuracy',
    'attachments',
    ...sortedKeys,
  ]);

  for (final submission in submissions) {
    final attachments = submission.attachments ?? const <MediaAttachment>[];
    final attachmentNames = attachments
        .map((a) => a.filename ?? a.url)
        .where((v) => v.isNotEmpty)
        .join('; ');
    final location = submission.location;
    final row = <String>[
      submission.id,
      submission.formTitle,
      submission.submittedBy,
      submission.submittedByName ?? '',
      submission.submittedAt.toIso8601String(),
      submission.status.name,
      location?.latitude.toString() ?? '',
      location?.longitude.toString() ?? '',
      location?.accuracy?.toString() ?? '',
      attachmentNames,
    ];
    for (final key in sortedKeys) {
      final value = submission.data[key];
      row.add(_formatValue(value));
    }
    rows.add(row);
  }

  return _toCsv(rows);
}

String buildSubmissionCsv(FormSubmission submission) {
  return buildSubmissionsCsv([submission]);
}

String _toCsv(List<List<String>> rows) {
  final buffer = StringBuffer();
  for (final row in rows) {
    final escaped = row.map(_escapeCsv).join(',');
    buffer.writeln(escaped);
  }
  return buffer.toString();
}

String _escapeCsv(String value) {
  final needsQuotes = value.contains(',') ||
      value.contains('\n') ||
      value.contains('\r') ||
      value.contains('"');
  if (!needsQuotes) return value;
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _formatValue(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return jsonEncode(value);
}
