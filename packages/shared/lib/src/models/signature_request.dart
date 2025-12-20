class SignatureRequest {
  final String id;
  final String orgId;
  final String? documentId;
  final String? requestName;
  final String? signerName;
  final String? signerEmail;
  final String status;
  final String? token;
  final String? requestedBy;
  final DateTime requestedAt;
  final DateTime? signedAt;
  final Map<String, dynamic>? signatureData;
  final String? fileUrl;
  final Map<String, dynamic>? metadata;

  SignatureRequest({
    required this.id,
    required this.orgId,
    this.documentId,
    this.requestName,
    this.signerName,
    this.signerEmail,
    this.status = 'pending',
    this.token,
    this.requestedBy,
    required this.requestedAt,
    this.signedAt,
    this.signatureData,
    this.fileUrl,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'documentId': documentId,
      'requestName': requestName,
      'signerName': signerName,
      'signerEmail': signerEmail,
      'status': status,
      'token': token,
      'requestedBy': requestedBy,
      'requestedAt': requestedAt.toIso8601String(),
      'signedAt': signedAt?.toIso8601String(),
      'signatureData': signatureData,
      'fileUrl': fileUrl,
      'metadata': metadata,
    };
  }

  factory SignatureRequest.fromJson(Map<String, dynamic> json) {
    return SignatureRequest(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      documentId: json['documentId'] as String?,
      requestName: json['requestName'] as String?,
      signerName: json['signerName'] as String?,
      signerEmail: json['signerEmail'] as String?,
      status: json['status'] as String? ?? 'pending',
      token: json['token'] as String?,
      requestedBy: json['requestedBy'] as String?,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      signedAt: json['signedAt'] != null
          ? DateTime.parse(json['signedAt'] as String)
          : null,
      signatureData: json['signatureData'] as Map<String, dynamic>?,
      fileUrl: json['fileUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
