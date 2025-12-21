import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared/shared.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/projects_provider.dart';
import '../../../documents/presentation/pages/documents_page.dart';
import 'project_share_page.dart';
import 'project_update_editor_page.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({required this.project, super.key});

  final Project project;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  static const _shareBaseUrl = 'https://formbridge.app/share';
  late Project _project;
  String? _selectedTag;
  bool _showSharedOnly = false;
  RealtimeChannel? _updatesChannel;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _updatesChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToUpdates() {
    final client = Supabase.instance.client;
    _updatesChannel = client.channel('project-updates-${_project.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'project_updates',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'project_id',
          value: _project.id,
        ),
        callback: (_) {
          if (!mounted) return;
          ref.invalidate(projectUpdatesProvider(_project.id));
        },
      )
      ..subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final updatesAsync = ref.watch(projectUpdatesProvider(_project.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(_project.name),
        actions: [
          IconButton(
            tooltip: 'Share gallery',
            icon: const Icon(Icons.share),
            onPressed: _shareProject,
          ),
          IconButton(
            tooltip: 'Show QR code',
            icon: const Icon(Icons.qr_code_2),
            onPressed: _showShareQr,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUpdateComposer,
        icon: const Icon(Icons.add),
        label: const Text('Add update'),
      ),
      body: updatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Updates Load Error',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load project updates.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${e.toString()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => ref.invalidate(projectUpdatesProvider(_project.id)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
        data: (updates) {
          final grouped = _groupUpdates(updates);
          final visibleUpdates = _applyUpdateFilters(grouped.mainUpdates);
          final tags = grouped.tags;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(projectUpdatesProvider(_project.id));
              await ref.read(projectUpdatesProvider(_project.id).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProjectSummaryCard(
                  project: _project,
                  updates: grouped.mainUpdates,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openSharedTimeline,
                  icon: const Icon(Icons.public),
                  label: const Text('Open shared timeline'),
                ),
                const SizedBox(height: 16),
                if (tags.isNotEmpty) _buildTagFilters(tags),
                if (tags.isNotEmpty) const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show client gallery only'),
                  value: _showSharedOnly,
                  onChanged: (value) => setState(() => _showSharedOnly = value),
                ),
                const SizedBox(height: 12),
                if (visibleUpdates.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'No updates yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text('Add photos, notes, or voice notes to build a timeline.'),
                        ],
                      ),
                    ),
                  )
                else
                  ...visibleUpdates.map(
                    (update) => _ProjectUpdateCard(
                      update: update,
                      comments: grouped.comments[update.id] ?? const [],
                      onToggleShared: _toggleShared,
                      onAddComment: _addComment,
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openUpdateComposer() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectUpdateEditorPage(project: _project),
      ),
    );
    if (!mounted) return;
    ref.invalidate(projectUpdatesProvider(_project.id));
  }

  Future<void> _shareProject() async {
    final repo = ref.read(projectsRepositoryProvider);
    final updated = await repo.ensureShareToken(_project);
    if (!mounted) return;
    setState(() => _project = updated);
    final token = updated.shareToken ?? '';
    final link = '$_shareBaseUrl/$token';
    final message = StringBuffer()
      ..writeln('Project: ${updated.name}')
      ..writeln('Client gallery: $link');
    await SharePlus.instance.share(ShareParams(text: message.toString()));
  }

  Future<void> _openSharedTimeline() async {
    final repo = ref.read(projectsRepositoryProvider);
    final updated = await repo.ensureShareToken(_project);
    if (!mounted) return;
    setState(() => _project = updated);
    final token = updated.shareToken;
    if (token == null || token.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectSharePage(shareToken: token),
      ),
    );
  }

  Future<void> _showShareQr() async {
    final repo = ref.read(projectsRepositoryProvider);
    final updated = await repo.ensureShareToken(_project);
    if (!mounted) return;
    setState(() => _project = updated);
    final token = updated.shareToken ?? '';
    final link = '$_shareBaseUrl/$token';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Client gallery link',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              QrImageView(
                data: link,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              SelectableText(
                link,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy link'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  List<ProjectUpdate> _applyUpdateFilters(List<ProjectUpdate> updates) {
    var filtered = updates;
    if (_showSharedOnly) {
      filtered = filtered.where((u) => u.isShared).toList();
    }
    if (_selectedTag != null) {
      filtered = filtered.where((u) => u.tags.contains(_selectedTag)).toList();
    }
    return filtered;
  }

  Widget _buildTagFilters(List<String> tags) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('All tags'),
          selected: _selectedTag == null,
          onSelected: (_) => setState(() => _selectedTag = null),
        ),
        ...tags.map(
          (tag) => FilterChip(
            label: Text(tag),
            selected: _selectedTag == tag,
            onSelected: (_) => setState(() => _selectedTag = tag),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleShared(ProjectUpdate update, bool value) async {
    final repo = ref.read(projectsRepositoryProvider);
    await repo.toggleUpdateShared(update.id, value);
    if (!mounted) return;
    ref.invalidate(projectUpdatesProvider(_project.id));
  }

  Future<void> _addComment(ProjectUpdate update) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add comment'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Share an update or question',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    final repo = ref.read(projectsRepositoryProvider);
    await repo.addUpdate(
      projectId: _project.id,
      type: 'comment',
      body: result,
      parentId: update.id,
    );
    if (!mounted) return;
    ref.invalidate(projectUpdatesProvider(_project.id));
  }

  _GroupedUpdates _groupUpdates(List<ProjectUpdate> updates) {
    final comments = <String, List<ProjectUpdate>>{};
    final mainUpdates = <ProjectUpdate>[];
    final tags = <String>{};

    for (final update in updates) {
      if (update.parentId != null && update.parentId!.isNotEmpty) {
        comments.putIfAbsent(update.parentId!, () => []).add(update);
      } else {
        mainUpdates.add(update);
        tags.addAll(update.tags);
      }
    }

    final sortedTags = tags.where((t) => t.trim().isNotEmpty).toList()..sort();
    return _GroupedUpdates(
      mainUpdates: mainUpdates,
      comments: comments,
      tags: sortedTags,
    );
  }
}

class _GroupedUpdates {
  _GroupedUpdates({
    required this.mainUpdates,
    required this.comments,
    required this.tags,
  });

  final List<ProjectUpdate> mainUpdates;
  final Map<String, List<ProjectUpdate>> comments;
  final List<String> tags;
}

class _ProjectSummaryCard extends StatelessWidget {
  const _ProjectSummaryCard({
    required this.project,
    required this.updates,
  });

  final Project project;
  final List<ProjectUpdate> updates;

  @override
  Widget build(BuildContext context) {
    final photoCount = updates.where((u) => u.type == 'photo').length;
    final sharedCount = updates.where((u) => u.isShared).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project.name, style: Theme.of(context).textTheme.titleLarge),
            if ((project.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(project.description!),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _SummaryPill(label: 'Updates', value: updates.length.toString()),
                _SummaryPill(label: 'Photos', value: photoCount.toString()),
                _SummaryPill(label: 'Shared', value: sharedCount.toString()),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_copy),
              label: const Text('Documents'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DocumentsPage(
                      projectId: project.id,
                      projectName: project.name,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _ProjectUpdateCard extends StatelessWidget {
  const _ProjectUpdateCard({
    required this.update,
    required this.comments,
    required this.onToggleShared,
    required this.onAddComment,
  });

  final ProjectUpdate update;
  final List<ProjectUpdate> comments;
  final Future<void> Function(ProjectUpdate update, bool value) onToggleShared;
  final Future<void> Function(ProjectUpdate update) onAddComment;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(update.type);
    final timestamp = update.createdAt.toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    update.title ?? _labelForType(update.type),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if ((update.body ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(update.body!),
            ],
            if (update.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: update.tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (update.attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              _AttachmentStrip(attachments: update.attachments),
            ],
            if (update.type != 'comment') ...[
              const Divider(height: 24),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => onAddComment(update),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text('Comment${comments.isEmpty ? '' : ' (${comments.length})'}'),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Text('Share'),
                      Switch(
                        value: update.isShared,
                        onChanged: (value) => onToggleShared(update, value),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            if (comments.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...comments.map(
                (comment) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${comment.body ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'photo':
        return Icons.photo;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.mic;
      case 'comment':
        return Icons.chat_bubble_outline;
      default:
        return Icons.note_alt;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'photo':
        return 'Photo update';
      case 'video':
        return 'Video update';
      case 'audio':
        return 'Voice note';
      case 'comment':
        return 'Comment';
      default:
        return 'Project update';
    }
  }
}

class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({required this.attachments});

  final List<MediaAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return _AttachmentPreview(attachment: attachment);
        },
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.attachment});

  final MediaAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final url = attachment.url;
    final isImage = attachment.type == 'photo' ||
        (attachment.filename?.toLowerCase().endsWith('.png') ?? false) ||
        (attachment.filename?.toLowerCase().endsWith('.jpg') ?? false) ||
        (attachment.filename?.toLowerCase().endsWith('.jpeg') ?? false);
    final isVideo =
        attachment.type == 'video' || (attachment.filename?.toLowerCase().endsWith('.mp4') ?? false);
    final isAudio = attachment.type == 'audio' ||
        (attachment.filename?.toLowerCase().endsWith('.m4a') ?? false) ||
        (attachment.filename?.toLowerCase().endsWith('.mp3') ?? false);
    final icon = isVideo
        ? Icons.videocam
        : isAudio
        ? Icons.mic
        : Icons.insert_drive_file;
    return InkWell(
      onTap: () async {
        if (isImage && url.isNotEmpty) {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              child: Image.network(url, fit: BoxFit.cover),
            ),
          );
        } else if (url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: SizedBox(
        width: 180,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: isImage && url.isNotEmpty
              ? Image.network(url, fit: BoxFit.cover)
              : Container(
                  color: Colors.grey.shade200,
                  child: Center(child: Icon(icon, size: 42)),
                ),
        ),
      ),
    );
  }
}
