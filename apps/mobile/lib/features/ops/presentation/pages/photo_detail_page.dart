import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared/shared.dart';

import '../../data/ops_provider.dart';
import '../../data/ops_repository.dart';
import '../../../../core/utils/file_bytes_loader.dart';

class PhotoDetailPage extends ConsumerStatefulWidget {
  const PhotoDetailPage({super.key, required this.photo});

  final ProjectPhoto photo;

  @override
  ConsumerState<PhotoDetailPage> createState() => _PhotoDetailPageState();
}

class _PhotoDetailPageState extends ConsumerState<PhotoDetailPage> {
  final _commentController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  AttachmentDraft? _voiceNote;
  bool _recording = false;
  bool _sending = false;

  @override
  void dispose() {
    if (_recording) {
      _recorder.stop();
    }
    _commentController.dispose();
    _recorder.dispose();
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
          if (widget.photo.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.photo.tags
                  .map(
                    (tag) => Chip(
                      avatar: _tagIcon(tag) == null
                          ? null
                          : Icon(_tagIcon(tag), size: 16),
                      label: Text(_formatTag(tag)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
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
                      (comment) {
                        final voiceNote =
                            comment.metadata?['voiceNote'] as Map?;
                        return Column(
                          children: [
                            ListTile(
                              leading:
                                  const Icon(Icons.chat_bubble_outline),
                              title: Text(comment.body),
                              subtitle:
                                  Text(_formatDate(comment.createdAt)),
                            ),
                            if (voiceNote != null)
                              ListTile(
                                leading: const Icon(Icons.audiotrack),
                                title: Text(
                                  voiceNote['filename']?.toString() ??
                                      'Voice note',
                                ),
                                subtitle: const Text('Tap to play'),
                                onTap: () async {
                                  final url = voiceNote['url']?.toString();
                                  if (url == null || url.isEmpty) return;
                                  final uri = Uri.tryParse(url);
                                  if (uri == null) return;
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                          ],
                        );
                      },
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _recording ? _stopVoiceNote : _startVoiceNote,
                icon: Icon(_recording ? Icons.stop : Icons.mic),
                label: Text(_recording ? 'Stop voice note' : 'Voice note'),
              ),
              if (_voiceNote != null)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _voiceNote = null),
                  icon: const Icon(Icons.close),
                  label: const Text('Remove voice note'),
                ),
            ],
          ),
          if (_voiceNote != null) ...[
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.audiotrack),
              title: Text(_voiceNote!.filename),
              subtitle: const Text('Voice note attached'),
            ),
          ],
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
            voiceNote: _voiceNote,
          );
      _commentController.clear();
      setState(() => _voiceNote = null);
      ref.invalidate(photoCommentsProvider(widget.photo.id));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startVoiceNote() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required.')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'photo_comment_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _recorder.start(const RecordConfig(), path: path);
    if (!mounted) return;
    setState(() => _recording = true);
  }

  Future<void> _stopVoiceNote() async {
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (path == null) return;
    final bytes = await loadFileBytes(path);
    if (bytes == null) return;
    setState(() {
      _voiceNote = AttachmentDraft(
        type: 'audio',
        bytes: bytes,
        filename: p.basename(path),
        mimeType: 'audio/m4a',
        metadata: const {'voiceNote': true},
      );
    });
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

  String _formatTag(String tag) {
    switch (tag) {
      case 'before':
        return 'Before';
      case 'after':
        return 'After';
      case 'logo_sticker':
        return 'Logo sticker';
      default:
        return tag;
    }
  }

  IconData? _tagIcon(String tag) {
    switch (tag) {
      case 'before':
        return Icons.flag_outlined;
      case 'after':
        return Icons.check_circle_outline;
      case 'logo_sticker':
        return Icons.label_outline;
      default:
        return null;
    }
  }
}
