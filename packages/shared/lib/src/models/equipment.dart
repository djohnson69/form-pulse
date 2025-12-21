import 'package:shared/src/models/form_submission.dart';

/// Equipment model for tracking assets
class Equipment {
  final String id;
  final String? orgId;
  final String name;
  final String? description;
  final String? category;
  final String? manufacturer;
  final String? modelNumber;
  final String? serialNumber;
  final DateTime? purchaseDate;
  final String? assignedTo;
  final String? currentLocation;
  final LocationData? gpsLocation;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String? rfidTag;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;
  final String? inspectionCadence;
  final DateTime? lastInspectionAt;
  final DateTime? nextInspectionAt;
  final bool isActive;
  final String? companyId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  Equipment({
    required this.id,
    this.orgId,
    required this.name,
    this.description,
    this.category,
    this.manufacturer,
    this.modelNumber,
    this.serialNumber,
    this.purchaseDate,
    this.assignedTo,
    this.currentLocation,
    this.gpsLocation,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.rfidTag,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    this.inspectionCadence,
    this.lastInspectionAt,
    this.nextInspectionAt,
    this.isActive = true,
    this.companyId,
    this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  /// Check if maintenance is due
  bool get isMaintenanceDue {
    if (nextMaintenanceDate == null) return false;
    return DateTime.now().isAfter(nextMaintenanceDate!);
  }

  /// Get days until next maintenance
  int? get daysUntilMaintenance {
    if (nextMaintenanceDate == null) return null;
    return nextMaintenanceDate!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'name': name,
      'description': description,
      'category': category,
      'manufacturer': manufacturer,
      'modelNumber': modelNumber,
      'serialNumber': serialNumber,
      'purchaseDate': purchaseDate?.toIso8601String(),
      'assignedTo': assignedTo,
      'currentLocation': currentLocation,
      'gpsLocation': gpsLocation?.toJson(),
      'contactName': contactName,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'rfidTag': rfidTag,
      'lastMaintenanceDate': lastMaintenanceDate?.toIso8601String(),
      'nextMaintenanceDate': nextMaintenanceDate?.toIso8601String(),
      'inspectionCadence': inspectionCadence,
      'lastInspectionAt': lastInspectionAt?.toIso8601String(),
      'nextInspectionAt': nextInspectionAt?.toIso8601String(),
      'isActive': isActive,
      'companyId': companyId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] as String,
      orgId: json['orgId'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      manufacturer: json['manufacturer'] as String?,
      modelNumber: json['modelNumber'] as String?,
      serialNumber: json['serialNumber'] as String?,
      purchaseDate: json['purchaseDate'] != null
          ? DateTime.parse(json['purchaseDate'] as String)
          : null,
      assignedTo: json['assignedTo'] as String?,
      currentLocation: json['currentLocation'] as String?,
      gpsLocation: json['gpsLocation'] != null
          ? LocationData.fromJson(json['gpsLocation'] as Map<String, dynamic>)
          : null,
      contactName: json['contactName'] as String?,
      contactEmail: json['contactEmail'] as String?,
      contactPhone: json['contactPhone'] as String?,
      rfidTag: json['rfidTag'] as String?,
      lastMaintenanceDate: json['lastMaintenanceDate'] != null
          ? DateTime.parse(json['lastMaintenanceDate'] as String)
          : null,
      nextMaintenanceDate: json['nextMaintenanceDate'] != null
          ? DateTime.parse(json['nextMaintenanceDate'] as String)
          : null,
      inspectionCadence: json['inspectionCadence'] as String?,
      lastInspectionAt: json['lastInspectionAt'] != null
          ? DateTime.parse(json['lastInspectionAt'] as String)
          : null,
      nextInspectionAt: json['nextInspectionAt'] != null
          ? DateTime.parse(json['nextInspectionAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      companyId: json['companyId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
