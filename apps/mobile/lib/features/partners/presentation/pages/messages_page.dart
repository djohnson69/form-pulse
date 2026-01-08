import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/partners_provider.dart';
import '../../data/partners_repository.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _showConversations = true;
  String? _selectedId;
  bool _sending = false;
  RealtimeChannel? _threadsChannel;
  late List<_DemoConversation> _demoConversations;

  @override
  void initState() {
    super.initState();
    _demoConversations = List<_DemoConversation>.from(_seedDemoConversations);
    _subscribeToThreadChanges();
  }

  @override
  void dispose() {
    _threadsChannel?.unsubscribe();
    _searchController.dispose();
    _messageController.dispose();
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
        callback: (_) {
          if (!mounted) return;
          ref.invalidate(messageThreadsProvider);
          final selectedId = _selectedId;
          if (selectedId != null) {
            ref.invalidate(threadMessagesProvider(selectedId));
          }
        },
      )
      ..subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _MessagingColors.fromTheme(Theme.of(context));
    final threadsAsync = ref.watch(messageThreadsProvider);
    final threads = threadsAsync.asData?.value ?? const <MessageThreadPreview>[];
    final useDemo = threads.isEmpty && !threadsAsync.isLoading;
    final conversations = useDemo
        ? _demoConversations.map((c) => c.summary).toList()
        : threads.map(_mapPreview).toList();
    final filtered = _applySearch(conversations);

    return Scaffold(
      backgroundColor: colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final selected = _findConversation(conversations, _selectedId);
          final showList =
              isWide || _showConversations || _selectedId == null;
          final showChat = isWide || (!_showConversations && selected != null);
          return PopScope(
            canPop: isWide || _showConversations || _selectedId == null,
            onPopInvoked: (didPop) {
              if (didPop) return;
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
                      onSelect: (id) => _handleSelect(
                        id,
                        isWide: isWide,
                        useDemo: useDemo,
                      ),
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
                      onSend: () => _handleSend(useDemo: useDemo),
                      sending: _sending,
                      messagesAsync: !useDemo && selected != null
                          ? ref.watch(threadMessagesProvider(selected.id))
                          : null,
                      demoConversation: useDemo && selected != null
                          ? _findDemoConversation(selected.id)
                          : null,
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

  _DemoConversation? _findDemoConversation(String id) {
    for (final conversation in _demoConversations) {
      if (conversation.summary.id == id) return conversation;
    }
    return null;
  }

  void _handleSelect(
    String id, {
    required bool isWide,
    required bool useDemo,
  }) {
    setState(() {
      _selectedId = id;
      if (!isWide) _showConversations = false;
      if (useDemo) {
        _demoConversations = _demoConversations.map((conversation) {
          if (conversation.summary.id != id) return conversation;
          return conversation.copyWith(
            summary: conversation.summary.copyWith(unread: 0),
          );
        }).toList();
      }
    });
  }

  void _handleBack() {
    setState(() {
      _showConversations = true;
      _selectedId = null;
    });
  }

  Future<void> _handleSend({required bool useDemo}) async {
    final id = _selectedId;
    final text = _messageController.text.trim();
    if (id == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    if (useDemo) {
      setState(() {
        _demoConversations = _demoConversations.map((conversation) {
          if (conversation.summary.id != id) return conversation;
          final updatedMessages = [
            ...conversation.messages,
            _MessageDisplay(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sender: 'Me',
              avatar: 'JD',
              content: text,
              time: _formatMessageTime(DateTime.now()),
              isMine: true,
              attachmentCount: 0,
            ),
          ];
          return conversation.copyWith(
            summary: conversation.summary.copyWith(
              lastMessage: text,
              timeLabel: 'Just now',
            ),
            messages: updatedMessages,
          );
        }).toList();
        _messageController.clear();
      });
      setState(() => _sending = false);
      return;
    }

    try {
      final repo = ref.read(partnersRepositoryProvider);
      await repo.sendMessage(threadId: id, body: text);
      _messageController.clear();
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

  _ConversationDisplay _mapPreview(MessageThreadPreview preview) {
    final name = preview.targetName ?? preview.thread.title;
    final lastMessage = preview.lastMessage ?? 'Start the conversation';
    final timeLabel = preview.lastMessageAt != null
        ? _formatThreadTime(preview.lastMessageAt!)
        : 'Just now';
    final type = _resolveConversationType(preview);
    final seed = preview.thread.id.hashCode.abs();
    final unread = preview.messageCount == 0 ? 0 : (seed % 4);
    final online = type == _ConversationType.direct && seed.isEven;
    final members = type == _ConversationType.group ? 3 + (seed % 6) : null;
    return _ConversationDisplay(
      id: preview.thread.id,
      name: name,
      lastMessage: lastMessage,
      timeLabel: timeLabel,
      unread: unread,
      online: online,
      type: type,
      members: members,
      avatarLabel: _initialsFor(name),
    );
  }

  _ConversationType _resolveConversationType(MessageThreadPreview preview) {
    final type = preview.thread.type ?? 'internal';
    if (type == 'vendor') return _ConversationType.vendor;
    if (type == 'client') return _ConversationType.direct;
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
    required this.loading,
    required this.error,
  });

  final _MessagingColors colors;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<_ConversationDisplay> conversations;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final bool loading;
  final bool error;

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.all(16),
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
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.more_vert, color: colors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: _inputDecoration(
                    colors,
                    hintText: 'Search conversations...',
                    prefixIcon: Icons.search,
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
                : ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return _ConversationTile(
                        colors: colors,
                        conversation: conversation,
                        selected: selectedId == conversation.id,
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
    required this.onTap,
  });

  final _MessagingColors colors;
  final _ConversationDisplay conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarColor = _avatarColor(conversation.type);
    final background = selected ? colors.selected : Colors.transparent;
    final textColor = selected ? colors.title : colors.body;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: background,
        child: Row(
          children: [
            _ConversationAvatar(
              colors: colors,
              label: conversation.avatarLabel,
              online: conversation.online,
              type: conversation.type,
              background: avatarColor,
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
  });

  final _MessagingColors colors;
  final String label;
  final bool online;
  final _ConversationType type;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final borderColor = colors.isDark ? colors.surface : Colors.white;
    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: type == _ConversationType.group
              ? const Icon(Icons.group, color: Colors.white, size: 20)
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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
    required this.onSend,
    required this.sending,
    required this.messagesAsync,
    required this.demoConversation,
  });

  final _MessagingColors colors;
  final _ConversationDisplay? conversation;
  final bool showBack;
  final VoidCallback onBack;
  final TextEditingController messageController;
  final VoidCallback onSend;
  final bool sending;
  final AsyncValue<List<Message>>? messagesAsync;
  final _DemoConversation? demoConversation;

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
                  size: 48, color: colors.muted),
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
        ),
        Expanded(
          child: _MessageList(
            colors: colors,
            messagesAsync: messagesAsync,
            demoConversation: demoConversation,
          ),
        ),
        _MessageComposer(
          colors: colors,
          controller: messageController,
          onSend: onSend,
          sending: sending,
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
  });

  final _MessagingColors colors;
  final _ConversationDisplay conversation;
  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final avatarColor = _avatarColor(conversation.type);
    final subtitle = conversation.type == _ConversationType.direct
        ? conversation.online
            ? 'Active now'
            : 'Offline'
        : conversation.members != null
            ? '${conversation.members} members'
            : 'Group chat';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              onPressed: onBack,
              icon: Icon(Icons.chevron_left, color: colors.muted),
              tooltip: 'Back',
            ),
          _ConversationAvatar(
            colors: colors,
            label: conversation.avatarLabel,
            online: conversation.online,
            type: conversation.type,
            background: avatarColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.title,
                      ),
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
              icon: Icon(Icons.call, color: colors.muted),
            ),
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.videocam, color: colors.muted),
            ),
          ],
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.more_vert, color: colors.muted),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.colors,
    required this.messagesAsync,
    required this.demoConversation,
  });

  final _MessagingColors colors;
  final AsyncValue<List<Message>>? messagesAsync;
  final _DemoConversation? demoConversation;

  @override
  Widget build(BuildContext context) {
    if (demoConversation != null) {
      return _MessageListBody(
        colors: colors,
        messages: demoConversation!.messages,
      );
    }
    if (messagesAsync == null) {
      return const SizedBox.shrink();
    }
    return messagesAsync!.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorBanner(
        colors: colors,
        message: 'Failed to load messages.',
      ),
      data: (messages) {
        if (messages.isEmpty) {
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
        final displayMessages = messages.map((message) {
          final isMine = currentUserId != null && message.senderId == currentUserId;
          final sender = message.senderName ?? (isMine ? 'Me' : 'User');
          final avatar = _initialsFor(sender);
          return _MessageDisplay(
            id: message.id,
            sender: sender,
            avatar: avatar,
            content: message.body,
            time: _formatMessageTime(message.createdAt),
            isMine: isMine,
            attachmentCount: message.attachments?.length ?? 0,
          );
        }).toList();
        return _MessageListBody(colors: colors, messages: displayMessages);
      },
    );
  }
}

class _MessageListBody extends StatelessWidget {
  const _MessageListBody({
    required this.colors,
    required this.messages,
  });

  final _MessagingColors colors;
  final List<_MessageDisplay> messages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return _MessageBubble(
          colors: colors,
          message: messages[index],
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.colors,
    required this.message,
  });

  final _MessagingColors colors;
  final _MessageDisplay message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final bubbleColor = isMine ? colors.primary : colors.bubbleOther;
    final textColor = isMine ? Colors.white : colors.bubbleOtherText;
    final attachmentBackground = isMine
        ? Colors.white.withValues(alpha: 0.2)
        : colors.filterSurface;
    final attachmentForeground = isMine ? Colors.white : colors.body;
    final radius = isMine
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(6),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(16),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
            ),
          if (!isMine) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: radius,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                      if (message.attachmentCount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: attachmentBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo,
                                size: 14,
                                color: attachmentForeground,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${message.attachmentCount} attachments',
                                style: TextStyle(
                                  color: attachmentForeground,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                      ),
                ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 8),
          if (isMine)
            _BubbleAvatar(
              colors: colors,
              label: message.avatar,
              isMine: true,
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
  });

  final _MessagingColors colors;
  final String label;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isMine ? colors.primary : colors.avatarMuted,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
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
  });

  final _MessagingColors colors;
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showExtras = constraints.maxWidth >= 768;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.attach_file, color: colors.muted),
              ),
              if (showExtras)
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.image_outlined, color: colors.muted),
                ),
              if (showExtras)
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.mic_none, color: colors.muted),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onSend(),
                  decoration: _inputDecoration(
                    colors,
                    hintText: 'Type a message...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                color: colors.primary,
              ),
            ],
          ),
        );
      },
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
    );
  }
}

class _MessageDisplay {
  const _MessageDisplay({
    required this.id,
    required this.sender,
    required this.avatar,
    required this.content,
    required this.time,
    required this.isMine,
    required this.attachmentCount,
  });

  final String id;
  final String sender;
  final String avatar;
  final String content;
  final String time;
  final bool isMine;
  final int attachmentCount;
}

class _DemoConversation {
  const _DemoConversation({
    required this.summary,
    required this.messages,
  });

  final _ConversationDisplay summary;
  final List<_MessageDisplay> messages;

  _DemoConversation copyWith({
    _ConversationDisplay? summary,
    List<_MessageDisplay>? messages,
  }) {
    return _DemoConversation(
      summary: summary ?? this.summary,
      messages: messages ?? this.messages,
    );
  }
}

enum _ConversationType { direct, group, vendor }

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
      selected: isDark
          ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
          : const Color(0xFFEFF6FF),
      filterSurface:
          isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
      inputFill: isDark ? const Color(0xFF0B1220) : Colors.white,
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
}) {
  return InputDecoration(
    hintText: hintText.isEmpty ? null : hintText,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
    filled: true,
    fillColor: colors.inputFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.inputBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.inputBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

final List<_DemoConversation> _seedDemoConversations = [
  _DemoConversation(
    summary: _ConversationDisplay(
      id: 'demo-1',
      name: 'Sarah Johnson',
      lastMessage: 'Thanks for the update!',
      timeLabel: '2m ago',
      unread: 0,
      online: true,
      type: _ConversationType.direct,
      members: null,
      avatarLabel: 'SJ',
    ),
    messages: [
      _MessageDisplay(
        id: 'm1',
        sender: 'Sarah Johnson',
        avatar: 'SJ',
        content: 'Hi! Can you check the latest inspection report?',
        time: '10:30 AM',
        isMine: false,
        attachmentCount: 0,
      ),
      _MessageDisplay(
        id: 'm2',
        sender: 'Me',
        avatar: 'JD',
        content: 'Sure, let me pull it up now.',
        time: '10:32 AM',
        isMine: true,
        attachmentCount: 0,
      ),
      _MessageDisplay(
        id: 'm3',
        sender: 'Me',
        avatar: 'JD',
        content: 'I see a few items that need attention. I\'ll send you the details.',
        time: '10:35 AM',
        isMine: true,
        attachmentCount: 0,
      ),
      _MessageDisplay(
        id: 'm4',
        sender: 'Sarah Johnson',
        avatar: 'SJ',
        content: 'Perfect! Also, can you share the photos from Building A?',
        time: '10:38 AM',
        isMine: false,
        attachmentCount: 0,
      ),
      _MessageDisplay(
        id: 'm5',
        sender: 'Me',
        avatar: 'JD',
        content: 'Absolutely. Uploading them now...',
        time: '10:40 AM',
        isMine: true,
        attachmentCount: 3,
      ),
      _MessageDisplay(
        id: 'm6',
        sender: 'Sarah Johnson',
        avatar: 'SJ',
        content: 'Thanks for the update!',
        time: '10:42 AM',
        isMine: false,
        attachmentCount: 0,
      ),
    ],
  ),
  _DemoConversation(
    summary: _ConversationDisplay(
      id: 'demo-2',
      name: 'Project Team Alpha',
      lastMessage: 'Meeting at 3pm',
      timeLabel: '15m ago',
      unread: 3,
      online: false,
      type: _ConversationType.group,
      members: 8,
      avatarLabel: 'PT',
    ),
    messages: [
      _MessageDisplay(
        id: 'm7',
        sender: 'Mike Chen',
        avatar: 'MC',
        content: 'Team, we need to discuss the project timeline.',
        time: '9:15 AM',
        isMine: false,
        attachmentCount: 0,
      ),
      _MessageDisplay(
        id: 'm8',
        sender: 'Emily Davis',
        avatar: 'ED',
        content: 'I agree. When should we meet?',
        time: '9:20 AM',
        isMine: false,
        attachmentCount: 0,
      ),
      _MessageDisplay(
        id: 'm9',
        sender: 'Me',
        avatar: 'JD',
        content: 'I\'m available after 2pm today.',
        time: '9:25 AM',
        isMine: true,
        attachmentCount: 0,
      ),
      _MessageDisplay(
        id: 'm10',
        sender: 'Sarah Johnson',
        avatar: 'SJ',
        content: 'Meeting at 3pm',
        time: '9:30 AM',
        isMine: false,
        attachmentCount: 0,
      ),
    ],
  ),
  _DemoConversation(
    summary: _ConversationDisplay(
      id: 'demo-3',
      name: 'Mike Chen',
      lastMessage: 'Can you review this?',
      timeLabel: '1h ago',
      unread: 1,
      online: true,
      type: _ConversationType.direct,
      members: null,
      avatarLabel: 'MC',
    ),
    messages: [
      _MessageDisplay(
        id: 'm11',
        sender: 'Mike Chen',
        avatar: 'MC',
        content: 'Hey, I just finished the compliance report.',
        time: '2:00 PM',
        isMine: false,
        attachmentCount: 0,
      ),
      _MessageDisplay(
        id: 'm12',
        sender: 'Mike Chen',
        avatar: 'MC',
        content: 'Can you review this?',
        time: '2:05 PM',
        isMine: false,
        attachmentCount: 0,
      ),
    ],
  ),
  _DemoConversation(
    summary: _ConversationDisplay(
      id: 'demo-4',
      name: 'Site Supervisors',
      lastMessage: 'Safety report submitted',
      timeLabel: '2h ago',
      unread: 0,
      online: false,
      type: _ConversationType.group,
      members: 5,
      avatarLabel: 'SS',
    ),
    messages: [
      _MessageDisplay(
        id: 'm13',
        sender: 'Tom Wilson',
        avatar: 'TW',
        content: 'Morning everyone. Site inspection complete.',
        time: '8:00 AM',
        isMine: false,
        attachmentCount: 0,
      ),
      _MessageDisplay(
        id: 'm14',
        sender: 'Lisa Brown',
        avatar: 'LB',
        content: 'Safety report submitted',
        time: '8:30 AM',
        isMine: false,
        attachmentCount: 0,
      ),
      _MessageDisplay(
        id: 'm15',
        sender: 'Me',
        avatar: 'JD',
        content: 'Great work team!',
        time: '8:45 AM',
        isMine: true,
        attachmentCount: 0,
      ),
    ],
  ),
  _DemoConversation(
    summary: _ConversationDisplay(
      id: 'demo-5',
      name: 'Emily Davis',
      lastMessage: 'Task completed ✓',
      timeLabel: '3h ago',
      unread: 0,
      online: false,
      type: _ConversationType.direct,
      members: null,
      avatarLabel: 'ED',
    ),
    messages: [
      _MessageDisplay(
        id: 'm16',
        sender: 'Emily Davis',
        avatar: 'ED',
        content: 'I\'ve completed the maintenance checklist for Zone B.',
        time: '11:00 AM',
        isMine: false,
        attachmentCount: 0,
      ),
      _MessageDisplay(
        id: 'm17',
        sender: 'Me',
        avatar: 'JD',
        content: 'Excellent! Any issues found?',
        time: '11:15 AM',
        isMine: true,
        attachmentCount: 0,
      ),
      _MessageDisplay(
        id: 'm18',
        sender: 'Emily Davis',
        avatar: 'ED',
        content: 'Task completed ✓',
        time: '11:20 AM',
        isMine: false,
        attachmentCount: 0,
      ),
    ],
  ),
  _DemoConversation(
    summary: _ConversationDisplay(
      id: 'demo-6',
      name: 'Vendor - ABC Supply',
      lastMessage: 'Delivery scheduled',
      timeLabel: '5h ago',
      unread: 2,
      online: false,
      type: _ConversationType.vendor,
      members: null,
      avatarLabel: 'VS',
    ),
    messages: [
      _MessageDisplay(
        id: 'm19',
        sender: 'ABC Supply',
        avatar: 'VS',
        content: 'Your order #12345 has been processed.',
        time: '9:00 AM',
        isMine: false,
        attachmentCount: 0,
      ),
      _MessageDisplay(
        id: 'm20',
        sender: 'ABC Supply',
        avatar: 'VS',
        content: 'Delivery scheduled',
        time: '9:30 AM',
        isMine: false,
        attachmentCount: 0,
      ),
    ],
  ),
];
