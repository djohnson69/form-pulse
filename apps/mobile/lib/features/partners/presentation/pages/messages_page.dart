import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../data/partners_provider.dart';
import '../../data/partners_repository.dart';
import '../../data/message_models.dart';
import '../../../training/data/training_provider.dart';
import '../../../../core/utils/storage_utils.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({
    super.key,
    this.initialThreadId,
    this.showOnlyThread = false,
  });

  final String? initialThreadId;
  final bool showOnlyThread;

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _threadSearchController = TextEditingController();
  bool _showConversations = true;
  String? _selectedId;
  bool _sending = false;
  RealtimeChannel? _threadsChannel;
  Timer? _typingDebounce;
  Timer? _presenceTimer;
  final Map<String, DateTime> _typingUsers = {};
  final Map<String, DateTime?> _lastSeenByUserId = {};
  final List<MessageUploadAttachment> _pendingAttachments = [];
  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();
  final Map<String, bool> _mutedThreads = {};
  Message? _replyToMessage;
  Message? _editingMessage;
  bool _showMessageSearch = false;
  _MessageFilter _messageFilter = _MessageFilter.all;

  @override
  void initState() {
    super.initState();
    _subscribeToThreadChanges();
    _startPresenceHeartbeat();
    final initialId = widget.initialThreadId;
    if (initialId != null) {
      _selectedId = initialId;
      _showConversations = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadThreadMuteStatus(initialId);
        final repo = ref.read(partnersRepositoryProvider);
        repo.markThreadDelivered(threadId: initialId);
        repo.markThreadRead(threadId: initialId);
      });
    }
  }

  @override
  void dispose() {
    _threadsChannel?.unsubscribe();
    _typingDebounce?.cancel();
    _presenceTimer?.cancel();
    _searchController.dispose();
    _messageController.dispose();
    _threadSearchController.dispose();
    super.dispose();
  }

  void _subscribeToThreadChanges() {
    final client = Supabase.instance.client;
    _threadsChannel = client.channel('message-threads')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'message_threads',
        callback: (_) {
          if (!mounted) return;
          ref.invalidate(messageThreadsProvider);
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          if (!mounted) return;
          ref.invalidate(messageThreadsProvider);
          final selectedId = _selectedId;
          if (selectedId != null) {
            ref.invalidate(threadMessagesProvider(selectedId));
            final threadId = payload.newRecord['thread_id']?.toString() ??
                payload.oldRecord['thread_id']?.toString();
            if (threadId == selectedId) {
              final repo = ref.read(partnersRepositoryProvider);
              repo.markThreadDelivered(threadId: selectedId);
              repo.markThreadRead(threadId: selectedId);
            }
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'message_typing',
        callback: (payload) {
          if (!mounted) return;
          _handleTypingPayload(payload);
        },
      )
      ..subscribe();
  }

  void _startPresenceHeartbeat() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updatePresence(),
    );
    _updatePresence();
  }

  Future<void> _updatePresence() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'last_seen_at': DateTime.now().toIso8601String()})
          .eq('id', userId);
    } catch (_) {}
  }

  void _handleTypingPayload(PostgresChangePayload payload) {
    final record = payload.newRecord;
    final threadId = record['thread_id']?.toString() ?? '';
    if (threadId.isEmpty || threadId != _selectedId) return;
    final userId = record['user_id']?.toString();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty || userId == currentUserId) return;
    final isTyping = record['is_typing'] == true;
    setState(() {
      if (isTyping) {
        _typingUsers[userId] = DateTime.now();
      } else {
        _typingUsers.remove(userId);
      }
    });
  }

  void _ensurePresenceLoaded(List<MessageThreadPreview> threads) {
    final ids = <String>{};
    for (final thread in threads) {
      for (final participant in thread.participants) {
        if (participant.userId != null && participant.userId!.isNotEmpty) {
          ids.add(participant.userId!);
        }
      }
    }
    final missing = ids.where((id) => !_lastSeenByUserId.containsKey(id)).toList();
    if (missing.isEmpty) return;
    _fetchPresence(missing);
  }

  Future<void> _fetchPresence(List<String> userIds) async {
    if (userIds.isEmpty) return;
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id, last_seen_at')
          .inFilter('id', userIds);
      final updates = <String, DateTime?>{};
      for (final row in (rows as List<dynamic>)) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['id']?.toString();
        if (id == null) continue;
        updates[id] = _parseNullableDate(map['last_seen_at']);
      }
      if (!mounted) return;
      setState(() => _lastSeenByUserId.addAll(updates));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = _MessagingColors.fromTheme(Theme.of(context));
    final threadsAsync = ref.watch(messageThreadsProvider);
    final threads = threadsAsync.asData?.value ?? const <MessageThreadPreview>[];
    if (threads.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensurePresenceLoaded(threads);
      });
    }
    final conversations = threads.map(_mapPreview).toList();
    final filtered = _applySearch(conversations);

    return Scaffold(
      backgroundColor: colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final selected = _findConversation(conversations, _selectedId);
          final showList = !widget.showOnlyThread &&
              (isWide || _showConversations || _selectedId == null);
          final showChat = widget.showOnlyThread
              ? true
              : (isWide || (!_showConversations && selected != null));
          return PopScope(
            canPop: widget.showOnlyThread ||
                isWide ||
                _showConversations ||
                _selectedId == null,
            onPopInvoked: (didPop) {
              if (didPop) return;
              if (widget.showOnlyThread) {
                Navigator.of(context).maybePop();
                return;
              }
              _handleBack();
            },
            child: Row(
              children: [
                if (showList)
                  SizedBox(
                    width: isWide ? 320 : constraints.maxWidth,
                    child: _ConversationPanel(
                      colors: colors,
                      searchController: _searchController,
                      onSearchChanged: (_) => setState(() {}),
                      conversations: filtered,
                      selectedId: _selectedId,
                      onSelect: (id) => _handleSelect(id, isWide: isWide),
                      onCompose: () => _showComposeDialog(isWide: isWide),
                      loading: threadsAsync.isLoading,
                      error: threadsAsync.hasError,
                    ),
                  ),
                if (showChat)
                  Expanded(
                    child: _ChatPanel(
                      colors: colors,
                      conversation: selected,
                      showBack: !isWide,
                      onBack: _handleBack,
                      messageController: _messageController,
                      threadSearchController: _threadSearchController,
                      showSearch: _showMessageSearch,
                      onToggleSearch: () => setState(
                        () => _showMessageSearch = !_showMessageSearch,
                      ),
                      onSearchChanged: (_) => setState(() {}),
                      onSend: _handleSend,
                      sending: _sending,
                      threadAsync: selected != null
                          ? ref.watch(threadMessagesProvider(selected.id))
                          : null,
                      notificationsMuted: selected != null
                          ? (_mutedThreads[selected.id] ??
                              _isMutedSetting(
                                selected.currentParticipant?.notificationLevel ??
                                    'all',
                                selected.currentParticipant?.muteUntil,
                              ))
                          : false,
                      onChatActions: selected == null
                          ? null
                          : () => _showThreadActions(
                                threadId: selected.id,
                                type: selected.type,
                                currentParticipant: selected.currentParticipant,
                              ),
                      onMessageAction: selected == null
                          ? null
                          : (message) => _showMessageActions(
                                message: message,
                                threadId: selected.id,
                              ),
                      messageFilter: _messageFilter,
                      onFilterChanged: (filter) =>
                          setState(() => _messageFilter = filter),
                      typingUsers: _typingUsers,
                      onTypingChanged: (isTyping) =>
                          _handleTypingChanged(isTyping),
                      pendingAttachments: _pendingAttachments,
                      onRemoveAttachment: _removeAttachmentAt,
                      onPickFile: _pickFiles,
                      onPickImage: _pickImages,
                      replyToMessage: _replyToMessage,
                      editingMessage: _editingMessage,
                      onCancelReply: _clearReply,
                      onCancelEdit: _clearEdit,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_ConversationDisplay> _applySearch(
    List<_ConversationDisplay> conversations,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return conversations;
    return conversations
        .where((conv) =>
            conv.name.toLowerCase().contains(query) ||
            conv.lastMessage.toLowerCase().contains(query))
        .toList();
  }

  _ConversationDisplay? _findConversation(
    List<_ConversationDisplay> conversations,
    String? id,
  ) {
    if (id == null) return null;
    for (final conversation in conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  void _handleSelect(String id, {required bool isWide}) {
    setState(() {
      _selectedId = id;
      if (!isWide) _showConversations = false;
    });
    _loadThreadMuteStatus(id);
    ref.read(partnersRepositoryProvider).markThreadDelivered(threadId: id);
    ref.read(partnersRepositoryProvider).markThreadRead(threadId: id);
  }

  void _handleBack() {
    if (widget.showOnlyThread) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _showConversations = true;
      _selectedId = null;
    });
  }

  Future<void> _loadThreadMuteStatus(String threadId) async {
    if (_mutedThreads.containsKey(threadId)) return;
    final repo = ref.read(partnersRepositoryProvider);
    final muted = await repo.isThreadMuted(threadId: threadId);
    if (!mounted) return;
    setState(() => _mutedThreads[threadId] = muted);
  }

  Future<void> _showThreadActions({
    required String threadId,
    required _ConversationType type,
    required MessageParticipantEntry? currentParticipant,
  }) async {
    final notificationLevel = currentParticipant?.notificationLevel ?? 'all';
    final muteUntil = currentParticipant?.muteUntil;
    final isArchived = currentParticipant?.isArchived ?? false;
    final mutedBySettings = _isMutedSetting(notificationLevel, muteUntil);
    final isMuted = _mutedThreads[threadId] ?? mutedBySettings;
    final action = await showModalBottomSheet<_ThreadAction>(
      context: context,
      backgroundColor: _MessagingColors.fromTheme(Theme.of(context)).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isMuted ? Icons.notifications_off : Icons.notifications_active,
                ),
                title: const Text('Notification settings'),
                subtitle:
                    Text(_notificationSummary(notificationLevel, muteUntil)),
                onTap: () =>
                    Navigator.of(context).pop(_ThreadAction.notifications),
              ),
              ListTile(
                leading:
                    Icon(isArchived ? Icons.unarchive : Icons.archive_outlined),
                title: Text(
                  isArchived ? 'Unarchive conversation' : 'Archive conversation',
                ),
                onTap: () => Navigator.of(context).pop(
                  isArchived ? _ThreadAction.unarchive : _ThreadAction.archive,
                ),
              ),
              if (type == _ConversationType.group) ...[
                ListTile(
                  leading: const Icon(Icons.group_add),
                  title: const Text('Manage participants'),
                  onTap: () =>
                      Navigator.of(context).pop(_ThreadAction.manageMembers),
                ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app),
                  title: const Text('Leave group'),
                  onTap: () =>
                      Navigator.of(context).pop(_ThreadAction.leaveGroup),
                ),
              ],
            ],
          ),
        );
      },
    );
    if (action == null) return;
    final repo = ref.read(partnersRepositoryProvider);
    try {
      if (action == _ThreadAction.notifications) {
        await _showNotificationSettingsSheet(
          threadId: threadId,
          currentLevel: notificationLevel,
          muteUntil: muteUntil,
        );
        return;
      }
      if (action == _ThreadAction.archive ||
          action == _ThreadAction.unarchive) {
        await repo.setThreadArchived(
          threadId: threadId,
          archived: action == _ThreadAction.archive,
        );
      } else if (action == _ThreadAction.manageMembers) {
        await _showParticipantManager(threadId: threadId);
        return;
      } else if (action == _ThreadAction.leaveGroup) {
        final confirmed = await _confirmLeaveThread();
        if (confirmed != true) return;
        await repo.leaveThread(threadId: threadId);
        if (!mounted) return;
        setState(() {
          _selectedId = null;
          _showConversations = true;
        });
      }
      ref.invalidate(messageThreadsProvider);
      ref.invalidate(threadMessagesProvider(threadId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == _ThreadAction.archive
                ? 'Conversation archived.'
                : action == _ThreadAction.unarchive
                    ? 'Conversation restored.'
                    : action == _ThreadAction.leaveGroup
                        ? 'You left the group.'
                        : 'Conversation updated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  Future<void> _showNotificationSettingsSheet({
    required String threadId,
    required String currentLevel,
    required DateTime? muteUntil,
  }) async {
    final colors = _MessagingColors.fromTheme(Theme.of(context));
    final now = DateTime.now();
    Future<void> applySetting(String level, DateTime? until) async {
      await ref.read(partnersRepositoryProvider).updateThreadNotificationSettings(
            threadId: threadId,
            level: level,
            muteUntil: until,
          );
      final muted = _isMutedSetting(level, until);
      if (!mounted) return;
      setState(() => _mutedThreads[threadId] = muted);
      ref.invalidate(messageThreadsProvider);
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final mutedBySettings = _isMutedSetting(currentLevel, muteUntil);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Notification settings'),
                subtitle: Text(_notificationSummary(currentLevel, muteUntil)),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active),
                title: const Text('All messages'),
                trailing: (!mutedBySettings && currentLevel == 'all')
                    ? Icon(Icons.check, color: colors.primary)
                    : null,
                onTap: () async {
                  Navigator.of(context).pop();
                  await applySetting('all', null);
                },
              ),
              ListTile(
                leading: const Icon(Icons.alternate_email),
                title: const Text('Mentions only'),
                trailing: (!mutedBySettings && currentLevel == 'mentions')
                    ? Icon(Icons.check, color: colors.primary)
                    : null,
                onTap: () async {
                  Navigator.of(context).pop();
                  await applySetting('mentions', null);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications_off),
                title: const Text('Mute for 1 hour'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await applySetting('none', now.add(const Duration(hours: 1)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off),
                title: const Text('Mute for 8 hours'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await applySetting('none', now.add(const Duration(hours: 8)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off),
                title: const Text('Mute for 24 hours'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await applySetting('none', now.add(const Duration(hours: 24)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off),
                title: const Text('Mute until turned off'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await applySetting(
                    'none',
                    now.add(const Duration(days: 3650)),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showParticipantManager({required String threadId}) async {
    final colors = _MessagingColors.fromTheme(Theme.of(context));
    final selectedToAdd = <String>{};

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Consumer(
              builder: (context, ref, _) {
                final participantsAsync =
                    ref.watch(threadParticipantsProvider(threadId));
                final employeesAsync = ref.watch(employeesProvider);
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Participants',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: colors.title,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        participantsAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (e, _) => Text(
                            'Unable to load participants.',
                            style: TextStyle(color: colors.muted),
                          ),
                          data: (participants) {
                            final currentUserId =
                                Supabase.instance.client.auth.currentUser?.id;
                            final activeParticipants = participants
                                .where((p) => p.isActive)
                                .toList();
                            final activeIds = activeParticipants
                                .map((p) => p.userId)
                                .whereType<String>()
                                .toSet();
                            final availableEmployees = employeesAsync
                                .asData
                                ?.value
                                .where((employee) => employee.isActive)
                                .where((employee) => employee.userId.isNotEmpty)
                                .where((employee) =>
                                    !activeIds.contains(employee.userId))
                                .toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (availableEmployees != null &&
                                    availableEmployees.isNotEmpty) ...[
                                  Text(
                                    'Add people',
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: availableEmployees.map((employee) {
                                      final selected = selectedToAdd
                                          .contains(employee.userId);
                                      return FilterChip(
                                        label: Text(employee.fullName),
                                        selected: selected,
                                        onSelected: (value) {
                                          setState(() {
                                            if (value) {
                                              selectedToAdd
                                                  .add(employee.userId);
                                            } else {
                                              selectedToAdd
                                                  .remove(employee.userId);
                                            }
                                          });
                                        },
                                        selectedColor: colors.primary,
                                        backgroundColor: colors.filterSurface,
                                        labelStyle: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : colors.body,
                                        ),
                                        side: BorderSide(color: colors.border),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton(
                                      onPressed: selectedToAdd.isEmpty
                                          ? null
                                          : () async {
                                              final repo = ref.read(
                                                partnersRepositoryProvider,
                                              );
                                              await repo.addThreadParticipants(
                                                threadId: threadId,
                                                userIds:
                                                    selectedToAdd.toList(),
                                              );
                                              selectedToAdd.clear();
                                              ref.invalidate(
                                                threadParticipantsProvider(
                                                  threadId,
                                                ),
                                              );
                                              ref.invalidate(
                                                threadMessagesProvider(threadId),
                                              );
                                              ref.invalidate(
                                                messageThreadsProvider,
                                              );
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Participants added.',
                                                  ),
                                                ),
                                              );
                                            },
                                      child: const Text('Add'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Text(
                                  'Current members',
                                  style: TextStyle(
                                    color: colors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...activeParticipants.map((participant) {
                                  final isSelf =
                                      participant.userId == currentUserId;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: colors.filterSurface,
                                      child: Text(
                                        _initialsFor(participant.displayName),
                                        style: TextStyle(color: colors.body),
                                      ),
                                    ),
                                    title: Text(participant.displayName),
                                    subtitle: participant.role != null
                                        ? Text(
                                            participant.role!,
                                            style: TextStyle(
                                              color: colors.muted,
                                              fontSize: 12,
                                            ),
                                          )
                                        : null,
                                    trailing: isSelf
                                        ? null
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                            onPressed: () async {
                                              final confirmed =
                                                  await _confirmRemoveParticipant(
                                                participant.displayName,
                                              );
                                              if (confirmed != true) return;
                                              final repo = ref.read(
                                                partnersRepositoryProvider,
                                              );
                                              final userId =
                                                  participant.userId ?? '';
                                              if (userId.isEmpty) return;
                                              await repo.removeThreadParticipant(
                                                threadId: threadId,
                                                userId: userId,
                                              );
                                              ref.invalidate(
                                                threadParticipantsProvider(
                                                  threadId,
                                                ),
                                              );
                                              ref.invalidate(
                                                threadMessagesProvider(threadId),
                                              );
                                              ref.invalidate(
                                                messageThreadsProvider,
                                              );
                                            },
                                          ),
                                  );
                                }).toList(),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Done'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<bool?> _confirmLeaveThread() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Leave group?'),
          content: const Text('You will stop receiving messages from this group.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmRemoveParticipant(String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove participant?'),
          content: Text('Remove $name from this group?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMessageActions({
    required _MessageDisplay message,
    required String threadId,
  }) async {
    final isMine = message.isMine;
    final isDeleted = message.isDeletedForAll;
    final isFlagged = message.isFlagged;
    final isArchived = message.isArchived;
    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      backgroundColor: _MessagingColors.fromTheme(Theme.of(context)).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () => Navigator.of(context).pop(_MessageAction.reply),
              ),
              if (isMine && !isDeleted)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit'),
                  onTap: () => Navigator.of(context).pop(_MessageAction.edit),
                ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: const Text('React'),
                onTap: () => Navigator.of(context).pop(_MessageAction.react),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  isFlagged ? Icons.flag : Icons.flag_outlined,
                ),
                title: Text(isFlagged ? 'Unflag' : 'Flag'),
                onTap: () => Navigator.of(context).pop(
                  isFlagged ? _MessageAction.unflag : _MessageAction.flag,
                ),
              ),
              ListTile(
                leading: Icon(
                  isArchived ? Icons.unarchive : Icons.archive_outlined,
                ),
                title: Text(isArchived ? 'Unarchive' : 'Archive'),
                onTap: () => Navigator.of(context).pop(
                  isArchived
                      ? _MessageAction.unarchive
                      : _MessageAction.archive,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete for me'),
                onTap: () =>
                    Navigator.of(context).pop(_MessageAction.deleteForMe),
              ),
              if (isMine)
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined),
                  title: const Text('Delete for everyone'),
                  onTap: () =>
                      Navigator.of(context).pop(_MessageAction.deleteForAll),
                ),
            ],
          ),
        );
      },
    );
    if (action == null) return;

    final repo = ref.read(partnersRepositoryProvider);
    try {
      if (action == _MessageAction.reply) {
        setState(() {
          _replyToMessage = message.message;
          _editingMessage = null;
        });
        return;
      }
      if (action == _MessageAction.edit) {
        setState(() {
          _editingMessage = message.message;
          _replyToMessage = null;
          _messageController.text = message.message.body;
        });
        return;
      }
      if (action == _MessageAction.react) {
        await _showReactionPicker(
          threadId: threadId,
          messageId: message.message.id,
        );
        return;
      }
      if (action == _MessageAction.deleteForMe) {
        final confirmed = await _confirmDeleteMessage(
          title: 'Delete for me?',
          message: 'This will remove the message from your view.',
        );
        if (confirmed != true) return;
        await repo.deleteMessageForMe(
          messageId: message.message.id,
          threadId: threadId,
        );
      } else if (action == _MessageAction.deleteForAll) {
        final confirmed = await _confirmDeleteMessage(
          title: 'Delete for everyone?',
          message: 'This will remove the message for all participants.',
        );
        if (confirmed != true) return;
        await repo.deleteMessageForAll(
          messageId: message.message.id,
          threadId: threadId,
        );
      } else if (action == _MessageAction.archive) {
        await repo.updateMessageMetadata(
          messageId: message.message.id,
          updates: {'archived': true},
        );
      } else if (action == _MessageAction.unarchive) {
        await repo.updateMessageMetadata(
          messageId: message.message.id,
          updates: {'archived': false},
        );
      } else if (action == _MessageAction.flag) {
        await repo.updateMessageMetadata(
          messageId: message.message.id,
          updates: {'flagged': true},
        );
      } else if (action == _MessageAction.unflag) {
        await repo.updateMessageMetadata(
          messageId: message.message.id,
          updates: {'flagged': false},
        );
      }
      if (!mounted) return;
      ref.invalidate(threadMessagesProvider(threadId));
      ref.invalidate(messageThreadsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_actionSuccessLabel(action)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $e')),
      );
    }
  }

  Future<void> _showReactionPicker({
    required String threadId,
    required String messageId,
  }) async {
    const emojis = ['👍', '❤️', '😂', '😮', '🎉', '👀'];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _MessagingColors.fromTheme(Theme.of(context)).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              children: emojis.map((emoji) {
                return InkWell(
                  onTap: () => Navigator.of(context).pop(emoji),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _MessagingColors.fromTheme(Theme.of(context))
                            .border,
                      ),
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
    if (chosen == null) return;
    await ref.read(partnersRepositoryProvider).toggleReaction(
          threadId: threadId,
          messageId: messageId,
          emoji: chosen,
        );
    ref.invalidate(threadMessagesProvider(threadId));
  }

  String _actionSuccessLabel(_MessageAction action) {
    switch (action) {
      case _MessageAction.archive:
        return 'Message archived.';
      case _MessageAction.unarchive:
        return 'Message restored.';
      case _MessageAction.flag:
        return 'Message flagged.';
      case _MessageAction.unflag:
        return 'Message unflagged.';
      case _MessageAction.deleteForMe:
        return 'Message deleted for you.';
      case _MessageAction.deleteForAll:
        return 'Message deleted for everyone.';
      default:
        return 'Message updated.';
    }
  }

  Future<bool?> _confirmDeleteMessage({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSend() async {
    final id = _selectedId;
    final text = _messageController.text.trim();
    if (id == null || _sending) return;
    if (_editingMessage == null && text.isEmpty && _pendingAttachments.isEmpty) {
      return;
    }
    setState(() => _sending = true);
    try {
      final repo = ref.read(partnersRepositoryProvider);
      if (_editingMessage != null) {
        final editing = _editingMessage!;
        await repo.updateMessage(
          messageId: editing.id,
          body: text,
          metadata: {'edited': true},
        );
        _messageController.clear();
        _clearEdit();
      } else {
        final messageId =
            _pendingAttachments.isNotEmpty ? _uuid.v4() : null;
        final attachments = _pendingAttachments.isNotEmpty && messageId != null
            ? await repo.uploadMessageAttachments(
                threadId: id,
                messageId: messageId,
                attachments: List<MessageUploadAttachment>.from(
                  _pendingAttachments,
                ),
              )
            : const <MessageAttachmentEntry>[];
        await repo.sendMessage(
          messageId: messageId,
          threadId: id,
          body: text,
          attachments: attachments.map((a) => a.toJson()).toList(),
          replyToMessageId: _replyToMessage?.id,
        );
        _messageController.clear();
        setState(() => _pendingAttachments.clear());
        _clearReply();
      }
      _handleTypingChanged(false);
      ref.invalidate(threadMessagesProvider(id));
      ref.invalidate(messageThreadsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _handleTypingChanged(bool isTyping) {
    final threadId = _selectedId;
    if (threadId == null) return;
    final repo = ref.read(partnersRepositoryProvider);
    _typingDebounce?.cancel();
    if (isTyping) {
      repo.updateTypingStatus(threadId: threadId, isTyping: true);
      _typingDebounce = Timer(const Duration(seconds: 3), () {
        repo.updateTypingStatus(threadId: threadId, isTyping: false);
      });
    } else {
      repo.updateTypingStatus(threadId: threadId, isTyping: false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    final files = result.files;
    if (files.isEmpty) return;
    setState(() {
      for (final file in files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final extension = (file.extension ?? '').toLowerCase();
        final contentType = _contentTypeForExtension(extension);
        _pendingAttachments.add(
          MessageUploadAttachment(
            name: file.name,
            bytes: bytes,
            contentType: contentType,
            size: file.size,
            isImage: _isImageExtension(extension),
          ),
        );
      }
    });
  }

  Future<void> _pickImages() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.image,
      );
      if (result == null) return;
      setState(() {
        for (final file in result.files) {
          final bytes = file.bytes;
          if (bytes == null) continue;
          final extension = (file.extension ?? 'png').toLowerCase();
          final contentType = _contentTypeForExtension(extension);
          _pendingAttachments.add(
            MessageUploadAttachment(
              name: file.name,
              bytes: bytes,
              contentType: contentType,
              size: file.size,
              isImage: true,
            ),
          );
        }
      });
      return;
    }
    final images = await _imagePicker.pickMultiImage();
    if (images.isEmpty) return;
    final entries = <MessageUploadAttachment>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      final extension = image.name.split('.').last.toLowerCase();
      entries.add(
        MessageUploadAttachment(
          name: image.name,
          bytes: bytes,
          contentType: _contentTypeForExtension(extension),
          size: bytes.length,
          isImage: true,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _pendingAttachments.addAll(entries));
  }

  void _removeAttachmentAt(int index) {
    if (index < 0 || index >= _pendingAttachments.length) return;
    setState(() => _pendingAttachments.removeAt(index));
  }

  void _clearReply() {
    if (!mounted) return;
    setState(() => _replyToMessage = null);
  }

  void _clearEdit() {
    if (!mounted) return;
    setState(() => _editingMessage = null);
  }

  Future<void> _showComposeDialog({required bool isWide}) async {
    final colors = _MessagingColors.fromTheme(Theme.of(context));
    final titleController = TextEditingController();
    var composeType = _ComposeTarget.direct;
    String? selectedVendorId;
    String? selectedEmployeeId;
    final selectedEmployeeIds = <String>{};
    bool saving = false;

    final thread = await showDialog<MessageThread>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Consumer(
              builder: (context, ref, _) {
                final vendorsAsync = ref.watch(vendorsProvider);
                final vendors = vendorsAsync.asData?.value ?? const <Vendor>[];
                final employeesAsync = ref.watch(employeesProvider);
                final employees = employeesAsync.asData?.value ?? const <Employee>[];
                final currentUserId =
                    Supabase.instance.client.auth.currentUser?.id;
                final selectableEmployees = employees
                    .where((employee) => employee.isActive)
                    .where((employee) => employee.userId.isNotEmpty)
                    .where((employee) => employee.userId != currentUserId)
                    .toList()
                  ..sort((a, b) => a.fullName.compareTo(b.fullName));
                final hasName = titleController.text.trim().isNotEmpty;
                final requiresName = composeType == _ComposeTarget.group;
                final requiresRecipient = composeType == _ComposeTarget.direct ||
                    composeType == _ComposeTarget.group;
                final hasRecipients = composeType == _ComposeTarget.direct
                    ? selectedEmployeeId != null
                    : composeType == _ComposeTarget.group
                        ? selectedEmployeeIds.isNotEmpty
                        : true;
                final requiresVendorSelection =
                    composeType == _ComposeTarget.vendor && vendors.isNotEmpty;
                final canCreate =
                    (!requiresName || hasName) &&
                    (!requiresRecipient || hasRecipients) &&
                    (!requiresVendorSelection || selectedVendorId != null);

                Widget buildTypeChip({
                  required _ComposeTarget type,
                  required String label,
                  required IconData icon,
                }) {
                  final selected = composeType == type;
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        composeType = type;
                        if (composeType != _ComposeTarget.vendor) {
                          selectedVendorId = null;
                        }
                        if (composeType != _ComposeTarget.direct) {
                          selectedEmployeeId = null;
                        }
                        if (composeType != _ComposeTarget.group) {
                          selectedEmployeeIds.clear();
                        }
                      });
                    },
                    avatar: Icon(
                      icon,
                      size: 16,
                      color: selected ? Colors.white : colors.muted,
                    ),
                    label: Text(label),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : colors.body,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    selectedColor: colors.primary,
                    backgroundColor: colors.filterSurface,
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  );
                }

                Widget buildVendorField() {
                  return vendorsAsync.when(
                    loading: () => Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Loading vendors...',
                          style: TextStyle(color: colors.muted),
                        ),
                      ],
                    ),
                    error: (e, _) => Text(
                      'Unable to load vendors.',
                      style: TextStyle(color: colors.muted),
                    ),
                    data: (vendors) {
                      if (vendors.isEmpty) {
                        return Text(
                          'No vendors available.',
                          style: TextStyle(color: colors.muted),
                        );
                      }
                      final availableIds =
                          vendors.map((vendor) => vendor.id).toSet();
                      final dropdownValue = availableIds.contains(
                        selectedVendorId,
                      )
                          ? selectedVendorId
                          : null;
                      return DropdownButtonFormField<String>(
                        value: dropdownValue,
                        items: vendors
                            .map(
                              (vendor) => DropdownMenuItem(
                                value: vendor.id,
                                child: Text(vendor.companyName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedVendorId = value;
                            if (value != null &&
                                titleController.text.trim().isEmpty) {
                              final vendor = vendors.firstWhere(
                                (item) => item.id == value,
                              );
                              titleController.text = vendor.companyName;
                            }
                          });
                        },
                        decoration: _inputDecoration(
                          colors,
                          hintText: 'Select a vendor',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      );
                    },
                  );
                }

                Widget buildRecipientField() {
                  return employeesAsync.when(
                    loading: () => Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Loading team members...',
                          style: TextStyle(color: colors.muted),
                        ),
                      ],
                    ),
                    error: (e, _) => Text(
                      'Unable to load team members.',
                      style: TextStyle(color: colors.muted),
                    ),
                    data: (_) {
                      if (selectableEmployees.isEmpty) {
                        return Text(
                          'No team members available.',
                          style: TextStyle(color: colors.muted),
                        );
                      }
                      if (composeType == _ComposeTarget.direct) {
                        final availableIds = selectableEmployees
                            .map((employee) => employee.userId)
                            .toSet();
                        final dropdownValue = availableIds.contains(
                          selectedEmployeeId,
                        )
                            ? selectedEmployeeId
                            : null;
                        return DropdownButtonFormField<String>(
                          value: dropdownValue,
                          items: selectableEmployees
                              .map(
                                (employee) => DropdownMenuItem(
                                  value: employee.userId,
                                  child: Text(
                                    '${employee.fullName} • ${employee.email}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedEmployeeId = value;
                              if (value != null &&
                                  titleController.text.trim().isEmpty) {
                                final employee = selectableEmployees.firstWhere(
                                  (item) => item.userId == value,
                                );
                                titleController.text = employee.fullName;
                              }
                            });
                          },
                          decoration: _inputDecoration(
                            colors,
                            hintText: 'Select a recipient',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: selectableEmployees.map((employee) {
                          final selected =
                              selectedEmployeeIds.contains(employee.userId);
                          return FilterChip(
                            label: Text(employee.fullName),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  selectedEmployeeIds.add(employee.userId);
                                } else {
                                  selectedEmployeeIds.remove(employee.userId);
                                }
                              });
                            },
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : colors.body,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            selectedColor: colors.primary,
                            backgroundColor: colors.filterSurface,
                            checkmarkColor: Colors.white,
                            side: BorderSide(color: colors.border),
                          );
                        }).toList(),
                      );
                    },
                  );
                }

                return AlertDialog(
                  backgroundColor: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(
                    'New Message',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.title,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requiresName
                              ? 'Group name'
                              : 'Conversation name (optional)',
                          style:
                              TextStyle(color: colors.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: titleController,
                          onChanged: (_) => setState(() {}),
                          decoration: _inputDecoration(
                            colors,
                            hintText: requiresName
                                ? 'Enter a group name'
                                : 'Add a name if you want',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                        if (requiresName) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Group messages require a name.',
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          Text(
                            'Leave this blank to use the recipient name.',
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Type',
                          style:
                              TextStyle(color: colors.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            buildTypeChip(
                              type: _ComposeTarget.direct,
                              label: 'Direct',
                              icon: Icons.person,
                            ),
                            buildTypeChip(
                              type: _ComposeTarget.group,
                              label: 'Group',
                              icon: Icons.group,
                            ),
                            buildTypeChip(
                              type: _ComposeTarget.vendor,
                              label: 'Vendor',
                              icon: Icons.store,
                            ),
                          ],
                        ),
                        if (composeType == _ComposeTarget.direct ||
                            composeType == _ComposeTarget.group) ...[
                          const SizedBox(height: 12),
                          Text(
                            composeType == _ComposeTarget.group
                                ? 'Recipients'
                                : 'Recipient',
                            style:
                                TextStyle(color: colors.muted, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          buildRecipientField(),
                        ],
                        if (composeType == _ComposeTarget.vendor) ...[
                          const SizedBox(height: 12),
                          buildVendorField(),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: (!canCreate || saving)
                          ? null
                          : () async {
                              setState(() => saving = true);
                              final repo =
                                  ref.read(partnersRepositoryProvider);
                              final enteredTitle = titleController.text.trim();
                              final vendorId =
                                  composeType == _ComposeTarget.vendor
                                      ? selectedVendorId
                                      : null;
                              final vendorName = vendorId == null
                                  ? null
                                  : vendors
                                      .firstWhere(
                                        (item) => item.id == vendorId,
                                      )
                                      .companyName;
                              Employee? directRecipient;
                              if (composeType == _ComposeTarget.direct &&
                                  selectedEmployeeId != null) {
                                for (final employee in selectableEmployees) {
                                  if (employee.userId == selectedEmployeeId) {
                                    directRecipient = employee;
                                    break;
                                  }
                                }
                              }
                              final resolvedTitle = enteredTitle.isNotEmpty
                                  ? enteredTitle
                                  : composeType == _ComposeTarget.vendor &&
                                          vendorName != null
                                      ? vendorName
                                      : composeType == _ComposeTarget.direct &&
                                              directRecipient != null
                                          ? directRecipient.fullName
                                      : composeType == _ComposeTarget.group
                                          ? 'Group chat'
                                          : 'Direct message';
                              final participantUserIds =
                                  composeType == _ComposeTarget.direct
                                      ? selectedEmployeeId != null
                                          ? [selectedEmployeeId!]
                                          : const <String>[]
                                      : composeType == _ComposeTarget.group
                                          ? selectedEmployeeIds.toList()
                                          : const <String>[];
                              final threadType =
                                  composeType == _ComposeTarget.group
                                      ? 'group'
                                      : composeType == _ComposeTarget.vendor
                                          ? 'vendor'
                                          : 'direct';
                              try {
                                final created = await repo.createThread(
                                  title: resolvedTitle,
                                  vendorId: vendorId,
                                  threadType:
                                      vendorId == null ? threadType : null,
                                  participantUserIds: participantUserIds,
                                );
                                if (!context.mounted) return;
                                Navigator.of(context).pop(created);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Create failed: ${e.toString()}'),
                                  ),
                                );
                                setState(() => saving = false);
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
    titleController.dispose();
    if (thread == null || !mounted) return;
    ref.invalidate(messageThreadsProvider);
    ref.invalidate(threadMessagesProvider(thread.id));
    _handleSelect(thread.id, isWide: isWide);
  }

  _ConversationDisplay _mapPreview(MessageThreadPreview preview) {
    final name = preview.targetName ?? preview.thread.title;
    final lastMessage = preview.lastMessage ?? 'Start the conversation';
    final timeLabel = preview.lastMessageAt != null
        ? _formatThreadTime(preview.lastMessageAt!)
        : 'Just now';
    final type = _resolveConversationType(preview);
    final members = type == _ConversationType.group &&
            preview.participantCount > 1
        ? preview.participantCount
        : null;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    MessageParticipantEntry? otherParticipant;
    if (type == _ConversationType.direct) {
      for (final participant in preview.participants) {
        if (participant.userId != null &&
            participant.userId != currentUserId &&
            participant.isActive) {
          otherParticipant = participant;
          break;
        }
      }
    }
    final lastSeen = otherParticipant?.userId != null
        ? _lastSeenByUserId[otherParticipant!.userId!]
        : null;
    final online = lastSeen != null &&
        DateTime.now().difference(lastSeen).inMinutes < 2;
    return _ConversationDisplay(
      id: preview.thread.id,
      name: name,
      lastMessage: lastMessage,
      timeLabel: timeLabel,
      unread: preview.unreadCount,
      online: online,
      type: type,
      members: members,
      avatarLabel: _initialsFor(name),
      currentParticipant: preview.currentParticipant,
    );
  }

  _ConversationType _resolveConversationType(MessageThreadPreview preview) {
    final type = preview.thread.type ?? 'internal';
    if (type == 'vendor') return _ConversationType.vendor;
    if (type == 'client' || type == 'direct') return _ConversationType.direct;
    if (type == 'group') return _ConversationType.group;
    final name = preview.thread.title.toLowerCase();
    final groupHints = ['team', 'group', 'project', 'supervisors', 'crew'];
    final isGroup = groupHints.any(name.contains);
    return isGroup ? _ConversationType.group : _ConversationType.direct;
  }
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
    required this.colors,
    required this.searchController,
    required this.onSearchChanged,
    required this.conversations,
    required this.selectedId,
    required this.onSelect,
    required this.onCompose,
    required this.loading,
    required this.error,
  });

  final _MessagingColors colors;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<_ConversationDisplay> conversations;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onCompose;
  final bool loading;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    final hasQuery = searchController.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(color: colors.border),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isWide ? 16 : 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.border),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Messages',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.title,
                          ),
                    ),
                    const Spacer(),
                    if (isWide)
                      FilledButton.icon(
                        onPressed: onCompose,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Message'),
                      )
                    else
                      IconButton(
                        onPressed: onCompose,
                        icon: Icon(Icons.add, color: colors.primary, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.more_vert, color: colors.muted, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isWide ? 16 : 12),
                TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: _inputDecoration(
                    colors,
                    hintText: 'Search conversations...',
                    prefixIcon: Icons.search,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isWide ? 16 : 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (error)
            Padding(
              padding: const EdgeInsets.all(12),
              child: _ErrorBanner(
                colors: colors,
                message: 'Failed to load conversations.',
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : conversations.isEmpty
                    ? _EmptyConversationState(
                        colors: colors,
                        message: hasQuery
                            ? 'No conversations match your search.'
                            : 'No conversations yet.',
                      )
                    : ListView.builder(
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          return _ConversationTile(
                            colors: colors,
                            conversation: conversation,
                            selected: selectedId == conversation.id,
                            isWide: isWide,
                            onTap: () => onSelect(conversation.id),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.colors,
    required this.conversation,
    required this.selected,
    required this.isWide,
    required this.onTap,
  });

  final _MessagingColors colors;
  final _ConversationDisplay conversation;
  final bool selected;
  final bool isWide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarColor = _avatarColor(conversation.type);
    final background = selected ? colors.selected : Colors.transparent;
    final textColor = selected ? colors.title : colors.body;
    final padding = EdgeInsets.symmetric(
      horizontal: isWide ? 16 : 12,
      vertical: isWide ? 16 : 12,
    );

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: padding,
        color: background,
        child: Row(
          children: [
            _ConversationAvatar(
              colors: colors,
              label: conversation.avatarLabel,
              online: conversation.online,
              type: conversation.type,
              background: avatarColor,
              size: isWide ? 48 : 44,
              iconSize: isWide ? 24 : 20,
              textSize: isWide ? 16 : 14,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        conversation.timeLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.muted,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colors.muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            conversation.unread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (conversation.type == _ConversationType.group &&
                      conversation.members != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${conversation.members} members',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.muted,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({
    required this.colors,
    required this.label,
    required this.online,
    required this.type,
    required this.background,
    required this.size,
    required this.iconSize,
    required this.textSize,
  });

  final _MessagingColors colors;
  final String label;
  final bool online;
  final _ConversationType type;
  final Color background;
  final double size;
  final double iconSize;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    final borderColor = colors.isDark ? colors.surface : Colors.white;
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: type == _ConversationType.group
              ? Icon(Icons.group, color: Colors.white, size: iconSize)
              : Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: textSize,
                  ),
                ),
        ),
        if (online && type == _ConversationType.direct)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.colors,
    required this.conversation,
    required this.showBack,
    required this.onBack,
    required this.messageController,
    required this.threadSearchController,
    required this.showSearch,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.onSend,
    required this.sending,
    required this.threadAsync,
    required this.notificationsMuted,
    required this.onChatActions,
    required this.onMessageAction,
    required this.messageFilter,
    required this.onFilterChanged,
    required this.typingUsers,
    required this.onTypingChanged,
    required this.pendingAttachments,
    required this.onRemoveAttachment,
    required this.onPickFile,
    required this.onPickImage,
    required this.replyToMessage,
    required this.editingMessage,
    required this.onCancelReply,
    required this.onCancelEdit,
  });

  final _MessagingColors colors;
  final _ConversationDisplay? conversation;
  final bool showBack;
  final VoidCallback onBack;
  final TextEditingController messageController;
  final TextEditingController threadSearchController;
  final bool showSearch;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSend;
  final bool sending;
  final AsyncValue<ThreadMessagesBundle>? threadAsync;
  final bool notificationsMuted;
  final VoidCallback? onChatActions;
  final ValueChanged<_MessageDisplay>? onMessageAction;
  final _MessageFilter messageFilter;
  final ValueChanged<_MessageFilter> onFilterChanged;
  final Map<String, DateTime> typingUsers;
  final ValueChanged<bool> onTypingChanged;
  final List<MessageUploadAttachment> pendingAttachments;
  final ValueChanged<int> onRemoveAttachment;
  final VoidCallback onPickFile;
  final VoidCallback onPickImage;
  final Message? replyToMessage;
  final Message? editingMessage;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    if (conversation == null) {
      return Container(
        color: colors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 64, color: colors.muted),
              const SizedBox(height: 12),
              Text(
                'Select a conversation to start messaging',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _ChatHeader(
          colors: colors,
          conversation: conversation!,
          showBack: showBack,
          onBack: onBack,
          notificationsMuted: notificationsMuted,
          onChatActions: onChatActions,
          showSearch: showSearch,
          onToggleSearch: onToggleSearch,
        ),
        if (showSearch)
          _ThreadSearchBar(
            colors: colors,
            controller: threadSearchController,
            onChanged: onSearchChanged,
          ),
        Expanded(
          child: _MessageList(
            colors: colors,
            threadAsync: threadAsync,
            onMessageAction: onMessageAction,
            filter: messageFilter,
            onFilterChanged: onFilterChanged,
            searchQuery: threadSearchController.text.trim(),
            typingUsers: typingUsers,
          ),
        ),
        _MessageComposer(
          colors: colors,
          controller: messageController,
          onSend: onSend,
          sending: sending,
          onTypingChanged: onTypingChanged,
          pendingAttachments: pendingAttachments,
          onRemoveAttachment: onRemoveAttachment,
          onPickFile: onPickFile,
          onPickImage: onPickImage,
          replyToMessage: replyToMessage,
          editingMessage: editingMessage,
          onCancelReply: onCancelReply,
          onCancelEdit: onCancelEdit,
        ),
      ],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.colors,
    required this.conversation,
    required this.showBack,
    required this.onBack,
    required this.notificationsMuted,
    required this.onChatActions,
    required this.showSearch,
    required this.onToggleSearch,
  });

  final _MessagingColors colors;
  final _ConversationDisplay conversation;
  final bool showBack;
  final VoidCallback onBack;
  final bool notificationsMuted;
  final VoidCallback? onChatActions;
  final bool showSearch;
  final VoidCallback onToggleSearch;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    final avatarColor = _avatarColor(conversation.type);
    final subtitle = conversation.type == _ConversationType.direct
        ? conversation.online
            ? 'Active now'
            : 'Offline'
        : conversation.members != null
            ? '${conversation.members} members'
            : 'Group chat';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isWide ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              onPressed: onBack,
              icon: Icon(Icons.chevron_left, color: colors.muted, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          _ConversationAvatar(
            colors: colors,
            label: conversation.avatarLabel,
            online: conversation.online,
            type: conversation.type,
            background: avatarColor,
            size: isWide ? 40 : 36,
            iconSize: isWide ? 20 : 18,
            textSize: isWide ? 14 : 13,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        conversation.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.title,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (notificationsMuted) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.notifications_off,
                        size: 14,
                        color: colors.muted,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
          if (conversation.type == _ConversationType.direct) ...[
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.call, color: colors.muted, size: isWide ? 20 : 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon:
                  Icon(Icons.videocam, color: colors.muted, size: isWide ? 20 : 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
          IconButton(
            onPressed: onToggleSearch,
            icon: Icon(
              showSearch ? Icons.search_off : Icons.search,
              color: colors.muted,
              size: isWide ? 20 : 16,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
          IconButton(
            onPressed: onChatActions,
            icon:
                Icon(Icons.more_vert, color: colors.muted, size: isWide ? 20 : 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadSearchBar extends StatelessWidget {
  const _ThreadSearchBar({
    required this.colors,
    required this.controller,
    required this.onChanged,
  });

  final _MessagingColors colors;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: _inputDecoration(
          colors,
          hintText: 'Search this conversation...',
          prefixIcon: Icons.search,
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.colors,
    required this.threadAsync,
    required this.onMessageAction,
    required this.filter,
    required this.onFilterChanged,
    required this.searchQuery,
    required this.typingUsers,
  });

  final _MessagingColors colors;
  final AsyncValue<ThreadMessagesBundle>? threadAsync;
  final ValueChanged<_MessageDisplay>? onMessageAction;
  final _MessageFilter filter;
  final ValueChanged<_MessageFilter> onFilterChanged;
  final String searchQuery;
  final Map<String, DateTime> typingUsers;

  @override
  Widget build(BuildContext context) {
    if (threadAsync == null) {
      return const SizedBox.shrink();
    }
    return threadAsync!.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorBanner(
        colors: colors,
        message: 'Failed to load messages.',
      ),
      data: (bundle) {
        if (bundle.messages.isEmpty) {
          return Center(
            child: Text(
              'Start the conversation with the first message.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.muted),
            ),
          );
        }
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        final filtered = _filterMessages(
          bundle.messages,
          filter,
          searchQuery,
          currentUserId,
          lastReadAt: bundle.currentParticipant?.lastReadAt,
        );
        final displayMessages = filtered.map((message) {
          final isMine = currentUserId != null && message.senderId == currentUserId;
          final sender = message.senderName ?? (isMine ? 'Me' : 'User');
          final avatar = _initialsFor(sender);
          final metadata = message.metadata ?? const <String, dynamic>{};
          final isFlagged = metadata['flagged'] == true;
          final isArchived = metadata['archived'] == true;
          final isDeletedForAll = metadata['deleted_for_all'] == true;
          final isEdited = metadata['edited'] == true || metadata['editedAt'] != null;
          final replyPreview =
              metadata['reply_to'] is Map ? Map<String, dynamic>.from(metadata['reply_to'] as Map) : null;
          final attachments = _parseAttachments(message.attachments);
          final reactions = bundle.reactions[message.id] ?? const [];
          final receipts = _computeReceipts(
            message: message,
            participants: bundle.participants,
            currentUserId: currentUserId,
          );
          return _MessageDisplay(
            message: message,
            sender: sender,
            avatar: avatar,
            content: message.body,
            time: _formatMessageTime(message.createdAt),
            isMine: isMine,
            attachments: attachments,
            isFlagged: isFlagged,
            isArchived: isArchived,
            isDeletedForAll: isDeletedForAll,
            isEdited: isEdited,
            replyPreview: replyPreview,
            reactions: reactions,
            readCount: receipts.readCount,
            deliveredCount: receipts.deliveredCount,
            recipientCount: receipts.recipientCount,
          );
        }).toList();
        final typingLabels = _resolveTypingLabels(
          typingUsers,
          bundle.participants,
          currentUserId,
        );
        return Column(
          children: [
            _MessageFilterBar(
              colors: colors,
              selected: filter,
              onChanged: onFilterChanged,
            ),
            Expanded(
              child: _MessageListBody(
                colors: colors,
                messages: displayMessages,
                onMessageAction: onMessageAction,
              ),
            ),
            if (typingLabels.isNotEmpty)
              _TypingIndicator(
                colors: colors,
                label: typingLabels,
              ),
          ],
        );
      },
    );
  }
}

class _MessageListBody extends StatelessWidget {
  const _MessageListBody({
    required this.colors,
    required this.messages,
    required this.onMessageAction,
  });

  final _MessagingColors colors;
  final List<_MessageDisplay> messages;
  final ValueChanged<_MessageDisplay>? onMessageAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;
        return ListView.builder(
          padding: EdgeInsets.all(isWide ? 16 : 12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return _MessageBubble(
              colors: colors,
              message: messages[index],
              isWide: isWide,
              onMenu: onMessageAction == null
                  ? null
                  : () => onMessageAction!(messages[index]),
            );
          },
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.colors,
    required this.message,
    required this.isWide,
    required this.onMenu,
  });

  final _MessagingColors colors;
  final _MessageDisplay message;
  final bool isWide;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final bubbleColor = isMine ? colors.primary : colors.bubbleOther;
    final textColor = isMine ? Colors.white : colors.bubbleOtherText;
    final attachmentBackground = isMine
        ? Colors.white.withValues(alpha: 0.2)
        : const Color(0xFF4B5563).withValues(alpha: 0.2);
    final attachmentForeground = textColor;
    final smallRadius = const Radius.circular(4);
    final largeRadius = const Radius.circular(16);
    final radius = isMine
        ? BorderRadius.only(
            topLeft: largeRadius,
            topRight: largeRadius,
            bottomLeft: largeRadius,
            bottomRight: smallRadius,
          )
        : BorderRadius.only(
            topLeft: largeRadius,
            topRight: largeRadius,
            bottomLeft: smallRadius,
            bottomRight: largeRadius,
          );
    final padding = EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    );
    final avatarSize = isWide ? 32.0 : 24.0;
    final avatarFontSize = isWide ? 12.0 : 10.0;
    final verticalGap = isWide ? 8.0 : 4.0;
    final timeSize = isWide ? 12.0 : 11.0;
    final textSize = isWide ? 14.0 : 13.0;
    final menuButton = IconButton(
      onPressed: onMenu,
      icon: Icon(Icons.more_horiz, size: 18, color: colors.muted),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 28,
        minHeight: 28,
      ),
      splashRadius: 16,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalGap),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine)
            _BubbleAvatar(
              colors: colors,
              label: message.avatar,
              isMine: false,
              size: avatarSize,
              fontSize: avatarFontSize,
            ),
          if (!isMine) const SizedBox(width: 8),
          if (isMine) menuButton,
          if (isMine) const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: radius,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.replyPreview != null) ...[
                        _ReplyPreview(
                          colors: colors,
                          reply: message.replyPreview!,
                          isMine: isMine,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        message.isDeletedForAll
                            ? 'Message deleted'
                            : message.content,
                        style: TextStyle(
                          color: message.isDeletedForAll
                              ? colors.muted
                              : textColor,
                          fontSize: textSize,
                          fontStyle: message.isDeletedForAll
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                      if (message.attachments.isNotEmpty &&
                          !message.isDeletedForAll) ...[
                        const SizedBox(height: 8),
                        _AttachmentGrid(
                          attachments: message.attachments,
                          isMine: isMine,
                          background: attachmentBackground,
                          foreground: attachmentForeground,
                        ),
                      ],
                    ],
                  ),
                ),
                if (message.reactions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _ReactionRow(
                    colors: colors,
                    reactions: message.reactions,
                    isMine: isMine,
                  ),
                ],
                SizedBox(height: isWide ? 4 : 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.muted,
                            fontSize: timeSize,
                          ),
                    ),
                    if (message.isEdited) ...[
                      const SizedBox(width: 4),
                      Text(
                        'edited',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.muted,
                              fontSize: timeSize,
                            ),
                      ),
                    ],
                    if (isMine && message.recipientCount > 0) ...[
                      const SizedBox(width: 6),
                      _ReceiptIndicator(
                        colors: colors,
                        readCount: message.readCount,
                        deliveredCount: message.deliveredCount,
                        recipientCount: message.recipientCount,
                      ),
                    ],
                    if (message.isFlagged) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.flag, size: 12, color: colors.muted),
                    ],
                    if (message.isArchived) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.archive, size: 12, color: colors.muted),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isMine) ...[
            const SizedBox(width: 4),
            menuButton,
          ],
          if (isMine) const SizedBox(width: 8),
          if (isMine)
            _BubbleAvatar(
              colors: colors,
              label: message.avatar,
              isMine: true,
              size: avatarSize,
              fontSize: avatarFontSize,
            ),
        ],
      ),
    );
  }
}

class _BubbleAvatar extends StatelessWidget {
  const _BubbleAvatar({
    required this.colors,
    required this.label,
    required this.isMine,
    required this.size,
    required this.fontSize,
  });

  final _MessagingColors colors;
  final String label;
  final bool isMine;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isMine ? colors.primary : colors.avatarMuted,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.colors,
    required this.controller,
    required this.onSend,
    required this.sending,
    required this.onTypingChanged,
    required this.pendingAttachments,
    required this.onRemoveAttachment,
    required this.onPickFile,
    required this.onPickImage,
    required this.replyToMessage,
    required this.editingMessage,
    required this.onCancelReply,
    required this.onCancelEdit,
  });

  final _MessagingColors colors;
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final ValueChanged<bool> onTypingChanged;
  final List<MessageUploadAttachment> pendingAttachments;
  final ValueChanged<int> onRemoveAttachment;
  final VoidCallback onPickFile;
  final VoidCallback onPickImage;
  final Message? replyToMessage;
  final Message? editingMessage;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showExtras = constraints.maxWidth >= 768;
        final isWide = constraints.maxWidth >= 768;
        final iconSize = isWide ? 20.0 : 16.0;
        return Container(
          padding: EdgeInsets.all(isWide ? 16 : 12),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyToMessage != null || editingMessage != null)
                _ComposerBanner(
                  colors: colors,
                  title: editingMessage != null ? 'Editing message' : 'Replying to',
                  subtitle: editingMessage?.body ?? replyToMessage?.body ?? '',
                  onClose: editingMessage != null ? onCancelEdit : onCancelReply,
                ),
              if (pendingAttachments.isNotEmpty)
                _AttachmentStrip(
                  colors: colors,
                  attachments: pendingAttachments,
                  onRemove: onRemoveAttachment,
                ),
              Row(
                children: [
                  IconButton(
                    onPressed: onPickFile,
                    icon: Icon(
                      Icons.attach_file,
                      color: colors.muted,
                      size: iconSize,
                    ),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  if (showExtras)
                    IconButton(
                      onPressed: onPickImage,
                      icon: Icon(
                        Icons.image_outlined,
                        color: colors.muted,
                        size: iconSize,
                      ),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: (value) =>
                          onTypingChanged(value.trim().isNotEmpty),
                      onSubmitted: (_) {
                        onTypingChanged(false);
                        onSend();
                      },
                      decoration: _inputDecoration(
                        colors,
                        hintText: 'Type a message...',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isWide ? 16 : 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: FilledButton(
                      onPressed: sending ? null : onSend,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(36, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.send, size: iconSize, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ComposerBanner extends StatelessWidget {
  const _ComposerBanner({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final _MessagingColors colors;
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.filterSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.body),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: colors.muted, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({
    required this.colors,
    required this.attachments,
    required this.onRemove,
  });

  final _MessagingColors colors;
  final List<MessageUploadAttachment> attachments;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: List.generate(attachments.length, (index) {
          final attachment = attachments[index];
          return Chip(
            label: Text(
              attachment.name,
              overflow: TextOverflow.ellipsis,
            ),
            onDeleted: () => onRemove(index),
            deleteIcon: const Icon(Icons.close, size: 16),
            backgroundColor: colors.filterSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: colors.border),
            ),
          );
        }),
      ),
    );
  }
}

class _MessageFilterBar extends StatelessWidget {
  const _MessageFilterBar({
    required this.colors,
    required this.selected,
    required this.onChanged,
  });

  final _MessagingColors colors;
  final _MessageFilter selected;
  final ValueChanged<_MessageFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: _MessageFilter.values.map((filter) {
          final isSelected = selected == filter;
          return ChoiceChip(
            selected: isSelected,
            onSelected: (_) => onChanged(filter),
            label: Text(_filterLabel(filter)),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : colors.body,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            selectedColor: colors.primary,
            backgroundColor: colors.filterSurface,
            side: BorderSide(color: colors.border),
          );
        }).toList(),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({
    required this.colors,
    required this.label,
  });

  final _MessagingColors colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.surface,
      child: Text(
        label,
        style:
            Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.muted),
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.colors,
    required this.reply,
    required this.isMine,
  });

  final _MessagingColors colors;
  final Map<String, dynamic> reply;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final name = reply['sender_name']?.toString() ?? 'Message';
    final body = reply['body']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.15)
            : colors.filterSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isMine ? Colors.white70 : colors.muted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isMine ? Colors.white70 : colors.body,
                ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentGrid extends StatelessWidget {
  const _AttachmentGrid({
    required this.attachments,
    required this.isMine,
    required this.background,
    required this.foreground,
  });

  final List<MessageAttachmentEntry> attachments;
  final bool isMine;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments.map((attachment) {
        return _AttachmentTile(
          attachment: attachment,
          background: background,
          foreground: foreground,
        );
      }).toList(),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.background,
    required this.foreground,
  });

  final MessageAttachmentEntry attachment;
  final Color background;
  final Color foreground;

  Future<String?> _signedUrl() {
    return createSignedStorageUrl(
      client: Supabase.instance.client,
      url: attachment.path,
      defaultBucket: attachment.bucket,
      metadata: {
        'bucket': attachment.bucket,
        'storagePath': attachment.path,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _signedUrl(),
      builder: (context, snapshot) {
        final url = snapshot.data;
        return InkWell(
          onTap: url == null
              ? null
              : () => launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ),
          child: Container(
            width: attachment.isImage ? 140 : 200,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: attachment.isImage && url != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      url,
                      height: 90,
                      width: 140,
                      fit: BoxFit.cover,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insert_drive_file,
                          size: 18, color: foreground),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          attachment.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.colors,
    required this.reactions,
    required this.isMine,
  });

  final _MessagingColors colors;
  final List<MessageReactionEntry> reactions;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final counts = <String, int>{};
    final reacted = <String>{};
    for (final reaction in reactions) {
      counts[reaction.emoji] = (counts[reaction.emoji] ?? 0) + 1;
      if (reaction.userId == currentUserId) {
        reacted.add(reaction.emoji);
      }
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: counts.entries.map((entry) {
        final selected = reacted.contains(entry.key);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.2)
                : colors.filterSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            '${entry.key} ${entry.value}',
            style: TextStyle(
              fontSize: 12,
              color: isMine ? Colors.white : colors.body,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReceiptIndicator extends StatelessWidget {
  const _ReceiptIndicator({
    required this.colors,
    required this.readCount,
    required this.deliveredCount,
    required this.recipientCount,
  });

  final _MessagingColors colors;
  final int readCount;
  final int deliveredCount;
  final int recipientCount;

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;
    Color color;
    if (recipientCount == 0) {
      return const SizedBox.shrink();
    }
    if (readCount >= recipientCount) {
      label = recipientCount > 1 ? 'Seen $readCount' : 'Seen';
      icon = Icons.done_all;
      color = colors.primary;
    } else if (deliveredCount >= recipientCount) {
      label = recipientCount > 1 ? 'Delivered' : 'Delivered';
      icon = Icons.done_all;
      color = colors.muted;
    } else {
      label = 'Sent';
      icon = Icons.check;
      color = colors.muted;
    }
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.muted,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.colors,
    required this.message,
  });

  final _MessagingColors colors;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.filterSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversationState extends StatelessWidget {
  const _EmptyConversationState({
    required this.colors,
    required this.message,
  });

  final _MessagingColors colors;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: colors.muted),
          const SizedBox(height: 12),
          Text(
            message,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}

class _ConversationDisplay {
  const _ConversationDisplay({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.timeLabel,
    required this.unread,
    required this.online,
    required this.type,
    required this.members,
    required this.avatarLabel,
    required this.currentParticipant,
  });

  final String id;
  final String name;
  final String lastMessage;
  final String timeLabel;
  final int unread;
  final bool online;
  final _ConversationType type;
  final int? members;
  final String avatarLabel;
  final MessageParticipantEntry? currentParticipant;

  _ConversationDisplay copyWith({
    String? lastMessage,
    String? timeLabel,
    int? unread,
  }) {
    return _ConversationDisplay(
      id: id,
      name: name,
      lastMessage: lastMessage ?? this.lastMessage,
      timeLabel: timeLabel ?? this.timeLabel,
      unread: unread ?? this.unread,
      online: online,
      type: type,
      members: members,
      avatarLabel: avatarLabel,
      currentParticipant: currentParticipant,
    );
  }
}

class _MessageDisplay {
  const _MessageDisplay({
    required this.message,
    required this.sender,
    required this.avatar,
    required this.content,
    required this.time,
    required this.isMine,
    required this.attachments,
    required this.isFlagged,
    required this.isArchived,
    required this.isDeletedForAll,
    required this.isEdited,
    required this.replyPreview,
    required this.reactions,
    required this.readCount,
    required this.deliveredCount,
    required this.recipientCount,
  });

  final Message message;
  final String sender;
  final String avatar;
  final String content;
  final String time;
  final bool isMine;
  final List<MessageAttachmentEntry> attachments;
  final bool isFlagged;
  final bool isArchived;
  final bool isDeletedForAll;
  final bool isEdited;
  final Map<String, dynamic>? replyPreview;
  final List<MessageReactionEntry> reactions;
  final int readCount;
  final int deliveredCount;
  final int recipientCount;
}

enum _ConversationType { direct, group, vendor }

enum _ComposeTarget { direct, group, vendor }

enum _MessageAction {
  reply,
  edit,
  react,
  deleteForMe,
  deleteForAll,
  archive,
  unarchive,
  flag,
  unflag,
}

enum _ThreadAction {
  notifications,
  archive,
  unarchive,
  manageMembers,
  leaveGroup,
}

enum _MessageFilter { all, unread, flagged, archived }

class _MessagingColors {
  const _MessagingColors({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.border,
    required this.muted,
    required this.body,
    required this.title,
    required this.primary,
    required this.selected,
    required this.filterSurface,
    required this.inputFill,
    required this.inputBorder,
    required this.bubbleOther,
    required this.bubbleOtherText,
    required this.avatarMuted,
  });

  final bool isDark;
  final Color background;
  final Color surface;
  final Color border;
  final Color muted;
  final Color body;
  final Color title;
  final Color primary;
  final Color selected;
  final Color filterSurface;
  final Color inputFill;
  final Color inputBorder;
  final Color bubbleOther;
  final Color bubbleOtherText;
  final Color avatarMuted;

  factory _MessagingColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF2563EB);
    return _MessagingColors(
      isDark: isDark,
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      surface: isDark ? const Color(0xFF1F2937) : Colors.white,
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      muted: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      body: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      title: isDark ? Colors.white : const Color(0xFF111827),
      primary: primary,
      selected:
          isDark ? primary.withValues(alpha: 0.2) : const Color(0xFFEFF6FF),
      filterSurface:
          isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
      inputFill: isDark ? const Color(0xFF111827) : Colors.white,
      inputBorder: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
      bubbleOther: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
      bubbleOtherText:
          isDark ? Colors.white : const Color(0xFF111827),
      avatarMuted:
          isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
    );
  }
}

InputDecoration _inputDecoration(
  _MessagingColors colors, {
  required String hintText,
  IconData? prefixIcon,
  EdgeInsetsGeometry? contentPadding,
  double borderRadius = 8,
  double prefixIconSize = 16,
}) {
  return InputDecoration(
    hintText: hintText.isEmpty ? null : hintText,
    prefixIcon:
        prefixIcon != null ? Icon(prefixIcon, size: prefixIconSize) : null,
    prefixIconConstraints: prefixIcon != null
        ? const BoxConstraints(minWidth: 36, minHeight: 36)
        : null,
    filled: true,
    fillColor: colors.inputFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(color: colors.inputBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(color: colors.inputBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
    contentPadding:
        contentPadding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );
}

Color _avatarColor(_ConversationType type) {
  switch (type) {
    case _ConversationType.group:
      return const Color(0xFF8B5CF6);
    case _ConversationType.vendor:
      return const Color(0xFFF97316);
    case _ConversationType.direct:
      return const Color(0xFF3B82F6);
  }
}

String _formatThreadTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.month}/${date.day}';
}

String _formatMessageTime(DateTime date) {
  var hour = date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final isAm = hour < 12;
  if (hour == 0) {
    hour = 12;
  } else if (hour > 12) {
    hour -= 12;
  }
  final period = isAm ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\\s+'));
  if (parts.isEmpty) return '';
  if (parts.length == 1) {
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '';
  }
  final first = parts.first.isNotEmpty ? parts.first[0] : '';
  final last = parts.last.isNotEmpty ? parts.last[0] : '';
  return '${first.toUpperCase()}${last.toUpperCase()}';
}

class _MessageReceiptCounts {
  const _MessageReceiptCounts({
    required this.readCount,
    required this.deliveredCount,
    required this.recipientCount,
  });

  final int readCount;
  final int deliveredCount;
  final int recipientCount;
}

List<Message> _filterMessages(
  List<Message> messages,
  _MessageFilter filter,
  String searchQuery,
  String? currentUserId, {
  DateTime? lastReadAt,
}) {
  final query = searchQuery.trim().toLowerCase();
  return messages.where((message) {
    final metadata = message.metadata ?? const <String, dynamic>{};
    final matchesSearch = query.isEmpty ||
        message.body.toLowerCase().contains(query) ||
        (message.senderName?.toLowerCase().contains(query) ?? false) ||
        (_parseAttachments(message.attachments)
            .any((attachment) => attachment.name.toLowerCase().contains(query)));
    if (!matchesSearch) return false;
    switch (filter) {
      case _MessageFilter.all:
        return true;
      case _MessageFilter.flagged:
        return metadata['flagged'] == true;
      case _MessageFilter.archived:
        return metadata['archived'] == true;
      case _MessageFilter.unread:
        if (currentUserId == null) return false;
        if (message.senderId == currentUserId) return false;
        if (lastReadAt == null) return true;
        return message.createdAt.isAfter(lastReadAt);
    }
  }).toList();
}

List<MessageAttachmentEntry> _parseAttachments(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((entry) => entry is Map
          ? MessageAttachmentEntry.fromJson(
              Map<String, dynamic>.from(entry),
            )
          : null)
      .whereType<MessageAttachmentEntry>()
      .toList();
}

_MessageReceiptCounts _computeReceipts({
  required Message message,
  required List<MessageParticipantEntry> participants,
  required String? currentUserId,
}) {
  var deliveredCount = 0;
  var readCount = 0;
  var recipientCount = 0;
  if (currentUserId == null) {
    return const _MessageReceiptCounts(
      readCount: 0,
      deliveredCount: 0,
      recipientCount: 0,
    );
  }
  for (final participant in participants) {
    final userId = participant.userId;
    if (userId == null || userId.isEmpty) continue;
    if (userId == currentUserId) continue;
    if (!participant.isActive) continue;
    recipientCount += 1;
    final deliveredAt = participant.lastDeliveredAt;
    final readAt = participant.lastReadAt;
    if (deliveredAt != null && !deliveredAt.isBefore(message.createdAt)) {
      deliveredCount += 1;
    }
    if (readAt != null && !readAt.isBefore(message.createdAt)) {
      readCount += 1;
    }
  }
  if (readCount > deliveredCount) {
    deliveredCount = readCount;
  }
  return _MessageReceiptCounts(
    readCount: readCount,
    deliveredCount: deliveredCount,
    recipientCount: recipientCount,
  );
}

String _resolveTypingLabels(
  Map<String, DateTime> typingUsers,
  List<MessageParticipantEntry> participants,
  String? currentUserId,
) {
  final now = DateTime.now();
  final activeIds = typingUsers.entries
      .where((entry) => now.difference(entry.value).inSeconds < 6)
      .map((entry) => entry.key)
      .where((id) => id != currentUserId)
      .toList();
  if (activeIds.isEmpty) return '';
  final names = activeIds.map((id) {
    final participant = participants.cast<MessageParticipantEntry?>().firstWhere(
          (entry) => entry?.userId == id,
          orElse: () => null,
        );
    return participant?.displayName ?? 'Someone';
  }).toList();
  if (names.length == 1) {
    return '${names.first} is typing...';
  }
  if (names.length == 2) {
    return '${names.first} and ${names[1]} are typing...';
  }
  return '${names.first} and ${names.length - 1} others are typing...';
}

DateTime? _parseNullableDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

String _filterLabel(_MessageFilter filter) {
  switch (filter) {
    case _MessageFilter.all:
      return 'All';
    case _MessageFilter.unread:
      return 'Unread';
    case _MessageFilter.flagged:
      return 'Flagged';
    case _MessageFilter.archived:
      return 'Archived';
  }
}

bool _isMutedSetting(String level, DateTime? muteUntil) {
  if (level == 'none') return true;
  if (muteUntil == null) return false;
  return muteUntil.isAfter(DateTime.now());
}

String _notificationSummary(String level, DateTime? muteUntil) {
  if (_isMutedSetting(level, muteUntil)) return 'Muted';
  if (level == 'mentions') return 'Mentions only';
  return 'All messages';
}

bool _isImageExtension(String extension) {
  const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
  return imageExtensions.contains(extension.toLowerCase());
}

String _contentTypeForExtension(String extension) {
  final normalized = extension.toLowerCase();
  if (_isImageExtension(normalized)) {
    if (normalized == 'jpg') return 'image/jpeg';
    return 'image/$normalized';
  }
  switch (normalized) {
    case 'pdf':
      return 'application/pdf';
    case 'csv':
      return 'text/csv';
    case 'txt':
      return 'text/plain';
    case 'json':
      return 'application/json';
    case 'zip':
      return 'application/zip';
    default:
      return 'application/octet-stream';
  }
}
