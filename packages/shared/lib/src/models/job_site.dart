import 'package:shared/src/models/form_submission.dart';

/// Job site model
class JobSite {
  final String id;
  final String name;
  final String? description;
  final String? address;
  final LocationData? location;
  final String? clientId;
  final String? clientName;
  final List<String>? assignedEmployees;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final String? projectManager;
  final String? companyId;
  final Map<String, dynamic>? metadata;

  JobSite({
    required this.id,
    required this.name,
    this.description,
    this.address,
    this.location,
    this.clientId,
    this.clientName,
    this.assignedEmployees,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.projectManager,
    this.companyId,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'location': location?.toJson(),
      'clientId': clientId,
      'clientName': clientName,
      'assignedEmployees': assignedEmployees,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive,
      'projectManager': projectManager,
      'companyId': companyId,
      'metadata': metadata,
    };
  }

  factory JobSite.fromJson(Map<String, dynamic> json) {
    return JobSite(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      location: json['location'] != null
          ? LocationData.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      clientId: json['clientId'] as String?,
      clientName: json['clientName'] as String?,
      assignedEmployees: (json['assignedEmployees'] as List?)?.cast<String>(),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      projectManager: json['projectManager'] as String?,
      companyId: json['companyId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
