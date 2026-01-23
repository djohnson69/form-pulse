import 'chat_message.dart';

/// A conversation containing multiple chat messages
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.userId,
    this.orgId,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.messages = const [],
  });

  final String id;
  final String userId;
  final String? orgId;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final List<ChatMessage> messages;

  bool get isArchived => archivedAt != null;
  bool get isEmpty => messages.isEmpty;
  int get messageCount => messages.length;

  /// Get the last message in the conversation
  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;

  /// Generate a title from the first user message
  String get displayTitle {
    final t = title;
    if (t != null && t.isNotEmpty) return t;
    final firstUserMessage = messages.where((m) => m.role == ChatRole.user).firstOrNull;
    if (firstUserMessage != null) {
      final content = firstUserMessage.content;
      if (content.length <= 50) return content;
      return '${content.substring(0, 47)}...';
    }
    return 'New conversation';
  }

  /// Create from JSON (Supabase row with optional messages)
  factory ChatConversation.fromJson(Map<String, dynamic> json, {List<ChatMessage>? messages}) {
    return ChatConversation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      orgId: json['org_id'] as String?,
      title: json['title'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'] as String)
          : null,
      messages: messages ?? const [],
    );
  }

  /// Convert to JSON for Supabase insert
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      if (orgId != null) 'org_id': orgId,
      if (title != null) 'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (archivedAt != null) 'archived_at': archivedAt!.toIso8601String(),
    };
  }

  /// Convert to JSON for insert (without id, let DB generate)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      if (orgId != null) 'org_id': orgId,
      if (title != null) 'title': title,
    };
  }

  ChatConversation copyWith({
    String? id,
    String? userId,
    String? orgId,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orgId: orgId ?? this.orgId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      messages: messages ?? this.messages,
    );
  }

  /// Add a message to the conversation
  ChatConversation addMessage(ChatMessage message) {
    return copyWith(
      messages: [...messages, message],
      updatedAt: DateTime.now(),
    );
  }
}
