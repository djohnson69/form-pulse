import 'package:shared/shared.dart';

class MessageParticipantEntry {
  MessageParticipantEntry({
    required this.id,
    required this.threadId,
    this.userId,
    this.clientId,
    this.vendorId,
    required this.displayName,
    this.role,
    required this.isActive,
    this.lastReadAt,
    this.lastDeliveredAt,
    required this.notificationLevel,
    this.muteUntil,
    required this.isArchived,
    this.leftAt,
    this.metadata,
  });

  final String id;
  final String threadId;
  final String? userId;
  final String? clientId;
  final String? vendorId;
  final String displayName;
  final String? role;
  final bool isActive;
  final DateTime? lastReadAt;
  final DateTime? lastDeliveredAt;
  final String notificationLevel;
  final DateTime? muteUntil;
  final bool isArchived;
  final DateTime? leftAt;
  final Map<String, dynamic>? metadata;
}

class MessageReactionEntry {
  MessageReactionEntry({
    required this.id,
    required this.threadId,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  final String id;
  final String threadId;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;
}

class MessageAttachmentEntry {
  MessageAttachmentEntry({
    required this.name,
    required this.bucket,
    required this.path,
    required this.contentType,
    required this.size,
    required this.isImage,
    this.url,
  });

  final String name;
  final String bucket;
  final String path;
  final String contentType;
  final int size;
  final bool isImage;
  final String? url;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'bucket': bucket,
      'storagePath': path,
      'contentType': contentType,
      'size': size,
      'isImage': isImage,
      if (url != null) 'url': url,
    };
  }

  static MessageAttachmentEntry? fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString();
    final bucket = json['bucket']?.toString();
    final path =
        json['storagePath']?.toString() ?? json['path']?.toString();
    if (name == null || bucket == null || path == null) return null;
    return MessageAttachmentEntry(
      name: name,
      bucket: bucket,
      path: path,
      contentType: json['contentType']?.toString() ?? 'application/octet-stream',
      size: json['size'] is int
          ? json['size'] as int
          : int.tryParse(json['size']?.toString() ?? '') ?? 0,
      isImage: json['isImage'] == true,
      url: json['url']?.toString(),
    );
  }
}

class ThreadMessagesBundle {
  ThreadMessagesBundle({
    required this.thread,
    required this.messages,
    required this.participants,
    required this.reactions,
    required this.deletedMessageIds,
    required this.currentParticipant,
  });

  final MessageThread thread;
  final List<Message> messages;
  final List<MessageParticipantEntry> participants;
  final Map<String, List<MessageReactionEntry>> reactions;
  final Set<String> deletedMessageIds;
  final MessageParticipantEntry? currentParticipant;
}

class MessageUploadAttachment {
  MessageUploadAttachment({
    required this.name,
    required this.bytes,
    required this.contentType,
    required this.size,
    required this.isImage,
  });

  final String name;
  final List<int> bytes;
  final String contentType;
  final int size;
  final bool isImage;
}

class ThreadSearchResult {
  ThreadSearchResult({
    required this.threadId,
    required this.messageId,
    required this.preview,
  });

  final String threadId;
  final String messageId;
  final String preview;
}
