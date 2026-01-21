import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/chat_conversation.dart';
import '../domain/models/chat_message.dart';

/// Repository for AI chat persistence in Supabase
class AiChatRepository {
  AiChatRepository(this._client);

  final SupabaseClient _client;

  /// Get the current user's ID
  String? get _userId => _client.auth.currentUser?.id;

  /// Fetch recent conversations for the current user (without messages for list view)
  Future<List<ChatConversation>> getRecentConversations({int limit = 20}) async {
    if (_userId == null) return [];

    try {
      // Only select needed columns for list display
      final response = await _client
          .from('ai_conversations')
          .select('id, title, created_at, updated_at')
          .eq('user_id', _userId!)
          .isFilter('archived_at', null)
          .order('updated_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((row) => ChatConversation.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch a single conversation with all its messages (single query with JOIN)
  Future<ChatConversation?> getConversation(String conversationId) async {
    try {
      // Use nested select to fetch conversation and messages in one query
      final response = await _client
          .from('ai_conversations')
          .select('*, ai_chat_messages(*)')
          .eq('id', conversationId)
          .maybeSingle();

      if (response == null) return null;

      // Extract messages from the nested response
      final messagesData = response['ai_chat_messages'] as List? ?? [];
      final messages = messagesData
          .map((row) => ChatMessage.fromJson(row as Map<String, dynamic>))
          .toList();

      // Sort messages by created_at since Supabase nested selects don't support ordering
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return ChatConversation.fromJson(
        response,
        messages: messages,
      );
    } catch (e) {
      return null;
    }
  }

  /// Create a new conversation
  Future<ChatConversation?> createConversation({String? title, String? orgId}) async {
    if (_userId == null) return null;

    try {
      final response = await _client
          .from('ai_conversations')
          .insert({
            'user_id': _userId,
            if (orgId != null) 'org_id': orgId,
            if (title != null) 'title': title,
          })
          .select()
          .single();

      return ChatConversation.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Add a message to a conversation
  Future<ChatMessage?> addMessage({
    required String conversationId,
    required ChatRole role,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _client
          .from('ai_chat_messages')
          .insert({
            'conversation_id': conversationId,
            'role': role.name,
            'content': content,
            if (metadata != null) 'metadata': metadata,
          })
          .select()
          .single();

      return ChatMessage.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Update conversation title
  Future<bool> updateConversationTitle(String conversationId, String title) async {
    try {
      await _client
          .from('ai_conversations')
          .update({'title': title})
          .eq('id', conversationId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Archive a conversation
  Future<bool> archiveConversation(String conversationId) async {
    try {
      await _client
          .from('ai_conversations')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', conversationId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a conversation and all its messages
  Future<bool> deleteConversation(String conversationId) async {
    try {
      await _client
          .from('ai_conversations')
          .delete()
          .eq('id', conversationId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete all conversations for the current user
  Future<bool> deleteAllConversations() async {
    if (_userId == null) return false;

    try {
      await _client
          .from('ai_conversations')
          .delete()
          .eq('user_id', _userId!);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get the most recent conversation with messages (single query with JOIN)
  Future<ChatConversation?> getMostRecentConversation() async {
    if (_userId == null) return null;

    try {
      // Single query to get conversation AND messages
      final response = await _client
          .from('ai_conversations')
          .select('*, ai_chat_messages(*)')
          .eq('user_id', _userId!)
          .isFilter('archived_at', null)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      // Extract messages from the nested response
      final messagesData = response['ai_chat_messages'] as List? ?? [];
      final messages = messagesData
          .map((row) => ChatMessage.fromJson(row as Map<String, dynamic>))
          .toList();

      // Sort messages by created_at
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return ChatConversation.fromJson(
        response,
        messages: messages,
      );
    } catch (e) {
      return null;
    }
  }
}
