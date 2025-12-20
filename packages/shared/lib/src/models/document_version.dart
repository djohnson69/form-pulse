/// Document version model
class DocumentVersion {
  final String id;
  final String documentId;
  final String version;
  final String fileUrl;
  final String filename;
  final String mimeType;
  final int fileSize;
  final String? uploadedBy;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  DocumentVersion({
    required this.id,
    required this.documentId,
    required this.version,
    required this.fileUrl,
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    this.uploadedBy,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentId': documentId,
      'version': version,
      'fileUrl': fileUrl,
      'filename': filename,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'uploadedBy': uploadedBy,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory DocumentVersion.fromJson(Map<String, dynamic> json) {
    return DocumentVersion(
      id: json['id'] as String,
      documentId: json['documentId'] as String,
      version: json['version'] as String,
      fileUrl: json['fileUrl'] as String,
      filename: json['filename'] as String,
      mimeType: json['mimeType'] as String,
      fileSize: json['fileSize'] as int,
      uploadedBy: json['uploadedBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
