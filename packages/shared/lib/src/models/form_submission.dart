import 'package:shared/src/enums/submission_status.dart';

/// Form submission model
class FormSubmission {
  final String id;
  final String formId;
  final String formTitle;
  final String submittedBy;
  final String? submittedByName;
  final DateTime submittedAt;
  final SubmissionStatus status;
  final Map<String, dynamic> data;
  final List<MediaAttachment>? attachments;
  final LocationData? location;
  final String? jobSiteId;
  final String? companyId;
  final DateTime? syncedAt;
  final Map<String, dynamic>? metadata;

  FormSubmission({
    required this.id,
    required this.formId,
    required this.formTitle,
    required this.submittedBy,
    this.submittedByName,
    required this.submittedAt,
    required this.status,
    required this.data,
    this.attachments,
    this.location,
    this.jobSiteId,
    this.companyId,
    this.syncedAt,
    this.metadata,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'formId': formId,
      'formTitle': formTitle,
      'submittedBy': submittedBy,
      'submittedByName': submittedByName,
      'submittedAt': submittedAt.toIso8601String(),
      'status': status.name,
      'data': data,
      'attachments': attachments?.map((a) => a.toJson()).toList(),
      'location': location?.toJson(),
      'jobSiteId': jobSiteId,
      'companyId': companyId,
      'syncedAt': syncedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory FormSubmission.fromJson(Map<String, dynamic> json) {
    return FormSubmission(
      id: json['id'] as String,
      formId: json['formId'] as String,
      formTitle: json['formTitle'] as String,
      submittedBy: json['submittedBy'] as String,
      submittedByName: json['submittedByName'] as String?,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      status: SubmissionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubmissionStatus.submitted,
      ),
      data: json['data'] as Map<String, dynamic>,
      attachments: (json['attachments'] as List?)
          ?.map((a) => MediaAttachment.fromJson(a as Map<String, dynamic>))
          .toList(),
      location: json['location'] != null
          ? LocationData.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      jobSiteId: json['jobSiteId'] as String?,
      companyId: json['companyId'] as String?,
      syncedAt: json['syncedAt'] != null
          ? DateTime.parse(json['syncedAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Media attachment model
class MediaAttachment {
  final String id;
  final String type; // photo, video, file
  final String url;
  final String? localPath;
  final String? filename;
  final int? fileSize;
  final String? mimeType;
  final DateTime capturedAt;
  final LocationData? location;
  final Map<String, dynamic>? metadata;

  MediaAttachment({
    required this.id,
    required this.type,
    required this.url,
    this.localPath,
    this.filename,
    this.fileSize,
    this.mimeType,
    required this.capturedAt,
    this.location,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'url': url,
      'localPath': localPath,
      'filename': filename,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'capturedAt': capturedAt.toIso8601String(),
      'location': location?.toJson(),
      'metadata': metadata,
    };
  }

  factory MediaAttachment.fromJson(Map<String, dynamic> json) {
    return MediaAttachment(
      id: json['id'] as String,
      type: json['type'] as String,
      url: json['url'] as String,
      localPath: json['localPath'] as String?,
      filename: json['filename'] as String?,
      fileSize: json['fileSize'] as int?,
      mimeType: json['mimeType'] as String?,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      location: json['location'] != null
          ? LocationData.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Location data model
class LocationData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final DateTime timestamp;
  final String? address;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    required this.timestamp,
    this.address,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'address': address,
    };
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: _parseRequiredDouble(json, 'latitude'),
      longitude: _parseRequiredDouble(json, 'longitude'),
      altitude: _parseOptionalDouble(json, 'altitude'),
      accuracy: _parseOptionalDouble(json, 'accuracy'),
      timestamp: DateTime.parse(json['timestamp'] as String),
      address: json['address'] as String?,
    );
  }
}

double _parseRequiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('Expected $key to be a numeric value but got $value');
}

double? _parseOptionalDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('Expected $key to be a numeric value but got $value');
}
