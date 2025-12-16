/// Document model for document management
class Document {
  final String id;
  final String title;
  final String? description;
  final String? category;
  final String fileUrl;
  final String? localPath;
  final String filename;
  final String mimeType;
  final int fileSize;
  final String version;
  final String uploadedBy;
  final DateTime uploadedAt;
  final DateTime? updatedAt;
  final bool isPublished;
  final List<String>? tags;
  final String? companyId;
  final Map<String, dynamic>? metadata;

  Document({
    required this.id,
    required this.title,
    this.description,
    this.category,
    required this.fileUrl,
    this.localPath,
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    required this.version,
    required this.uploadedBy,
    required this.uploadedAt,
    this.updatedAt,
    this.isPublished = true,
    this.tags,
    this.companyId,
    this.metadata,
  });

  /// Get formatted file size
  String get formattedFileSize {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var size = fileSize.toDouble();
    var suffixIndex = 0;
    
    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }
    
    return '${size.toStringAsFixed(2)} ${suffixes[suffixIndex]}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'fileUrl': fileUrl,
      'localPath': localPath,
      'filename': filename,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'version': version,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isPublished': isPublished,
      'tags': tags,
      'companyId': companyId,
      'metadata': metadata,
    };
  }

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      fileUrl: json['fileUrl'] as String,
      localPath: json['localPath'] as String?,
      filename: json['filename'] as String,
      mimeType: json['mimeType'] as String,
      fileSize: json['fileSize'] as int,
      version: json['version'] as String,
      uploadedBy: json['uploadedBy'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      isPublished: json['isPublished'] as bool? ?? true,
      tags: (json['tags'] as List?)?.cast<String>(),
      companyId: json['companyId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
