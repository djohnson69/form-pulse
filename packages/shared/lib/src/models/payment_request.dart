class PaymentRequest {
  final String id;
  final String orgId;
  final String? projectId;
  final double amount;
  final String currency;
  final String status;
  final String? description;
  final String? requestedBy;
  final DateTime requestedAt;
  final DateTime? paidAt;
  final Map<String, dynamic>? metadata;

  PaymentRequest({
    required this.id,
    required this.orgId,
    this.projectId,
    required this.amount,
    this.currency = 'USD',
    this.status = 'requested',
    this.description,
    this.requestedBy,
    required this.requestedAt,
    this.paidAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'projectId': projectId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'description': description,
      'requestedBy': requestedBy,
      'requestedAt': requestedAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    return PaymentRequest(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      projectId: json['projectId'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      status: json['status'] as String? ?? 'requested',
      description: json['description'] as String?,
      requestedBy: json['requestedBy'] as String?,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      paidAt:
          json['paidAt'] != null ? DateTime.parse(json['paidAt'] as String) : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
