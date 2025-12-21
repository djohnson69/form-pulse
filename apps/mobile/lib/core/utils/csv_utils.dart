import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:shared/shared.dart';

import 'submission_utils.dart';

String buildSubmissionsCsv(List<FormSubmission> submissions) {
  return _toCsv(_buildSubmissionRows(submissions));
}

String buildSubmissionCsv(FormSubmission submission) {
  return buildSubmissionsCsv([submission]);
}

Uint8List buildSubmissionsXlsx(List<FormSubmission> submissions) {
  return _toXlsx(_buildSubmissionRows(submissions), sheetName: 'Submissions');
}

String buildTasksCsv(List<Task> tasks) {
  return _toCsv(_buildTaskRows(tasks));
}

Uint8List buildTasksXlsx(List<Task> tasks) {
  return _toXlsx(_buildTaskRows(tasks), sheetName: 'Tasks');
}

String buildAssetsCsv(List<Equipment> assets) {
  return _toCsv(_buildAssetRows(assets));
}

Uint8List buildAssetsXlsx(List<Equipment> assets) {
  return _toXlsx(_buildAssetRows(assets), sheetName: 'Assets');
}

String buildIncidentsCsv(List<IncidentReport> incidents) {
  return _toCsv(_buildIncidentRows(incidents));
}

Uint8List buildIncidentsXlsx(List<IncidentReport> incidents) {
  return _toXlsx(_buildIncidentRows(incidents), sheetName: 'Incidents');
}

String _toCsv(List<List<String>> rows) {
  final buffer = StringBuffer();
  for (final row in rows) {
    final escaped = row.map(_escapeCsv).join(',');
    buffer.writeln(escaped);
  }
  return buffer.toString();
}

Uint8List _toXlsx(List<List<String>> rows, {required String sheetName}) {
  final excel = Excel.createExcel();
  final sheet = excel[sheetName];
  for (final row in rows) {
    sheet.appendRow(row.map(TextCellValue.new).toList());
  }
  final bytes = excel.encode() ?? <int>[];
  return Uint8List.fromList(bytes);
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

List<List<String>> _buildSubmissionRows(List<FormSubmission> submissions) {
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
    'input_types',
    'visibility',
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
      resolveSubmissionInputTypes(submission).join('|'),
      resolveSubmissionAccessLevel(submission),
    ];
    for (final key in sortedKeys) {
      final value = submission.data[key];
      row.add(_formatValue(value));
    }
    rows.add(row);
  }

  return rows;
}

List<List<String>> _buildTaskRows(List<Task> tasks) {
  final rows = <List<String>>[];
  rows.add([
    'id',
    'title',
    'description',
    'instructions',
    'status',
    'progress',
    'due_date',
    'priority',
    'assigned_to',
    'assigned_to_name',
    'assigned_team',
    'created_at',
    'completed_at',
  ]);
  for (final task in tasks) {
    rows.add([
      task.id,
      task.title,
      task.description ?? '',
      task.instructions ?? '',
      task.status.name,
      task.progress.toString(),
      task.dueDate?.toIso8601String() ?? '',
      task.priority ?? '',
      task.assignedTo ?? '',
      task.assignedToName ?? '',
      task.assignedTeam ?? '',
      task.createdAt.toIso8601String(),
      task.completedAt?.toIso8601String() ?? '',
    ]);
  }
  return rows;
}

List<List<String>> _buildAssetRows(List<Equipment> assets) {
  final rows = <List<String>>[];
  rows.add([
    'id',
    'name',
    'category',
    'status',
    'location',
    'assigned_to',
    'next_maintenance_date',
    'next_inspection_at',
    'inspection_cadence',
    'contact_name',
    'contact_email',
    'contact_phone',
  ]);
  for (final asset in assets) {
    rows.add([
      asset.id,
      asset.name,
      asset.category ?? '',
      asset.isActive ? 'active' : 'inactive',
      asset.currentLocation ?? '',
      asset.assignedTo ?? '',
      asset.nextMaintenanceDate?.toIso8601String() ?? '',
      asset.nextInspectionAt?.toIso8601String() ?? '',
      asset.inspectionCadence ?? '',
      asset.contactName ?? '',
      asset.contactEmail ?? '',
      asset.contactPhone ?? '',
    ]);
  }
  return rows;
}

List<List<String>> _buildIncidentRows(List<IncidentReport> incidents) {
  final rows = <List<String>>[];
  rows.add([
    'id',
    'title',
    'status',
    'category',
    'severity',
    'occurred_at',
    'submitted_by',
    'submitted_by_name',
    'equipment_id',
    'job_site_id',
  ]);
  for (final incident in incidents) {
    rows.add([
      incident.id,
      incident.title,
      incident.status,
      incident.category ?? '',
      incident.severity ?? '',
      incident.occurredAt.toIso8601String(),
      incident.submittedBy ?? '',
      incident.submittedByName ?? '',
      incident.equipmentId ?? '',
      incident.jobSiteId ?? '',
    ]);
  }
  return rows;
}
