import 'dart:developer' as developer;

import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageThreadPreview {
  MessageThreadPreview({
    required this.thread,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSender,
    this.targetName,
    this.messageCount = 0,
  });

  final MessageThread thread;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSender;
  final String? targetName;
  final int messageCount;
}

abstract class PartnersRepositoryBase {
  Future<List<Client>> fetchClients();
  Future<Client> createClient(Client client);
  Future<Client> updateClient(Client client);

  Future<List<Vendor>> fetchVendors();
  Future<Vendor> createVendor(Vendor vendor);
  Future<Vendor> updateVendor(Vendor vendor);

  Future<List<MessageThreadPreview>> fetchThreadPreviews();
  Future<List<Message>> fetchMessages(String threadId);
  Future<MessageThread> createThread({
    required String title,
    String? clientId,
    String? vendorId,
  });
  Future<Message> sendMessage({
    required String threadId,
    required String body,
  });
}

class SupabasePartnersRepository implements PartnersRepositoryBase {
  SupabasePartnersRepository(this._client);

  final SupabaseClient _client;

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
          .select('thread_id, body, created_at, sender_name')
          .inFilter('thread_id', threadIds)
          .order('created_at', ascending: false);

      final lastMessageByThread = <String, Map<String, dynamic>>{};
      final messageCounts = <String, int>{};
      for (final row in (messages as List<dynamic>)) {
        final map = Map<String, dynamic>.from(row as Map);
        final threadId = map['thread_id']?.toString() ?? '';
        if (threadId.isEmpty) continue;
        messageCounts[threadId] = (messageCounts[threadId] ?? 0) + 1;
        if (!lastMessageByThread.containsKey(threadId)) {
          lastMessageByThread[threadId] = map;
        }
      }

      return mappedThreads.map((thread) {
        final last = lastMessageByThread[thread.id];
        final targetName = thread.clientId != null
            ? clientIndex[thread.clientId]
            : thread.vendorId != null
                ? vendorIndex[thread.vendorId]
                : 'Internal';
        return MessageThreadPreview(
          thread: thread,
          lastMessage: last?['body'] as String?,
          lastMessageAt: _parseNullableDate(last?['created_at']),
          lastSender: last?['sender_name'] as String?,
          targetName: targetName,
          messageCount: messageCounts[thread.id] ?? 0,
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
  Future<List<Message>> fetchMessages(String threadId) async {
    try {
      final rows = await _client
          .from('messages')
          .select()
          .eq('thread_id', threadId)
          .order('created_at', ascending: true);
      return (rows as List<dynamic>)
          .map((row) => _mapMessage(Map<String, dynamic>.from(row as Map)))
          .toList();
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase fetchMessages failed: ${e.message} (code: ${e.code})',
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
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization.');
    }
    final type = clientId != null
        ? 'client'
        : vendorId != null
            ? 'vendor'
            : 'internal';
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
      await _seedParticipants(thread);
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
    required String threadId,
    required String body,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization.');
    }
    final sender = await _currentSender();
    final payload = {
      'thread_id': threadId,
      'org_id': orgId,
      'sender_id': _client.auth.currentUser?.id,
      'sender_name': sender.name,
      'sender_role': sender.role,
      'body': body,
      'attachments': const [],
    };
    try {
      final res = await _client.from('messages').insert(payload).select().single();
      await _client
          .from('message_threads')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', threadId);
      return _mapMessage(Map<String, dynamic>.from(res as Map));
    } on PostgrestException catch (e, st) {
      developer.log(
        'Supabase sendMessage failed: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> _seedParticipants(MessageThread thread) async {
    final orgId = thread.orgId;
    final userId = _client.auth.currentUser?.id;
    final sender = await _currentSender();
    if (userId == null) return;
    final participants = <Map<String, dynamic>>[
      {
        'thread_id': thread.id,
        'org_id': orgId,
        'user_id': userId,
        'display_name': sender.name,
        'role': sender.role ?? 'member',
      },
    ];
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
