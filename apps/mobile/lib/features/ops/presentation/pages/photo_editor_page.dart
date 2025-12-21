import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/file_bytes_loader.dart';
import '../../data/ops_provider.dart';
import '../../data/ops_repository.dart';

class PhotoEditorPage extends ConsumerStatefulWidget {
  const PhotoEditorPage({super.key, this.projectId});

  final String? projectId;

  @override
  ConsumerState<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends ConsumerState<PhotoEditorPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final List<_AttachmentEntry> _attachments = [];
  bool _saving = false;
  bool _recording = false;
  bool _shared = false;
  bool _featured = false;
  bool _before = false;
  bool _after = false;
  bool _logoSticker = false;

  @override
  void dispose() {
    if (_recording) {
      _recorder.stop();
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Photo Update')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Share with clients'),
              value: _shared,
              onChanged: (value) => setState(() => _shared = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Feature in gallery'),
              value: _featured,
              onChanged: (value) => setState(() => _featured = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Before photo'),
              value: _before,
              onChanged: (value) => setState(() {
                _before = value;
                if (value) _after = false;
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('After photo'),
              value: _after,
              onChanged: (value) => setState(() {
                _after = value;
                if (value) _before = false;
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Logo sticker applied'),
              value: _logoSticker,
              onChanged: (value) => setState(() => _logoSticker = value),
            ),
            const SizedBox(height: 12),
            Text('Attachments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Photo'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickVideo(ImageSource.camera),
                  icon: const Icon(Icons.videocam),
                  label: const Text('Video'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDualVideo,
                  icon: const Icon(Icons.switch_video),
                  label: const Text('Dual video'),
                ),
                OutlinedButton.icon(
                  onPressed: _toggleRecording,
                  icon: Icon(_recording ? Icons.stop : Icons.mic),
                  label: Text(_recording ? 'Stop audio' : 'Voice note'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('File'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_attachments.isNotEmpty) _buildAttachmentList(),
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
              label: Text(_saving ? 'Saving...' : 'Save update'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentList() {
    return Column(
      children: _attachments.map((entry) {
        return Card(
          child: ListTile(
            leading: Icon(_attachmentIcon(entry.draft.type)),
            title: Text(entry.label),
            subtitle: Text(entry.draft.filename),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => setState(() => _attachments.remove(entry)),
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
    _addAttachment(
      AttachmentDraft(
        type: 'photo',
        bytes: bytes,
        filename: picked.name,
        mimeType: _guessMimeType(picked.path) ?? 'image/jpeg',
      ),
      label: 'Photo',
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picked = await _picker.pickVideo(source: source);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    _addAttachment(
      AttachmentDraft(
        type: 'video',
        bytes: bytes,
        filename: picked.name,
        mimeType: _guessMimeType(picked.path) ?? 'video/mp4',
      ),
      label: 'Video',
    );
  }

  Future<void> _pickDualVideo() async {
    final pairId = const Uuid().v4();
    final first = await _picker.pickVideo(source: ImageSource.camera);
    if (first == null) return;
    final firstBytes = await first.readAsBytes();
    _addAttachment(
      AttachmentDraft(
        type: 'video',
        bytes: firstBytes,
        filename: first.name,
        mimeType: _guessMimeType(first.path) ?? 'video/mp4',
        metadata: {'dualMode': true, 'pairId': pairId, 'slot': 'primary'},
      ),
      label: 'Dual video (1/2)',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record second angle.')),
    );
    final second = await _picker.pickVideo(source: ImageSource.camera);
    if (second == null) return;
    final secondBytes = await second.readAsBytes();
    _addAttachment(
      AttachmentDraft(
        type: 'video',
        bytes: secondBytes,
        filename: second.name,
        mimeType: _guessMimeType(second.path) ?? 'video/mp4',
        metadata: {'dualMode': true, 'pairId': pairId, 'slot': 'secondary'},
      ),
      label: 'Dual video (2/2)',
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes ??
        (file.path != null ? await loadFileBytes(file.path!) : null);
    if (bytes == null) return;
    _addAttachment(
      AttachmentDraft(
        type: 'file',
        bytes: bytes,
        filename: file.name,
        mimeType: _guessMimeType(file.name) ?? 'application/octet-stream',
      ),
      label: 'File',
    );
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() => _recording = false);
      if (path == null) return;
      final bytes = await loadFileBytes(path);
      if (bytes == null) return;
      _addAttachment(
        AttachmentDraft(
          type: 'audio',
          bytes: bytes,
          filename: p.basename(path),
          mimeType: 'audio/m4a',
          metadata: const {'voiceNote': true},
        ),
        label: 'Voice note',
      );
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
      'photo_note_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _recorder.start(const RecordConfig(), path: path);
    if (!mounted) return;
    setState(() => _recording = true);
  }

  void _addAttachment(AttachmentDraft draft, {required String label}) {
    setState(() => _attachments.add(_AttachmentEntry(label: label, draft: draft)));
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(opsRepositoryProvider).createProjectPhoto(
            projectId: widget.projectId,
            title: _titleController.text.trim().isEmpty
                ? null
                : _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            attachments: _attachments.map((e) => e.draft).toList(),
            tags: _buildTags(),
            isFeatured: _featured,
            isShared: _shared,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
        return Icons.attach_file;
    }
  }

  List<String> _buildTags() {
    final tags = <String>[];
    final rawTags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty);
    tags.addAll(rawTags);
    if (_before) tags.add('before');
    if (_after) tags.add('after');
    if (_logoSticker) tags.add('logo_sticker');
    return tags.toSet().toList();
  }

  String? _guessMimeType(String filename) {
    final ext = p.extension(filename).toLowerCase();
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.heic':
        return 'image/heic';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.m4a':
        return 'audio/m4a';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.pdf':
        return 'application/pdf';
      default:
        return null;
    }
  }
}

class _AttachmentEntry {
  _AttachmentEntry({required this.label, required this.draft});

  final String label;
  final AttachmentDraft draft;
}
