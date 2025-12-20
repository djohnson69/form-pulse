import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../dashboard/presentation/pages/photo_annotator_page.dart';
import '../../../../core/utils/file_bytes_loader.dart';
import '../../data/projects_provider.dart';

class ProjectUpdateEditorPage extends ConsumerStatefulWidget {
  const ProjectUpdateEditorPage({required this.project, super.key});

  final Project project;

  @override
  ConsumerState<ProjectUpdateEditorPage> createState() =>
      _ProjectUpdateEditorPageState();
}

class _ProjectUpdateEditorPageState
    extends ConsumerState<ProjectUpdateEditorPage> {
  static const _bucketName =
      String.fromEnvironment('SUPABASE_BUCKET', defaultValue: 'formbridge-attachments');

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagsController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  final _picker = ImagePicker();
  final List<_UpdateAttachment> _attachments = [];

  String _type = 'photo';
  bool _shareWithClient = false;
  bool _saving = false;
  bool _recording = false;

  @override
  void dispose() {
    if (_recording) {
      _recorder.stop();
    }
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New Update')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Update type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'photo', child: Text('Photo')),
                  DropdownMenuItem(value: 'video', child: Text('Video')),
                  DropdownMenuItem(value: 'audio', child: Text('Voice note')),
                  DropdownMenuItem(value: 'note', child: Text('Note')),
                ],
                onChanged: (value) {
                  _handleTypeChange(value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include in client gallery'),
                value: _shareWithClient,
                onChanged: (value) => setState(() => _shareWithClient = value),
              ),
              const SizedBox(height: 12),
              if (_type != 'note') ...[
                Text('Attachments', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildAttachmentControls(),
                const SizedBox(height: 12),
                if (_attachments.isNotEmpty) _buildAttachmentList(),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Publish update'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentControls() {
    switch (_type) {
      case 'photo':
        return Wrap(
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Camera'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
          ],
        );
      case 'video':
        return Wrap(
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickVideo(ImageSource.camera),
              icon: const Icon(Icons.videocam),
              label: const Text('Record'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickVideo(ImageSource.gallery),
              icon: const Icon(Icons.video_library),
              label: const Text('Library'),
            ),
          ],
        );
      case 'audio':
        return OutlinedButton.icon(
          onPressed: _toggleRecording,
          icon: Icon(_recording ? Icons.stop : Icons.mic),
          label: Text(_recording ? 'Stop recording' : 'Record voice note'),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _handleTypeChange(String? value) async {
    if (_recording) {
      await _recorder.stop();
    }
    if (!mounted) return;
    setState(() {
      _type = value ?? 'photo';
      _attachments.clear();
      _recording = false;
    });
  }

  Widget _buildAttachmentList() {
    return Column(
      children: _attachments.map((attachment) {
        return Card(
          child: ListTile(
            leading: Icon(_attachmentIcon(attachment.type)),
            title: Text(attachment.label),
            subtitle: Text(
              attachment.filename ?? attachment.path ?? attachment.type,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (attachment.type == 'photo')
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Annotate',
                    onPressed: () => _annotateAttachment(attachment),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => setState(() => _attachments.remove(attachment)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final item = _UpdateAttachment(
      id: Uuid().v4(),
      type: 'photo',
      label: 'Photo',
      bytes: bytes,
      path: picked.path,
      filename: picked.name,
      fileSize: bytes.length,
      mimeType: _guessMimeType(picked.path) ?? 'image/jpeg',
      capturedAt: DateTime.now(),
    );
    setState(() => _attachments.add(item));
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picked = await _picker.pickVideo(source: source);
    if (picked == null) return;
    final size = await picked.length();
    final item = _UpdateAttachment(
      id: Uuid().v4(),
      type: 'video',
      label: 'Video',
      path: picked.path,
      filename: picked.name,
      fileSize: size,
      mimeType: _guessMimeType(picked.path) ?? 'video/mp4',
      capturedAt: DateTime.now(),
    );
    setState(() => _attachments.add(item));
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() => _recording = false);
      if (path == null) return;
      final size = await XFile(path).length();
      final item = _UpdateAttachment(
        id: Uuid().v4(),
        type: 'audio',
        label: 'Voice note',
        path: path,
        filename: p.basename(path),
        fileSize: size,
        mimeType: 'audio/m4a',
        capturedAt: DateTime.now(),
        metadata: const {'voiceNote': true},
      );
      if (!mounted) return;
      setState(() => _attachments.add(item));
      return;
    }

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
      'project_audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _recorder.start(const RecordConfig(), path: path);
    if (!mounted) return;
    setState(() => _recording = true);
  }

  Future<void> _annotateAttachment(_UpdateAttachment attachment) async {
    Uint8List? bytes = attachment.bytes;
    if (bytes == null && attachment.path != null) {
      bytes = await loadFileBytes(attachment.path!);
    }
    if (bytes == null) return;
    if (!mounted) return;
    final annotated = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => PhotoAnnotatorPage(imageBytes: bytes!, title: 'Annotate'),
      ),
    );
    if (!mounted) return;
    if (annotated == null) return;
    final updated = attachment.copyWith(
      bytes: annotated,
      filename: '${p.basenameWithoutExtension(attachment.filename ?? 'photo')}.png',
      mimeType: 'image/png',
      fileSize: annotated.length,
    );
    setState(() {
      final index = _attachments.indexOf(attachment);
      if (index != -1) _attachments[index] = updated;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_type != 'note' && _attachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one attachment.')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(projectsRepositoryProvider);
    try {
      final uploaded = await _uploadAttachments(_attachments);
      await repo.addUpdate(
        projectId: widget.project.id,
        type: _type,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        body: _bodyController.text.trim().isEmpty
            ? null
            : _bodyController.text.trim(),
        tags: _parseList(_tagsController.text),
        attachments: uploaded,
        isShared: _shareWithClient,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publish failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<MediaAttachment>> _uploadAttachments(
    List<_UpdateAttachment> items,
  ) async {
    if (items.isEmpty) return const [];
    final supabase = Supabase.instance.client;
    final orgId = await _getOrgId(supabase);
    final results = <MediaAttachment>[];
    for (final item in items) {
      var bytes = item.bytes;
      if (bytes == null && item.path != null) {
        bytes = await loadFileBytes(item.path!);
      }
      if (bytes == null) continue;
      final prefix = orgId != null ? 'org-$orgId' : 'public';
      final extension = _resolveExtension(item);
      final filename = item.filename?.trim().isNotEmpty == true
          ? item.filename!
          : '${item.type}_${item.id}$extension';
      final storagePath =
          '$prefix/projects/${widget.project.id}/${DateTime.now().microsecondsSinceEpoch}_$filename';
      await supabase.storage.from(_bucketName).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: item.mimeType,
            ),
          );
      final publicUrl =
          supabase.storage.from(_bucketName).getPublicUrl(storagePath);
      results.add(
        MediaAttachment(
          id: item.id,
          type: item.type,
          url: publicUrl,
          localPath: item.path,
          filename: filename,
          fileSize: item.fileSize ?? bytes.length,
          mimeType: item.mimeType,
          capturedAt: item.capturedAt,
          metadata: {
            'storagePath': storagePath,
            'bucket': _bucketName,
            ...?item.metadata,
          },
        ),
      );
    }
    return results;
  }

  Future<String?> _getOrgId(SupabaseClient client) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final res = await client
          .from('org_members')
          .select('org_id')
          .eq('user_id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    try {
      final res = await client
          .from('profiles')
          .select('org_id')
          .eq('id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    return null;
  }

  String _resolveExtension(_UpdateAttachment item) {
    final ext = p.extension(item.filename ?? item.path ?? '');
    if (ext.isNotEmpty) return ext;
    switch (item.type) {
      case 'photo':
        return '.png';
      case 'video':
        return '.mp4';
      case 'audio':
        return '.m4a';
      default:
        return '';
    }
  }

  String? _guessMimeType(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.m4a':
        return 'audio/m4a';
      case '.mp3':
        return 'audio/mpeg';
      default:
        return null;
    }
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
        return Icons.insert_drive_file;
    }
  }

  List<String> _parseList(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

class _UpdateAttachment {
  const _UpdateAttachment({
    required this.id,
    required this.type,
    required this.label,
    this.bytes,
    this.path,
    this.filename,
    this.fileSize,
    this.mimeType,
    required this.capturedAt,
    this.metadata,
  });

  final String id;
  final String type;
  final String label;
  final Uint8List? bytes;
  final String? path;
  final String? filename;
  final int? fileSize;
  final String? mimeType;
  final DateTime capturedAt;
  final Map<String, dynamic>? metadata;

  _UpdateAttachment copyWith({
    Uint8List? bytes,
    String? filename,
    int? fileSize,
    String? mimeType,
  }) {
    return _UpdateAttachment(
      id: id,
      type: type,
      label: label,
      bytes: bytes ?? this.bytes,
      path: path,
      filename: filename ?? this.filename,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      capturedAt: capturedAt,
      metadata: metadata,
    );
  }
}
