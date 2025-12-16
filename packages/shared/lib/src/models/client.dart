/// Client model for client portal
class Client {
  final String id;
  final String companyName;
  final String? contactName;
  final String? email;
  final String? phoneNumber;
  final String? address;
  final String? website;
  final List<String>? assignedJobSites;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  Client({
    required this.id,
    required this.companyName,
    this.contactName,
    this.email,
    this.phoneNumber,
    this.address,
    this.website,
    this.assignedJobSites,
    this.isActive = true,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyName': companyName,
      'contactName': contactName,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'website': website,
      'assignedJobSites': assignedJobSites,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as String,
      companyName: json['companyName'] as String,
      contactName: json['contactName'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      address: json['address'] as String?,
      website: json['website'] as String?,
      assignedJobSites: (json['assignedJobSites'] as List?)?.cast<String>(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Vendor model for vendor portal
class Vendor {
  final String id;
  final String companyName;
  final String? contactName;
  final String? email;
  final String? phoneNumber;
  final String? address;
  final String? website;
  final String? serviceCategory;
  final List<String>? certifications;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  Vendor({
    required this.id,
    required this.companyName,
    this.contactName,
    this.email,
    this.phoneNumber,
    this.address,
    this.website,
    this.serviceCategory,
    this.certifications,
    this.isActive = true,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyName': companyName,
      'contactName': contactName,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'website': website,
      'serviceCategory': serviceCategory,
      'certifications': certifications,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] as String,
      companyName: json['companyName'] as String,
      contactName: json['contactName'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      address: json['address'] as String?,
      website: json['website'] as String?,
      serviceCategory: json['serviceCategory'] as String?,
      certifications: (json['certifications'] as List?)?.cast<String>(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
