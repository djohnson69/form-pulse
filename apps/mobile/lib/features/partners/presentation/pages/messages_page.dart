import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/partners_provider.dart';
import '../../data/partners_repository.dart';
import 'thread_detail_page.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  String _query = '';
  String _typeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(messageThreadsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(messageThreadsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewThread(context),
        icon: const Icon(Icons.add_comment),
        label: const Text('New Thread'),
      ),
      body: threadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _ErrorView(error: e.toString()),
        data: (threads) {
          final filtered = _applyFilters(threads);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search threads',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _typeFilter == 'all',
                    onSelected: () => setState(() => _typeFilter = 'all'),
                  ),
                  _FilterChip(
                    label: 'Clients',
                    selected: _typeFilter == 'client',
                    onSelected: () => setState(() => _typeFilter = 'client'),
                  ),
                  _FilterChip(
                    label: 'Vendors',
                    selected: _typeFilter == 'vendor',
                    onSelected: () => setState(() => _typeFilter = 'vendor'),
                  ),
                  _FilterChip(
                    label: 'Internal',
                    selected: _typeFilter == 'internal',
                    onSelected: () => setState(() => _typeFilter = 'internal'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const _EmptyState()
              else
                ...filtered.map(
                  (preview) => _ThreadTile(
                    preview: preview,
                    onTap: () => _openThread(preview),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  List<MessageThreadPreview> _applyFilters(
    List<MessageThreadPreview> threads,
  ) {
    final query = _query.toLowerCase();
    return threads.where((preview) {
      final type = preview.thread.type ?? 'internal';
      final matchesType = _typeFilter == 'all' || _typeFilter == type;
      if (!matchesType) return false;
      if (query.isEmpty) return true;
      return preview.thread.title.toLowerCase().contains(query) ||
          (preview.targetName ?? '').toLowerCase().contains(query) ||
          (preview.lastMessage ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openThread(MessageThreadPreview preview) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThreadDetailPage(preview: preview),
      ),
    );
    if (!mounted) return;
    ref.invalidate(messageThreadsProvider);
  }

  Future<void> _openNewThread(BuildContext context) async {
    final result = await showModalBottomSheet<MessageThreadPreview?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _NewThreadSheet(),
    );
    if (!mounted) return;
    if (result != null) {
      await _openThread(result);
    }
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.preview, required this.onTap});

  final MessageThreadPreview preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (preview.targetName != null) preview.targetName!,
      if (preview.lastMessage != null) preview.lastMessage!,
    ].join(' • ');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(_iconForType(preview.thread.type)),
        ),
        title: Text(preview.thread.title),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (preview.lastMessageAt != null)
              Text(
                _formatDate(preview.lastMessageAt!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (preview.messageCount > 0)
              Text(
                '${preview.messageCount}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'client':
        return Icons.business;
      case 'vendor':
        return Icons.handshake;
      default:
        return Icons.chat_bubble;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _NewThreadSheet extends ConsumerStatefulWidget {
  const _NewThreadSheet();

  @override
  ConsumerState<_NewThreadSheet> createState() => _NewThreadSheetState();
}

class _NewThreadSheetState extends ConsumerState<_NewThreadSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _type = 'internal';
  String? _clientId;
  String? _vendorId;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final vendorsAsync = ref.watch(vendorsProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Text(
                  'New thread',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Thread title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Audience'),
              items: const [
                DropdownMenuItem(value: 'internal', child: Text('Internal')),
                DropdownMenuItem(value: 'client', child: Text('Client')),
                DropdownMenuItem(value: 'vendor', child: Text('Vendor')),
              ],
              onChanged: (value) {
                setState(() {
                  _type = value ?? 'internal';
                  _clientId = null;
                  _vendorId = null;
                });
              },
            ),
            const SizedBox(height: 12),
            if (_type == 'client')
              clientsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Clients error: $e'),
                data: (clients) => DropdownButtonFormField<String?>(
                  initialValue: _clientId,
                  decoration: const InputDecoration(labelText: 'Client'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Select client'),
                    ),
                    ...clients.map(
                      (client) => DropdownMenuItem(
                        value: client.id,
                        child: Text(client.companyName),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _clientId = value),
                  validator: (value) {
                    if (_type == 'client' && value == null) {
                      return 'Client is required';
                    }
                    return null;
                  },
                ),
              ),
            if (_type == 'vendor')
              vendorsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Vendors error: $e'),
                data: (vendors) => DropdownButtonFormField<String?>(
                  initialValue: _vendorId,
                  decoration: const InputDecoration(labelText: 'Vendor'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Select vendor'),
                    ),
                    ...vendors.map(
                      (vendor) => DropdownMenuItem(
                        value: vendor.id,
                        child: Text(vendor.companyName),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _vendorId = value),
                  validator: (value) {
                    if (_type == 'vendor' && value == null) {
                      return 'Vendor is required';
                    }
                    return null;
                  },
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'First message (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_saving ? 'Creating...' : 'Create thread'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(partnersRepositoryProvider);
      final thread = await repo.createThread(
        title: _titleController.text.trim(),
        clientId: _type == 'client' ? _clientId : null,
        vendorId: _type == 'vendor' ? _vendorId : null,
      );
      final firstMessage = _messageController.text.trim();
      if (firstMessage.isNotEmpty) {
        await repo.sendMessage(threadId: thread.id, body: firstMessage);
      }
      final previews = await repo.fetchThreadPreviews();
      final preview = previews.firstWhere(
        (p) => p.thread.id == thread.id,
        orElse: () => MessageThreadPreview(thread: thread),
      );
      if (!mounted) return;
      Navigator.of(context).pop(preview);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'No threads yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Start a thread to communicate with clients or vendors.'),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(error),
        ),
      ),
    );
  }
}
