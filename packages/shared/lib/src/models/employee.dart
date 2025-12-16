import 'package:shared/src/enums/training_status.dart';

/// Employee model
class Employee {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String? photoUrl;
  final String? phoneNumber;
  final String? employeeNumber;
  final String? department;
  final String? position;
  final DateTime hireDate;
  final DateTime? terminationDate;
  final bool isActive;
  final List<String>? certifications;
  final List<Training>? trainingHistory;
  final String? companyId;
  final Map<String, dynamic>? metadata;

  Employee({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.photoUrl,
    this.phoneNumber,
    this.employeeNumber,
    this.department,
    this.position,
    required this.hireDate,
    this.terminationDate,
    this.isActive = true,
    this.certifications,
    this.trainingHistory,
    this.companyId,
    this.metadata,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'employeeNumber': employeeNumber,
      'department': department,
      'position': position,
      'hireDate': hireDate.toIso8601String(),
      'terminationDate': terminationDate?.toIso8601String(),
      'isActive': isActive,
      'certifications': certifications,
      'trainingHistory': trainingHistory?.map((t) => t.toJson()).toList(),
      'companyId': companyId,
      'metadata': metadata,
    };
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      userId: json['userId'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      employeeNumber: json['employeeNumber'] as String?,
      department: json['department'] as String?,
      position: json['position'] as String?,
      hireDate: DateTime.parse(json['hireDate'] as String),
      terminationDate: json['terminationDate'] != null
          ? DateTime.parse(json['terminationDate'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      certifications: (json['certifications'] as List?)?.cast<String>(),
      trainingHistory: (json['trainingHistory'] as List?)
          ?.map((t) => Training.fromJson(t as Map<String, dynamic>))
          .toList(),
      companyId: json['companyId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Training record model
class Training {
  final String id;
  final String employeeId;
  final String trainingName;
  final String? trainingType;
  final TrainingStatus status;
  final DateTime? completedDate;
  final DateTime? expirationDate;
  final String? instructorName;
  final double? score;
  final String? certificateUrl;
  final DateTime? nextRecertificationDate;
  final Map<String, dynamic>? metadata;

  Training({
    required this.id,
    required this.employeeId,
    required this.trainingName,
    this.trainingType,
    required this.status,
    this.completedDate,
    this.expirationDate,
    this.instructorName,
    this.score,
    this.certificateUrl,
    this.nextRecertificationDate,
    this.metadata,
  });

  /// Check if training is expired
  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.now().isAfter(expirationDate!);
  }

  /// Get days until expiration
  int? get daysUntilExpiration {
    if (expirationDate == null) return null;
    return expirationDate!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'trainingName': trainingName,
      'trainingType': trainingType,
      'status': status.name,
      'completedDate': completedDate?.toIso8601String(),
      'expirationDate': expirationDate?.toIso8601String(),
      'instructorName': instructorName,
      'score': score,
      'certificateUrl': certificateUrl,
      'nextRecertificationDate': nextRecertificationDate?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Training.fromJson(Map<String, dynamic> json) {
    return Training(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      trainingName: json['trainingName'] as String,
      trainingType: json['trainingType'] as String?,
      status: TrainingStatus.values.firstWhere((e) => e.name == json['status']),
      completedDate: json['completedDate'] != null
          ? DateTime.parse(json['completedDate'] as String)
          : null,
      expirationDate: json['expirationDate'] != null
          ? DateTime.parse(json['expirationDate'] as String)
          : null,
      instructorName: json['instructorName'] as String?,
      score: _parseNullableDouble(json['score']),
      certificateUrl: json['certificateUrl'] as String?,
      nextRecertificationDate: json['nextRecertificationDate'] != null
          ? DateTime.parse(json['nextRecertificationDate'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

double? _parseNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('Expected score to be numeric but got $value');
}
