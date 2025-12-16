import 'package:shared/src/models/form_submission.dart';

/// Equipment model for tracking assets
class Equipment {
  final String id;
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
  final String? rfidTag;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;
  final bool isActive;
  final String? companyId;
  final Map<String, dynamic>? metadata;

  Equipment({
    required this.id,
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
    this.rfidTag,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    this.isActive = true,
    this.companyId,
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
      'rfidTag': rfidTag,
      'lastMaintenanceDate': lastMaintenanceDate?.toIso8601String(),
      'nextMaintenanceDate': nextMaintenanceDate?.toIso8601String(),
      'isActive': isActive,
      'companyId': companyId,
      'metadata': metadata,
    };
  }

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] as String,
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
      rfidTag: json['rfidTag'] as String?,
      lastMaintenanceDate: json['lastMaintenanceDate'] != null
          ? DateTime.parse(json['lastMaintenanceDate'] as String)
          : null,
      nextMaintenanceDate: json['nextMaintenanceDate'] != null
          ? DateTime.parse(json['nextMaintenanceDate'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      companyId: json['companyId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
