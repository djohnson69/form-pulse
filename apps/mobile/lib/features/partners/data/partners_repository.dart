import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:shared/shared.dart';

import 'message_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageThreadPreview {
  MessageThreadPreview({
    required this.thread,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSender,
    this.targetName,
    this.messageCount = 0,
    this.participantCount = 0,
    this.unreadCount = 0,
    this.participants = const [],
    this.currentParticipant,
  });

  final MessageThread thread;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSender;
  final String? targetName;
  final int messageCount;
  final int participantCount;
  final int unreadCount;
  final List<MessageParticipantEntry> participants;
  final MessageParticipantEntry? currentParticipant;
}

abstract class PartnersRepositoryBase {
  Future<List<Client>> fetchClients();
  Future<Client> createClient(Client client);
  Future<Client> updateClient(Client client);

  Future<List<Vendor>> fetchVendors();
  Future<Vendor> createVendor(Vendor vendor);
  Future<Vendor> updateVendor(Vendor vendor);

  Future<List<MessageThreadPreview>> fetchThreadPreviews();
  Future<ThreadMessagesBundle> fetchThreadDetails(String threadId);
  Future<List<Message>> fetchMessages(String threadId);
  Future<List<MessageParticipantEntry>> fetchThreadParticipants(String threadId);
  Future<MessageThread> createThread({
    required String title,
    String? clientId,
    String? vendorId,
    String? threadType,
    List<String>? participantUserIds,
  });
  Future<Message> sendMessage({
    String? messageId,
    required String threadId,
    required String body,
    List<Map<String, dynamic>> attachments = const [],
    Map<String, dynamic>? metadata,
    String? replyToMessageId,
  });
  Future<Message> updateMessage({
    required String messageId,
    required String body,
    Map<String, dynamic>? metadata,
  });
  Future<void> deleteMessage({required String messageId});
  Future<void> deleteMessageForMe({
    required String messageId,
    required String threadId,
  });
  Future<void> deleteMessageForAll({
    required String messageId,
    required String threadId,
  });
  Future<void> updateMessageMetadata({
    required String messageId,
    required Map<String, dynamic> updates,
  });
  Future<bool> isThreadMuted({required String threadId});
  Future<void> setThreadMuted({
    required String threadId,
    required bool muted,
  });
  Future<void> updateThreadNotificationSettings({
    required String threadId,
    required String level,
    DateTime? muteUntil,
  });
  Future<void> setThreadArchived({
    required String threadId,
    required bool archived,
  });
  Future<void> addThreadParticipants({
    required String threadId,
    required List<String> userIds,
  });
  Future<void> removeThreadParticipant({
    required String threadId,
    required String userId,
  });
  Future<void> leaveThread({required String threadId});
  Future<void> markThreadDelivered({required String threadId});
  Future<void> markThreadRead({required String threadId});
  Future<void> updateTypingStatus({
    required String threadId,
    required bool isTyping,
  });
  Future<List<MessageReactionEntry>> fetchThreadReactions(String threadId);
  Future<void> toggleReaction({
    required String threadId,
    required String messageId,
    required String emoji,
  });
  Future<List<MessageAttachmentEntry>> uploadMessageAttachments({
    required String threadId,
    required String messageId,
    required List<MessageUploadAttachment> attachments,
  });
  Future<List<ThreadSearchResult>> searchMessages({
    required String query,
    String? threadId,
  });
}

class SupabasePartnersRepository implements PartnersRepositoryBase {
  SupabasePartnersRepository(this._client);

  final SupabaseClient _client;
  static const _bucketName =
      String.fromEnvironment('SUPABASE_BUCKET', defaultValue: 'formbridge-attachments');

  @override
  Future<List<Client>> fetchClients() async {
    try {
      final orgId = await _getOrgId();
      if (orgId == null) return const [];
      final rows = await _client
          .from('clients')
          .select()
          .eq('org_id', orgId)
          .order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map((row) => _mapClient(Map<String, dynamic>.from(row as Map)))
          .toList();
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase fetchClients failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Client> createClient(Client client) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization.');
    }
    final payload = _toClientPayload(client, orgId);
    try {
      final res = await _client.from('clients').insert(payload).select().single();
      return _mapClient(Map<String, dynamic>.from(res as Map));
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase createClient failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Client> updateClient(Client client) async {
    final payload = _toClientPayload(client, null);
    try {
      final res = await _client
          .from('clients')
          .update(payload)
          .eq('id', client.id)
          .select()
          .single();
      return _mapClient(Map<String, dynamic>.from(res as Map));
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase updateClient failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<Vendor>> fetchVendors() async {
    try {
      final orgId = await _getOrgId();
      if (orgId == null) return const [];
      final rows = await _client
          .from('vendors')
          .select()
          .eq('org_id', orgId)
          .order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map((row) => _mapVendor(Map<String, dynamic>.from(row as Map)))
          .toList();
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase fetchVendors failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Vendor> createVendor(Vendor vendor) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization.');
    }
    final payload = _toVendorPayload(vendor, orgId);
    try {
      final res = await _client.from('vendors').insert(payload).select().single();
      return _mapVendor(Map<String, dynamic>.from(res as Map));
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase createVendor failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Vendor> updateVendor(Vendor vendor) async {
    final payload = _toVendorPayload(vendor, null);
    try {
      final res = await _client
          .from('vendors')
          .update(payload)
          .eq('id', vendor.id)
          .select()
          .single();
      return _mapVendor(Map<String, dynamic>.from(res as Map));
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase updateVendor failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<MessageThreadPreview>> fetchThreadPreviews() async {
    try {
      final orgId = await _getOrgId();
      if (orgId == null) return const [];
      final userId = _client.auth.currentUser?.id;
      final threads = await _client
          .from('message_threads')
          .select()
          .eq('org_id', orgId)
          .order('updated_at', ascending: false);
      final mappedThreads = (threads as List<dynamic>)
          .map((row) => _mapThread(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (mappedThreads.isEmpty) return const [];

      final clients = await fetchClients();
      final vendors = await fetchVendors();
      final clientIndex = {
        for (final client in clients) client.id: client.companyName
      };
      final vendorIndex = {
        for (final vendor in vendors) vendor.id: vendor.companyName
      };

      final threadIds = mappedThreads.map((t) => t.id).toList();
      final messages = await _client
          .from('messages')
          .select('id, thread_id, body, created_at, sender_name, sender_id, deleted_at')
          .inFilter('thread_id', threadIds)
          .order('created_at', ascending: false);
      final participantsRows = await _client
          .from('message_participants')
          .select(
              'id, thread_id, user_id, client_id, vendor_id, display_name, role, '
              'is_active, last_read_at, last_delivered_at, notification_level, '
              'mute_until, is_archived, left_at, metadata')
          .inFilter('thread_id', threadIds);

      final participantsByThread = <String, List<MessageParticipantEntry>>{};
      final currentParticipantByThread = <String, MessageParticipantEntry?>{};
      for (final row in (participantsRows as List<dynamic>)) {
        final participant = _mapParticipant(Map<String, dynamic>.from(row as Map));
        participantsByThread
            .putIfAbsent(participant.threadId, () => [])
            .add(participant);
        if (userId != null && participant.userId == userId) {
          currentParticipantByThread[participant.threadId] = participant;
        }
      }

      final deletedByThread = <String, Set<String>>{};
      if (userId != null) {
        final deletions = await _client
            .from('message_deletions')
            .select('thread_id, message_id')
            .eq('user_id', userId)
            .inFilter('thread_id', threadIds);
        for (final row in (deletions as List<dynamic>)) {
          final map = Map<String, dynamic>.from(row as Map);
          final threadId = map['thread_id']?.toString() ?? '';
          final messageId = map['message_id']?.toString() ?? '';
          if (threadId.isEmpty || messageId.isEmpty) continue;
          deletedByThread
              .putIfAbsent(threadId, () => <String>{})
              .add(messageId);
        }
      }

      final lastMessageByThread = <String, Map<String, dynamic>>{};
      final messageCounts = <String, int>{};
      final unreadCounts = <String, int>{};
      for (final row in (messages as List<dynamic>)) {
        final map = Map<String, dynamic>.from(row as Map);
        final threadId = map['thread_id']?.toString() ?? '';
        final messageId = map['id']?.toString() ?? '';
        if (threadId.isEmpty) continue;
        final deletedIds = deletedByThread[threadId];
        if (messageId.isNotEmpty && deletedIds != null && deletedIds.contains(messageId)) {
          continue;
        }
        final deletedAt = map['deleted_at'];
        if (deletedAt == null) {
          messageCounts[threadId] = (messageCounts[threadId] ?? 0) + 1;
        }
        if (!lastMessageByThread.containsKey(threadId) && deletedAt == null) {
          lastMessageByThread[threadId] = map;
        }
        final senderId = map['sender_id']?.toString();
        if (userId != null && senderId != userId && deletedAt == null) {
          final createdAt = _parseNullableDate(map['created_at']);
          final lastReadAt = currentParticipantByThread[threadId]?.lastReadAt;
          if (createdAt != null && (lastReadAt == null || createdAt.isAfter(lastReadAt))) {
            unreadCounts[threadId] = (unreadCounts[threadId] ?? 0) + 1;
          }
        }
      }
      final participantCounts = <String, int>{};
      for (final entry in participantsByThread.entries) {
        participantCounts[entry.key] =
            entry.value.where((participant) => participant.isActive).length;
      }

      return mappedThreads.map((thread) {
        final last = lastMessageByThread[thread.id];
        final targetName = thread.clientId != null
            ? clientIndex[thread.clientId]
            : thread.vendorId != null
                ? vendorIndex[thread.vendorId]
                : null;
        return MessageThreadPreview(
          thread: thread,
          lastMessage: last?['body'] as String?,
          lastMessageAt: _parseNullableDate(last?['created_at']),
          lastSender: last?['sender_name'] as String?,
          targetName: targetName,
          messageCount: messageCounts[thread.id] ?? 0,
          participantCount: participantCounts[thread.id] ?? 0,
          unreadCount: unreadCounts[thread.id] ?? 0,
          participants: participantsByThread[thread.id] ?? const [],
          currentParticipant: currentParticipantByThread[thread.id],
        );
      }).toList();
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase fetchThreadPreviews failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<ThreadMessagesBundle> fetchThreadDetails(String threadId) async {
    try {
      final threadRow = await _client
          .from('message_threads')
          .select()
          .eq('id', threadId)
          .single();
      final thread = _mapThread(Map<String, dynamic>.from(threadRow as Map));
      final participants = await fetchThreadParticipants(threadId);
      final currentUserId = _client.auth.currentUser?.id;
      final currentParticipant = currentUserId == null
          ? null
          : participants.cast<MessageParticipantEntry?>().firstWhere(
                (entry) => entry?.userId == currentUserId,
                orElse: () => null,
              );
      final deletedMessageIds =
          await _fetchDeletedMessageIds(threadId: threadId);
      final rows = await _client
          .from('messages')
          .select()
          .eq('thread_id', threadId)
          .order('created_at', ascending: true);
      final messages = (rows as List<dynamic>)
          .map((row) => _mapMessage(Map<String, dynamic>.from(row as Map)))
          .where((message) => !deletedMessageIds.contains(message.id))
          .toList();
      final reactions = await fetchThreadReactions(threadId);
      final reactionsByMessage = <String, List<MessageReactionEntry>>{};
      for (final reaction in reactions) {
        reactionsByMessage
            .putIfAbsent(reaction.messageId, () => [])
            .add(reaction);
      }
      return ThreadMessagesBundle(
        thread: thread,
        messages: messages,
        participants: participants,
        reactions: reactionsByMessage,
        deletedMessageIds: deletedMessageIds,
        currentParticipant: currentParticipant,
      );
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase fetchThreadDetails failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<Message>> fetchMessages(String threadId) async {
    final bundle = await fetchThreadDetails(threadId);
    return bundle.messages;
  }

  @override
  Future<List<MessageParticipantEntry>> fetchThreadParticipants(
    String threadId,
  ) async {
    try {
      final rows = await _client
          .from('message_participants')
          .select()
          .eq('thread_id', threadId)
          .order('created_at');
      return (rows as List<dynamic>)
          .map((row) => _mapParticipant(Map<String, dynamic>.from(row as Map)))
          .toList();
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase fetchThreadParticipants failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<MessageThread> createThread({
    required String title,
    String? clientId,
    String? vendorId,
    String? threadType,
    List<String>? participantUserIds,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization.');
    }
    final type = clientId != null
        ? 'client'
        : vendorId != null
            ? 'vendor'
            : threadType ?? 'internal';
    final payload = {
      'org_id': orgId,
      'title': title,
      'type': type,
      'client_id': clientId,
      'vendor_id': vendorId,
      'created_by': _client.auth.currentUser?.id,
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      final res = await _client
          .from('message_threads')
          .insert(payload)
          .select()
          .single();
      final thread = _mapThread(Map<String, dynamic>.from(res as Map));
      await _seedParticipants(
        thread,
        participantUserIds: participantUserIds ?? const [],
      );
      return thread;
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase createThread failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Message> sendMessage({
    String? messageId,
    required String threadId,
    required String body,
    List<Map<String, dynamic>> attachments = const [],
    Map<String, dynamic>? metadata,
    String? replyToMessageId,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization.');
    }
    final sender = await _currentSender();
    final mentions = await _extractMentions(threadId, body);
    final resolvedMetadata = <String, dynamic>{
      ...?metadata,
      if (mentions.isNotEmpty) 'mentions': mentions,
    };
    if (replyToMessageId != null && replyToMessageId.isNotEmpty) {
      final replyPreview = await _buildReplyPreview(replyToMessageId);
      if (replyPreview != null) {
        resolvedMetadata['reply_to'] = replyPreview;
      }
    }
    final payload = {
      if (messageId != null) 'id': messageId,
      'thread_id': threadId,
      'org_id': orgId,
      'sender_id': _client.auth.currentUser?.id,
      'sender_name': sender.name,
      'sender_role': sender.role,
      'body': body,
      'attachments': attachments,
      'metadata': resolvedMetadata,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      final res = await _client.from('messages').insert(payload).select().single();
      await _client
          .from('message_threads')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', threadId);
      final message = _mapMessage(Map<String, dynamic>.from(res as Map));
      await _notifyParticipantsNewMessage(
        threadId: threadId,
        orgId: orgId,
        message: message,
        mentions: mentions,
      );
      return message;
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase sendMessage failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Message> updateMessage({
    required String messageId,
    required String body,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final res = await _client
          .from('messages')
          .select('metadata')
          .eq('id', messageId)
          .maybeSingle();
      final existing = res?['metadata'];
      final merged = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};
      if (metadata != null) {
        merged.addAll(metadata);
      }
      merged['edited'] = true;
      final now = DateTime.now().toIso8601String();
      final updated = await _client
          .from('messages')
          .update({
            'body': body,
            'metadata': merged,
            'edited_at': now,
            'updated_at': now,
          })
          .eq('id', messageId)
          .select()
          .single();
      return _mapMessage(Map<String, dynamic>.from(updated as Map));
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase updateMessage failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteMessage({required String messageId}) async {
    try {
      await deleteMessageForAll(messageId: messageId, threadId: '');
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase deleteMessage failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteMessageForMe({
    required String messageId,
    required String threadId,
  }) async {
    final orgId = await _getOrgId();
    final userId = _client.auth.currentUser?.id;
    if (orgId == null || userId == null) return;
    try {
      await _client.from('message_deletions').upsert({
        'org_id': orgId,
        'thread_id': threadId,
        'message_id': messageId,
        'user_id': userId,
        'deleted_at': DateTime.now().toIso8601String(),
      }, onConflict: 'message_id,user_id');
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase deleteMessageForMe failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteMessageForAll({
    required String messageId,
    required String threadId,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final res = await _client
          .from('messages')
          .select('metadata')
          .eq('id', messageId)
          .maybeSingle();
      final existing = res?['metadata'];
      final metadata = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};
      metadata.addAll({
        'deleted_for_all': true,
        'deleted_at': now,
      });
      await _client.from('messages').update({
        'deleted_at': now,
        'deleted_by': _client.auth.currentUser?.id,
        'metadata': metadata,
        'updated_at': now,
      }).eq('id', messageId);
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase deleteMessageForAll failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateMessageMetadata({
    required String messageId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final res = await _client
          .from('messages')
          .select('metadata')
          .eq('id', messageId)
          .maybeSingle();
      final existing = res?['metadata'];
      final metadata = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};
      metadata.addAll(updates);
      await _client
          .from('messages')
          .update({
            'metadata': metadata,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId);
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase updateMessageMetadata failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<bool> isThreadMuted({required String threadId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final res = await _client
          .from('message_participants')
          .select('metadata, mute_until, notification_level')
          .eq('thread_id', threadId)
          .eq('user_id', userId)
          .maybeSingle();
      final muteUntil = _parseNullableDate(res?['mute_until']);
      if (muteUntil != null && muteUntil.isAfter(DateTime.now())) {
        return true;
      }
      if (res?['notification_level']?.toString() == 'none') {
        return true;
      }
      final metadata = res?['metadata'];
      if (metadata is Map && metadata['muted'] == true) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<void> setThreadMuted({
    required String threadId,
    required bool muted,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await _client
          .from('message_participants')
          .select('id, metadata')
          .eq('thread_id', threadId)
          .eq('user_id', userId)
          .maybeSingle();
      if (res == null) return;
      final existing = res['metadata'];
      final metadata = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};
      metadata['muted'] = muted;
      final updates = {
        'metadata': metadata,
        'notification_level': muted ? 'none' : 'all',
        'mute_until': muted
            ? DateTime.now().add(const Duration(days: 3650)).toIso8601String()
            : null,
      };
      await _client
          .from('message_participants')
          .update(updates)
          .eq('id', res['id']);
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase setThreadMuted failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateThreadNotificationSettings({
    required String threadId,
    required String level,
    DateTime? muteUntil,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from('message_participants')
          .update({
            'notification_level': level,
            'mute_until': muteUntil?.toIso8601String(),
          })
          .eq('thread_id', threadId)
          .eq('user_id', userId);
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase updateThreadNotificationSettings failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> setThreadArchived({
    required String threadId,
    required bool archived,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from('message_participants')
          .update({'is_archived': archived})
          .eq('thread_id', threadId)
          .eq('user_id', userId);
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase setThreadArchived failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> addThreadParticipants({
    required String threadId,
    required List<String> userIds,
  }) async {
    if (userIds.isEmpty) return;
    final orgId = await _getOrgId();
    if (orgId == null) return;
    try {
      final existingRows = await _client
          .from('message_participants')
          .select('user_id')
          .eq('thread_id', threadId)
          .inFilter('user_id', userIds);
      final existingIds = (existingRows as List<dynamic>)
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .toSet();
      final newIds = userIds.where((id) => !existingIds.contains(id)).toList();
      if (newIds.isEmpty) return;
      final profileIndex = await _profilesById(newIds.toSet());
      final participants = newIds.map((userId) {
        final profile = profileIndex[userId];
        return {
          'thread_id': threadId,
          'org_id': orgId,
          'user_id': userId,
          'display_name': _profileDisplayName(profile),
          'role': profile?['role']?.toString() ?? 'member',
          'is_active': true,
        };
      }).toList();
      await _client.from('message_participants').insert(participants);
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase addThreadParticipants failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> removeThreadParticipant({
    required String threadId,
    required String userId,
  }) async {
    try {
      await _client
          .from('message_participants')
          .update({
            'is_active': false,
            'left_at': DateTime.now().toIso8601String(),
          })
          .eq('thread_id', threadId)
          .eq('user_id', userId);
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase removeThreadParticipant failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> leaveThread({required String threadId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await removeThreadParticipant(threadId: threadId, userId: userId);
  }

  @override
  Future<void> markThreadDelivered({required String threadId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from('message_participants')
          .update({
            'last_delivered_at': DateTime.now().toIso8601String(),
          })
          .eq('thread_id', threadId)
          .eq('user_id', userId);
    } catch (_) {}
  }

  @override
  Future<void> markThreadRead({required String threadId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final now = DateTime.now().toIso8601String();
      await _client
          .from('message_participants')
          .update({
            'last_read_at': now,
            'last_delivered_at': now,
          })
          .eq('thread_id', threadId)
          .eq('user_id', userId);
    } catch (_) {}
  }

  @override
  Future<void> updateTypingStatus({
    required String threadId,
    required bool isTyping,
  }) async {
    final orgId = await _getOrgId();
    final userId = _client.auth.currentUser?.id;
    if (orgId == null || userId == null) return;
    try {
      await _client.from('message_typing').upsert({
        'org_id': orgId,
        'thread_id': threadId,
        'user_id': userId,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'thread_id,user_id');
    } catch (_) {}
  }

  @override
  Future<List<MessageReactionEntry>> fetchThreadReactions(String threadId) async {
    try {
      final rows = await _client
          .from('message_reactions')
          .select()
          .eq('thread_id', threadId)
          .order('created_at');
      return (rows as List<dynamic>)
          .map((row) => _mapReaction(Map<String, dynamic>.from(row as Map)))
          .toList();
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase fetchThreadReactions failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> toggleReaction({
    required String threadId,
    required String messageId,
    required String emoji,
  }) async {
    final orgId = await _getOrgId();
    final userId = _client.auth.currentUser?.id;
    if (orgId == null || userId == null) return;
    try {
      final existing = await _client
          .from('message_reactions')
          .select('id')
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji)
          .maybeSingle();
      if (existing != null) {
        await _client.from('message_reactions').delete().eq('id', existing['id']);
      } else {
        await _client.from('message_reactions').insert({
          'org_id': orgId,
          'thread_id': threadId,
          'message_id': messageId,
          'user_id': userId,
          'emoji': emoji,
        });
      }
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase toggleReaction failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<MessageAttachmentEntry>> uploadMessageAttachments({
    required String threadId,
    required String messageId,
    required List<MessageUploadAttachment> attachments,
  }) async {
    if (attachments.isEmpty) return const [];
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final prefix = orgId.isNotEmpty ? 'org-$orgId' : 'public';
    final uploaded = <MessageAttachmentEntry>[];
    for (final attachment in attachments) {
      final safeName = attachment.name.replaceAll(' ', '_');
      final path =
          '$prefix/messages/$threadId/$messageId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
      await _client.storage.from(_bucketName).uploadBinary(
            path,
            Uint8List.fromList(attachment.bytes),
            fileOptions: FileOptions(
              upsert: true,
              contentType: attachment.contentType,
            ),
          );
      uploaded.add(
        MessageAttachmentEntry(
          name: attachment.name,
          bucket: _bucketName,
          path: path,
          contentType: attachment.contentType,
          size: attachment.size,
          isImage: attachment.isImage,
        ),
      );
    }
    return uploaded;
  }

  @override
  Future<List<ThreadSearchResult>> searchMessages({
    required String query,
    String? threadId,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      var request = _client
          .from('messages')
          .select('id, thread_id, body')
          .eq('org_id', orgId)
          .ilike('body', '%$trimmed%');
      if (threadId != null) {
        request = request.eq('thread_id', threadId);
      }
      final rows =
          await request.order('created_at', ascending: false).limit(50);
      return (rows as List<dynamic>).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final body = map['body']?.toString() ?? '';
        final preview = body.length > 120 ? body.substring(0, 120) : body;
        return ThreadSearchResult(
          threadId: map['thread_id']?.toString() ?? '',
          messageId: map['id']?.toString() ?? '',
          preview: preview,
        );
      }).toList();
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase searchMessages failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> _seedParticipants(
    MessageThread thread, {
    List<String> participantUserIds = const [],
  }) async {
    final orgId = thread.orgId;
    final userId = _client.auth.currentUser?.id;
    final sender = await _currentSender();
    if (userId == null) return;
    final extraUserIds = {...participantUserIds}..remove(userId);
    final profileIndex = await _profilesById(extraUserIds);
    final participants = <Map<String, dynamic>>[
      {
        'thread_id': thread.id,
        'org_id': orgId,
        'user_id': userId,
        'display_name': sender.name,
        'role': sender.role ?? 'member',
      },
    ];
    for (final participantId in extraUserIds) {
      final profile = profileIndex[participantId];
      participants.add({
        'thread_id': thread.id,
        'org_id': orgId,
        'user_id': participantId,
        'display_name': _profileDisplayName(profile),
        'role': profile?['role']?.toString() ?? 'member',
      });
    }
    if (thread.clientId != null) {
      final clientName = await _clientName(thread.clientId!);
      participants.add({
        'thread_id': thread.id,
        'org_id': orgId,
        'client_id': thread.clientId,
        'display_name': clientName ?? 'Client',
        'role': 'client',
      });
    }
    if (thread.vendorId != null) {
      final vendorName = await _vendorName(thread.vendorId!);
      participants.add({
        'thread_id': thread.id,
        'org_id': orgId,
        'vendor_id': thread.vendorId,
        'display_name': vendorName ?? 'Vendor',
        'role': 'vendor',
      });
    }
    try {
      await _client.from('message_participants').insert(participants);
    } catch (_) {}
  }

  MessageParticipantEntry _mapParticipant(Map<String, dynamic> row) {
    return MessageParticipantEntry(
      id: row['id']?.toString() ?? '',
      threadId: row['thread_id']?.toString() ?? '',
      userId: row['user_id']?.toString(),
      clientId: row['client_id']?.toString(),
      vendorId: row['vendor_id']?.toString(),
      displayName: row['display_name']?.toString() ?? 'Member',
      role: row['role']?.toString(),
      isActive: row['is_active'] as bool? ?? true,
      lastReadAt: _parseNullableDate(row['last_read_at']),
      lastDeliveredAt: _parseNullableDate(row['last_delivered_at']),
      notificationLevel: row['notification_level']?.toString() ?? 'all',
      muteUntil: _parseNullableDate(row['mute_until']),
      isArchived: row['is_archived'] as bool? ?? false,
      leftAt: _parseNullableDate(row['left_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  MessageReactionEntry _mapReaction(Map<String, dynamic> row) {
    return MessageReactionEntry(
      id: row['id']?.toString() ?? '',
      threadId: row['thread_id']?.toString() ?? '',
      messageId: row['message_id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      emoji: row['emoji']?.toString() ?? '',
      createdAt: _parseDate(row['created_at']),
    );
  }

  Future<Set<String>> _fetchDeletedMessageIds({
    required String threadId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return <String>{};
    try {
      final rows = await _client
          .from('message_deletions')
          .select('message_id')
          .eq('thread_id', threadId)
          .eq('user_id', userId);
      return (rows as List<dynamic>)
          .map((row) => row['message_id']?.toString())
          .whereType<String>()
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<Map<String, dynamic>?> _buildReplyPreview(String messageId) async {
    try {
      final res = await _client
          .from('messages')
          .select('id, body, sender_name, attachments')
          .eq('id', messageId)
          .maybeSingle();
      if (res == null) return null;
      final body = res['body']?.toString() ?? '';
      final preview = body.length > 140 ? body.substring(0, 140) : body;
      final attachments = res['attachments'];
      final attachmentCount = attachments is List ? attachments.length : 0;
      return {
        'id': res['id']?.toString(),
        'sender_name': res['sender_name']?.toString(),
        'body': preview,
        'attachments': attachmentCount,
      };
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _extractMentions(String threadId, String body) async {
    final lowerBody = body.toLowerCase();
    if (!lowerBody.contains('@')) return const [];
    try {
      final participants = await fetchThreadParticipants(threadId);
      final mentions = <String>{};
      for (final participant in participants) {
        final userId = participant.userId;
        if (userId == null || userId.isEmpty) continue;
        final display = participant.displayName.toLowerCase();
        if (display.isEmpty) continue;
        final first = display.split(' ').first;
        if (lowerBody.contains('@$display') || lowerBody.contains('@$first')) {
          mentions.add(userId);
        }
      }
      return mentions.toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _notifyParticipantsNewMessage({
    required String threadId,
    required String orgId,
    required Message message,
    required List<String> mentions,
  }) async {
    final senderId = message.senderId;
    final participants = await fetchThreadParticipants(threadId);
    final threadRow = await _client
        .from('message_threads')
        .select('title')
        .eq('id', threadId)
        .maybeSingle();
    final threadTitle = threadRow?['title']?.toString() ?? 'Message';
    for (final participant in participants) {
      final userId = participant.userId;
      if (userId == null ||
          userId.isEmpty ||
          userId == senderId ||
          !participant.isActive) {
        continue;
      }
      final muteUntil = participant.muteUntil;
      if (muteUntil != null && muteUntil.isAfter(DateTime.now())) {
        continue;
      }
      final level = participant.notificationLevel;
      if (level == 'none') continue;
      if (level == 'mentions' && !mentions.contains(userId)) continue;
      final title = message.senderName != null
          ? '${message.senderName} • $threadTitle'
          : threadTitle;
      try {
        await _client.from('notifications').insert({
          'org_id': orgId,
          'user_id': userId,
          'title': title,
          'body': message.body,
          'type': 'message',
          'data': {
            'threadId': threadId,
            'messageId': message.id,
          },
          'metadata': {
            'threadId': threadId,
            'messageId': message.id,
            if (mentions.isNotEmpty) 'mentions': mentions,
          },
          'created_at': DateTime.now().toIso8601String(),
        });
        await _client.functions.invoke(
          'push',
          body: {
            'orgId': orgId,
            'userId': userId,
            'title': title,
            'body': message.body,
            'data': {
              'type': 'message',
              'threadId': threadId,
              'messageId': message.id,
            },
          },
        );
      } catch (e, st) {
        developer.log(
          'Supabase message notification failed',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<Map<String, Map<String, dynamic>>> _profilesById(
    Set<String> userIds,
  ) async {
    if (userIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('profiles')
          .select('id, first_name, last_name, email, role, last_seen_at')
          .inFilter('id', userIds.toList());
      final profiles = <String, Map<String, dynamic>>{};
      for (final row in (rows as List<dynamic>)) {
        final profile = Map<String, dynamic>.from(row as Map);
        final id = profile['id']?.toString();
        if (id != null) {
          profiles[id] = profile;
        }
      }
      return profiles;
    } catch (_) {
      return {};
    }
  }

  String _profileDisplayName(Map<String, dynamic>? profile) {
    if (profile == null) return 'Member';
    final first = profile['first_name']?.toString() ?? '';
    final last = profile['last_name']?.toString() ?? '';
    final name = [first, last].where((value) => value.isNotEmpty).join(' ');
    if (name.isNotEmpty) return name;
    return profile['email']?.toString() ?? 'Member';
  }

  Future<_SenderInfo> _currentSender() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return _SenderInfo(name: 'Unknown', role: null);
    }
    try {
      final res = await _client
          .from('profiles')
          .select('first_name, last_name, email, role')
          .eq('id', user.id)
          .maybeSingle();
      if (res != null) {
        final first = res['first_name']?.toString() ?? '';
        final last = res['last_name']?.toString() ?? '';
        final name = [first, last].where((v) => v.isNotEmpty).join(' ');
        return _SenderInfo(
          name: name.isNotEmpty
              ? name
              : res['email']?.toString() ?? user.email ?? 'User',
          role: res['role']?.toString(),
        );
      }
    } catch (_) {}
    return _SenderInfo(name: user.email ?? 'User', role: null);
  }

  Future<String?> _clientName(String clientId) async {
    try {
      final res = await _client
          .from('clients')
          .select('company_name')
          .eq('id', clientId)
          .maybeSingle();
      return res?['company_name']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _vendorName(String vendorId) async {
    try {
      final res = await _client
          .from('vendors')
          .select('company_name')
          .eq('id', vendorId)
          .maybeSingle();
      return res?['company_name']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getOrgId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final res = await _client
          .from('org_members')
          .select('org_id')
          .eq('user_id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    try {
      final res = await _client
          .from('profiles')
          .select('org_id')
          .eq('id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    return null;
  }

  Client _mapClient(Map<String, dynamic> row) {
    return Client(
      id: row['id'].toString(),
      companyName: row['company_name'] as String? ??
          row['companyName'] as String? ??
          '',
      contactName:
          row['contact_name'] as String? ?? row['contactName'] as String?,
      email: row['email'] as String?,
      phoneNumber:
          row['phone_number'] as String? ?? row['phoneNumber'] as String?,
      address: row['address'] as String?,
      website: row['website'] as String?,
      assignedJobSites: (row['assigned_job_sites'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      isActive: row['is_active'] as bool? ?? row['isActive'] as bool? ?? true,
      createdAt: _parseDate(row['created_at'] ?? row['createdAt']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  Vendor _mapVendor(Map<String, dynamic> row) {
    return Vendor(
      id: row['id'].toString(),
      companyName: row['company_name'] as String? ??
          row['companyName'] as String? ??
          '',
      contactName:
          row['contact_name'] as String? ?? row['contactName'] as String?,
      email: row['email'] as String?,
      phoneNumber:
          row['phone_number'] as String? ?? row['phoneNumber'] as String?,
      address: row['address'] as String?,
      website: row['website'] as String?,
      serviceCategory:
          row['service_category'] as String? ?? row['serviceCategory'] as String?,
      certifications: (row['certifications'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      isActive: row['is_active'] as bool? ?? row['isActive'] as bool? ?? true,
      createdAt: _parseDate(row['created_at'] ?? row['createdAt']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  MessageThread _mapThread(Map<String, dynamic> row) {
    return MessageThread(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? row['orgId']?.toString() ?? '',
      title: row['title'] as String? ?? '',
      type: row['type'] as String?,
      clientId: row['client_id']?.toString() ?? row['clientId'] as String?,
      vendorId: row['vendor_id']?.toString() ?? row['vendorId'] as String?,
      createdBy: row['created_by']?.toString() ?? row['createdBy'] as String?,
      createdAt: _parseDate(row['created_at'] ?? row['createdAt']),
      updatedAt: _parseNullableDate(row['updated_at'] ?? row['updatedAt']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  Message _mapMessage(Map<String, dynamic> row) {
    return Message(
      id: row['id'].toString(),
      threadId: row['thread_id']?.toString() ?? row['threadId'] as String? ?? '',
      orgId: row['org_id']?.toString() ?? row['orgId'] as String? ?? '',
      senderId: row['sender_id']?.toString() ?? row['senderId'] as String?,
      senderName:
          row['sender_name'] as String? ?? row['senderName'] as String?,
      senderRole:
          row['sender_role'] as String? ?? row['senderRole'] as String?,
      body: row['body'] as String? ?? '',
      attachments: (row['attachments'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      createdAt: _parseDate(row['created_at'] ?? row['createdAt']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> _toClientPayload(Client client, String? orgId) {
    final payload = {
      if (orgId != null) 'org_id': orgId,
      'company_name': client.companyName,
      'contact_name': client.contactName,
      'email': client.email,
      'phone_number': client.phoneNumber,
      'address': client.address,
      'website': client.website,
      'assigned_job_sites': client.assignedJobSites ?? const [],
      'is_active': client.isActive,
      'metadata': client.metadata ?? const {},
    };
    return payload;
  }

  Map<String, dynamic> _toVendorPayload(Vendor vendor, String? orgId) {
    final payload = {
      if (orgId != null) 'org_id': orgId,
      'company_name': vendor.companyName,
      'contact_name': vendor.contactName,
      'email': vendor.email,
      'phone_number': vendor.phoneNumber,
      'address': vendor.address,
      'website': vendor.website,
      'service_category': vendor.serviceCategory,
      'certifications': vendor.certifications ?? const [],
      'is_active': vendor.isActive,
      'metadata': vendor.metadata ?? const {},
    };
    return payload;
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.parse(value.toString());
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

class _SenderInfo {
  _SenderInfo({required this.name, required this.role});

  final String name;
  final String? role;
}
