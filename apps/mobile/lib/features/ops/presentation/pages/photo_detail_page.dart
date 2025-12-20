import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/ops_provider.dart';

class PhotoDetailPage extends ConsumerStatefulWidget {
  const PhotoDetailPage({super.key, required this.photo});

  final ProjectPhoto photo;

  @override
  ConsumerState<PhotoDetailPage> createState() => _PhotoDetailPageState();
}

class _PhotoDetailPageState extends ConsumerState<PhotoDetailPage> {
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(photoCommentsProvider(widget.photo.id));
    final attachments = widget.photo.attachments ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.photo.title ?? 'Project photo',
              style: Theme.of(context).textTheme.titleLarge),
          if ((widget.photo.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.photo.description!),
          ],
          const SizedBox(height: 16),
          Text('Attachments', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (attachments.isEmpty)
            const Text('No media attached.')
          else
            ...attachments.map(
              (attachment) => ListTile(
                leading: Icon(_attachmentIcon(attachment.type)),
                title: Text(attachment.filename ?? attachment.type),
                subtitle: Text(attachment.url),
              ),
            ),
          const SizedBox(height: 16),
          Text('Comments', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          commentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (comments) {
              if (comments.isEmpty) {
                return const Text('No comments yet.');
              }
              return Column(
                children: comments
                    .map(
                      (comment) => ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(comment.body),
                        subtitle:
                            Text(_formatDate(comment.createdAt)),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              labelText: 'Add a comment',
              border: OutlineInputBorder(),
            ),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _sending ? null : _sendComment,
            child: Text(_sending ? 'Sending...' : 'Post comment'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final mentions = _extractMentions(text);
      await ref.read(opsRepositoryProvider).addPhotoComment(
            photoId: widget.photo.id,
            body: text,
            mentions: mentions,
          );
      _commentController.clear();
      ref.invalidate(photoCommentsProvider(widget.photo.id));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<String> _extractMentions(String text) {
    final matches = RegExp(r'@([A-Za-z0-9_.-]+)').allMatches(text);
    return matches.map((m) => m.group(1)!).toList();
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  IconData _attachmentIcon(String type) {
    switch (type) {
      case 'photo':
        return Icons.photo;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.mic;
      default:
        return Icons.attach_file;
    }
  }
}
