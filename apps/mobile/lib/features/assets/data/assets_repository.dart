import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/storage_utils.dart';

class AttachmentDraft {
  AttachmentDraft({
    required this.type,
    required this.bytes,
    required this.filename,
    required this.mimeType,
    this.metadata,
  });

  final String type;
  final Uint8List bytes;
  final String filename;
  final String mimeType;
  final Map<String, dynamic>? metadata;
}

abstract class AssetsRepositoryBase {
  Future<List<Equipment>> fetchEquipment();
  Future<Equipment> createEquipment(Equipment equipment);
  Future<Equipment> updateEquipment(Equipment equipment);

  Future<List<AssetInspection>> fetchInspections(String equipmentId);
  Future<AssetInspection> createInspection({
    required String equipmentId,
    required String status,
    String? notes,
    DateTime? inspectedAt,
    LocationData? location,
    List<AttachmentDraft> attachments = const [],
  });

  Future<List<IncidentReport>> fetchIncidents({String? equipmentId});
  Future<IncidentReport> createIncident({
    required String title,
    String? description,
    String? category,
    String? severity,
    String? equipmentId,
    String? jobSiteId,
    DateTime? occurredAt,
    LocationData? location,
    List<AttachmentDraft> attachments = const [],
  });
}

class SupabaseAssetsRepository implements AssetsRepositoryBase {
  SupabaseAssetsRepository(this._client);

  final SupabaseClient _client;
  static const _bucketName =
      String.fromEnvironment('SUPABASE_BUCKET', defaultValue: 'formbridge-attachments');

  @override
  Future<List<Equipment>> fetchEquipment() async {
    try {
      final orgId = await _getOrgId();
      if (orgId == null) return const [];
      final rows = await _client
          .from('equipment')
          .select()
          .eq('org_id', orgId)
          .order('updated_at', ascending: false);
      return (rows as List<dynamic>)
          .map((row) => _mapEquipment(Map<String, dynamic>.from(row as Map)))
          .toList();
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase fetchEquipment failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Equipment> createEquipment(Equipment equipment) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization.');
    }
    final payload = _toEquipmentPayload(equipment, orgId);
    try {
      final res =
          await _client.from('equipment').insert(payload).select().single();
      return _mapEquipment(Map<String, dynamic>.from(res as Map));
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase createEquipment failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Equipment> updateEquipment(Equipment equipment) async {
    final payload = _toEquipmentPayload(equipment, null);
    try {
      final res = await _client
          .from('equipment')
          .update(payload)
          .eq('id', equipment.id)
          .select()
          .single();
      return _mapEquipment(Map<String, dynamic>.from(res as Map));
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase updateEquipment failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<AssetInspection>> fetchInspections(String equipmentId) async {
    try {
      final rows = await _client
          .from('asset_inspections')
          .select()
          .eq('equipment_id', equipmentId)
          .order('inspected_at', ascending: false);
      final mapped = (rows as List<dynamic>)
          .map((row) => _mapInspection(Map<String, dynamic>.from(row as Map)))
          .toList();
      return Future.wait(mapped.map(_signInspectionAttachments));
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase fetchInspections failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<AssetInspection> createInspection({
    required String equipmentId,
    required String status,
    String? notes,
    DateTime? inspectedAt,
    LocationData? location,
    List<AttachmentDraft> attachments = const [],
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization.');
    }
    final uploaded = await _uploadAttachments(
      orgId: orgId,
      folder: 'inspections',
      attachments: attachments,
      location: location,
    );
    final payload = {
      'org_id': orgId,
      'equipment_id': equipmentId,
      'status': status,
      'notes': notes,
      'inspected_at': (inspectedAt ?? DateTime.now()).toIso8601String(),
      'created_by': _client.auth.currentUser?.id,
      'attachments': uploaded.map((a) => a.toJson()).toList(),
      'location': location?.toJson(),
    };
    try {
      final res = await _client
          .from('asset_inspections')
          .insert(payload)
          .select()
          .single();
      final inspection = _mapInspection(Map<String, dynamic>.from(res as Map));
      await _updateInspectionSchedule(
        equipmentId: equipmentId,
        inspectedAt: inspection.inspectedAt,
      );
      return _signInspectionAttachments(inspection);
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase createInspection failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<IncidentReport>> fetchIncidents({String? equipmentId}) async {
    try {
      final baseQuery = _client.from('incident_reports').select();
      final filteredQuery =
          equipmentId != null && equipmentId.isNotEmpty
              ? baseQuery.eq('equipment_id', equipmentId)
              : baseQuery;
      final rows = await filteredQuery.order('occurred_at', ascending: false);
      final mapped = (rows as List<dynamic>)
          .map((row) => _mapIncident(Map<String, dynamic>.from(row as Map)))
          .toList();
      return Future.wait(mapped.map(_signIncidentAttachments));
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase fetchIncidents failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<IncidentReport> createIncident({
    required String title,
    String? description,
    String? category,
    String? severity,
    String? equipmentId,
    String? jobSiteId,
    DateTime? occurredAt,
    LocationData? location,
    List<AttachmentDraft> attachments = const [],
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization.');
    }
    final uploaded = await _uploadAttachments(
      orgId: orgId,
      folder: 'incidents',
      attachments: attachments,
      location: location,
    );
    final payload = {
      'org_id': orgId,
      'equipment_id': equipmentId,
      'job_site_id': jobSiteId,
      'title': title,
      'description': description,
      'status': 'open',
      'category': category,
      'severity': severity,
      'occurred_at': (occurredAt ?? DateTime.now()).toIso8601String(),
      'submitted_by': _client.auth.currentUser?.id,
      'attachments': uploaded.map((a) => a.toJson()).toList(),
      'location': location?.toJson(),
    };
    try {
      final res = await _client
          .from('incident_reports')
          .insert(payload)
          .select()
          .single();
      final report = _mapIncident(Map<String, dynamic>.from(res as Map));
      return _signIncidentAttachments(report);
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase createIncident failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<List<MediaAttachment>> _uploadAttachments({
    required String orgId,
    required String folder,
    required List<AttachmentDraft> attachments,
    LocationData? location,
  }) async {
    if (attachments.isEmpty) return const [];
    final uploads = <MediaAttachment>[];
    for (final draft in attachments) {
      final path = await _uploadFile(
        orgId: orgId,
        folder: folder,
        filename: draft.filename,
        mimeType: draft.mimeType,
        bytes: draft.bytes,
      );
      uploads.add(
        MediaAttachment(
          id: const Uuid().v4(),
          type: draft.type,
          url: path,
          filename: draft.filename,
          fileSize: draft.bytes.length,
          mimeType: draft.mimeType,
          capturedAt: DateTime.now(),
          location: location,
          metadata: {
            'bucket': _bucketName,
            if (draft.metadata != null) ...draft.metadata!,
          },
        ),
      );
    }
    return uploads;
  }

  Future<String> _uploadFile({
    required String orgId,
    required String folder,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final prefix = orgId.isNotEmpty ? 'org-$orgId' : 'public';
    final safeName = filename.replaceAll(' ', '_');
    final path =
        '$prefix/assets/$folder/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _client.storage.from(_bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: mimeType,
          ),
        );
    return path;
  }

  Equipment _mapEquipment(Map<String, dynamic> row) {
    return Equipment(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString(),
      name: row['name'] as String? ?? '',
      description: row['description'] as String?,
      category: row['category'] as String?,
      manufacturer: row['manufacturer'] as String?,
      modelNumber: row['model_number'] as String?,
      serialNumber: row['serial_number'] as String?,
      purchaseDate: _parseNullableDate(row['purchase_date']),
      assignedTo: row['assigned_to'] as String?,
      currentLocation: row['current_location'] as String?,
      gpsLocation: row['gps_location'] != null
          ? LocationData.fromJson(
              Map<String, dynamic>.from(row['gps_location'] as Map),
            )
          : null,
      contactName: row['contact_name'] as String?,
      contactEmail: row['contact_email'] as String?,
      contactPhone: row['contact_phone'] as String?,
      rfidTag: row['rfid_tag'] as String?,
      lastMaintenanceDate: _parseNullableDate(row['last_maintenance_date']),
      nextMaintenanceDate: _parseNullableDate(row['next_maintenance_date']),
      inspectionCadence: row['inspection_cadence'] as String?,
      lastInspectionAt: _parseNullableDate(row['last_inspection_at']),
      nextInspectionAt: _parseNullableDate(row['next_inspection_at']),
      isActive: row['is_active'] as bool? ?? true,
      companyId: row['company_id'] as String?,
      createdAt: _parseNullableDate(row['created_at']),
      updatedAt: _parseNullableDate(row['updated_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  AssetInspection _mapInspection(Map<String, dynamic> row) {
    return AssetInspection(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      equipmentId: row['equipment_id']?.toString() ?? '',
      status: row['status'] as String? ?? 'pass',
      notes: row['notes'] as String?,
      attachments: (row['attachments'] as List?)
          ?.map((a) => MediaAttachment.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList(),
      location: row['location'] != null
          ? LocationData.fromJson(
              Map<String, dynamic>.from(row['location'] as Map),
            )
          : null,
      inspectedAt: _parseDate(row['inspected_at']),
      createdBy: row['created_by']?.toString(),
      createdByName: row['created_by_name'] as String?,
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  IncidentReport _mapIncident(Map<String, dynamic> row) {
    return IncidentReport(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      equipmentId: row['equipment_id']?.toString(),
      jobSiteId: row['job_site_id']?.toString(),
      title: row['title'] as String? ?? '',
      description: row['description'] as String?,
      status: row['status'] as String? ?? 'open',
      category: row['category'] as String?,
      severity: row['severity'] as String?,
      occurredAt: _parseDate(row['occurred_at']),
      submittedBy: row['submitted_by']?.toString(),
      submittedByName: row['submitted_by_name'] as String?,
      location: row['location'] != null
          ? LocationData.fromJson(
              Map<String, dynamic>.from(row['location'] as Map),
            )
          : null,
      attachments: (row['attachments'] as List?)
          ?.map((a) => MediaAttachment.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList(),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  Future<AssetInspection> _signInspectionAttachments(
    AssetInspection inspection,
  ) async {
    final attachments = inspection.attachments;
    if (attachments == null || attachments.isEmpty) return inspection;
    final signed = await Future.wait(attachments.map(_signAttachment));
    return AssetInspection(
      id: inspection.id,
      orgId: inspection.orgId,
      equipmentId: inspection.equipmentId,
      status: inspection.status,
      notes: inspection.notes,
      attachments: signed,
      location: inspection.location,
      inspectedAt: inspection.inspectedAt,
      createdBy: inspection.createdBy,
      createdByName: inspection.createdByName,
      metadata: inspection.metadata,
    );
  }

  Future<IncidentReport> _signIncidentAttachments(
    IncidentReport report,
  ) async {
    final attachments = report.attachments;
    if (attachments == null || attachments.isEmpty) return report;
    final signed = await Future.wait(attachments.map(_signAttachment));
    return IncidentReport(
      id: report.id,
      orgId: report.orgId,
      equipmentId: report.equipmentId,
      jobSiteId: report.jobSiteId,
      title: report.title,
      description: report.description,
      status: report.status,
      category: report.category,
      severity: report.severity,
      occurredAt: report.occurredAt,
      submittedBy: report.submittedBy,
      submittedByName: report.submittedByName,
      location: report.location,
      attachments: signed,
      metadata: report.metadata,
    );
  }

  Future<MediaAttachment> _signAttachment(MediaAttachment attachment) async {
    try {
      final signedUrl = await createSignedStorageUrl(
        client: _client,
        url: attachment.url,
        defaultBucket: _bucketName,
        metadata: attachment.metadata,
        expiresInSeconds: kSignedUrlExpirySeconds,
      );
      if (signedUrl == null || signedUrl.isEmpty) return attachment;
      return MediaAttachment(
        id: attachment.id,
        type: attachment.type,
        url: signedUrl,
        localPath: attachment.localPath,
        filename: attachment.filename,
        fileSize: attachment.fileSize,
        mimeType: attachment.mimeType,
        capturedAt: attachment.capturedAt,
        location: attachment.location,
        metadata: attachment.metadata,
      );
    } catch (_) {
      return attachment;
    }
  }

  Future<String?> _getOrgId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final res = await _client
          .from('org_members')
          .select('org_id')
          .eq('user_id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    try {
      final res = await _client
          .from('profiles')
          .select('org_id')
          .eq('id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _toEquipmentPayload(Equipment equipment, String? orgId) {
    return {
      if (orgId != null) 'org_id': orgId,
      'name': equipment.name,
      'description': equipment.description,
      'category': equipment.category,
      'manufacturer': equipment.manufacturer,
      'model_number': equipment.modelNumber,
      'serial_number': equipment.serialNumber,
      'purchase_date': equipment.purchaseDate?.toIso8601String(),
      'assigned_to': equipment.assignedTo,
      'current_location': equipment.currentLocation,
      'gps_location': equipment.gpsLocation?.toJson(),
      'contact_name': equipment.contactName,
      'contact_email': equipment.contactEmail,
      'contact_phone': equipment.contactPhone,
      'rfid_tag': equipment.rfidTag,
      'last_maintenance_date': equipment.lastMaintenanceDate?.toIso8601String(),
      'next_maintenance_date': equipment.nextMaintenanceDate?.toIso8601String(),
      'inspection_cadence': equipment.inspectionCadence,
      'last_inspection_at': equipment.lastInspectionAt?.toIso8601String(),
      'next_inspection_at': equipment.nextInspectionAt?.toIso8601String(),
      'is_active': equipment.isActive,
      'metadata': equipment.metadata ?? const {},
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _updateInspectionSchedule({
    required String equipmentId,
    required DateTime inspectedAt,
  }) async {
    try {
      final row = await _client
          .from('equipment')
          .select('inspection_cadence')
          .eq('id', equipmentId)
          .maybeSingle();
      final cadence = row?['inspection_cadence']?.toString();
      if (cadence == null || cadence.trim().isEmpty) {
        await _client.from('equipment').update({
          'last_inspection_at': inspectedAt.toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', equipmentId);
        return;
      }
      final nextAt = _computeNextInspection(cadence, inspectedAt);
      await _client.from('equipment').update({
        'last_inspection_at': inspectedAt.toIso8601String(),
        'next_inspection_at': nextAt?.toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', equipmentId);
    } catch (e, st) {
      developer.log(
        'Failed to update inspection schedule',
        error: e,
        stackTrace: st,
      );
    }
  }

  DateTime? _computeNextInspection(String cadence, DateTime inspectedAt) {
    switch (cadence) {
      case 'daily':
        return inspectedAt.add(const Duration(days: 1));
      case 'weekly':
        return inspectedAt.add(const Duration(days: 7));
      case 'quarterly':
        return inspectedAt.add(const Duration(days: 90));
      default:
        return null;
    }
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.parse(value.toString());
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
