/// Role of the chat message sender
enum ChatRole {
  user,
  assistant,
  system;

  String get displayName {
    switch (this) {
      case ChatRole.user:
        return 'You';
      case ChatRole.assistant:
        return 'AI Assistant';
      case ChatRole.system:
        return 'System';
    }
  }
}

/// A single chat message in a conversation
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.metadata,
  });

  final String id;
  final String conversationId;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  /// Create a user message
  factory ChatMessage.user({
    required String id,
    required String conversationId,
    required String content,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      role: ChatRole.user,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// Create an assistant message
  factory ChatMessage.assistant({
    required String id,
    required String conversationId,
    required String content,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      role: ChatRole.assistant,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// Create from JSON (Supabase row)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      role: ChatRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => ChatRole.assistant,
      ),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON for Supabase insert
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': role.name,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Convert to JSON for insert (without id, let DB generate)
  Map<String, dynamic> toInsertJson() {
    return {
      'conversation_id': conversationId,
      'role': role.name,
      'content': content,
      if (metadata != null) 'metadata': metadata,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    ChatRole? role,
    String? content,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
