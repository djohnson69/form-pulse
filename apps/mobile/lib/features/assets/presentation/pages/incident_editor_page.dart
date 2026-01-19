import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared/shared.dart';

import '../../../../core/ai/ai_assist_sheet.dart';
import '../../../../core/utils/file_bytes_loader.dart';
import '../../../ops/data/ops_provider.dart';
import '../../../ops/data/ops_repository.dart' as ops_repo;
import '../../data/assets_provider.dart';
import '../../data/assets_repository.dart';

class IncidentEditorPage extends ConsumerStatefulWidget {
  const IncidentEditorPage({this.asset, super.key});

  final Equipment? asset;

  @override
  ConsumerState<IncidentEditorPage> createState() => _IncidentEditorPageState();
}

class _IncidentEditorPageState extends ConsumerState<IncidentEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final List<_AttachmentEntry> _attachments = [];

  String _severity = 'medium';
  DateTime _occurredAt = DateTime.now();
  LocationData? _location;
  bool _saving = false;
  bool _recording = false;

  @override
  void dispose() {
    if (_recording) {
      _recorder.stop();
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Incident')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Incident title',
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
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _openAiAssist,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI Assist'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                decoration: const InputDecoration(
                  labelText: 'Severity',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'critical', child: Text('Critical')),
                ],
                onChanged: (value) =>
                    setState(() => _severity = value ?? 'medium'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('Occurred ${_formatDateTime(_occurredAt)}'),
                trailing: TextButton(
                  onPressed: _pickDateTime,
                  child: const Text('Edit'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on),
                title: Text(
                  _location == null
                      ? 'No location added'
                      : '${_location!.latitude}, ${_location!.longitude}',
                ),
                trailing: TextButton(
                  onPressed: _setLocation,
                  child: const Text('Use GPS'),
                ),
              ),
              const SizedBox(height: 12),
              Text('Attachments', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!kIsWeb) ...[
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
                      onPressed: _toggleRecording,
                      icon: Icon(_recording ? Icons.stop : Icons.mic),
                      label: Text(_recording ? 'Stop audio' : 'Record audio'),
                    ),
                  ],
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
                label: Text(_saving ? 'Saving...' : 'Save incident'),
              ),
            ],
          ),
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
        label: 'Audio note',
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
      'incident_audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _recorder.start(const RecordConfig(), path: path);
    if (!mounted) return;
    setState(() => _recording = true);
  }

  void _addAttachment(AttachmentDraft draft, {required String label}) {
    setState(() => _attachments.add(_AttachmentEntry(label: label, draft: draft)));
  }

  Future<void> _openAiAssist() async {
    final audioDraft = _latestAudioDraft();
    final result = await showModalBottomSheet<AiAssistResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AiAssistSheet(
        title: 'Incident AI Assist',
        initialText: _descriptionController.text.trim(),
        initialType: 'field_report',
        allowImage: true,
        initialAudioBytes: audioDraft?.bytes,
        initialAudioName: audioDraft?.filename,
        initialAudioMimeType: audioDraft?.mimeType,
      ),
    );
    if (result == null) return;
    final output = result.outputText.trim();
    if (output.isEmpty) return;
    setState(() => _descriptionController.text = output);
    await _recordAiUsage(result);
  }

  Future<void> _recordAiUsage(AiAssistResult result) async {
    try {
      final attachments = <ops_repo.AttachmentDraft>[];
      if (result.imageBytes != null) {
        attachments.add(
          ops_repo.AttachmentDraft(
            type: 'photo',
            bytes: result.imageBytes!,
            filename: result.imageName ?? 'ai-image',
            mimeType: result.imageMimeType ?? 'image/jpeg',
          ),
        );
      }
      if (result.audioBytes != null) {
        attachments.add(
          ops_repo.AttachmentDraft(
            type: 'audio',
            bytes: result.audioBytes!,
            filename: result.audioName ?? 'ai-audio',
            mimeType: result.audioMimeType ?? 'audio/m4a',
          ),
        );
      }
      await ref.read(opsRepositoryProvider).createAiJob(
            type: result.type,
            inputText: result.inputText.isEmpty ? null : result.inputText,
            outputText: result.outputText,
            inputMedia: attachments,
            metadata: {
              'source': 'incident_report',
              if (widget.asset != null) 'equipmentId': widget.asset!.id,
              'severity': _severity,
              'occurredAt': _occurredAt.toIso8601String(),
              'hasLocation': _location != null,
            },
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI log failed: $e')),
      );
    }
  }

  AttachmentDraft? _latestAudioDraft() {
    for (var i = _attachments.length - 1; i >= 0; i--) {
      final draft = _attachments[i].draft;
      if (draft.type == 'audio') return draft;
    }
    return null;
  }

  Future<void> _pickDateTime() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _occurredAt,
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (!mounted) return;
    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      );
    });
  }

  Future<void> _setLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    final position = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(
      () => _location = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(assetsRepositoryProvider);
      final incident = await repo.createIncident(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        severity: _severity,
        equipmentId: widget.asset?.id,
        occurredAt: _occurredAt,
        location: _location,
        attachments: _attachments.map((e) => e.draft).toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(incident);
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

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
