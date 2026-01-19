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

enum InspectionCaptureType { photo, video }

class InspectionEditorPage extends ConsumerStatefulWidget {
  const InspectionEditorPage({
    required this.asset,
    this.initialCapture,
    this.titleOverride,
    super.key,
  });

  final Equipment asset;
  final InspectionCaptureType? initialCapture;
  final String? titleOverride;

  @override
  ConsumerState<InspectionEditorPage> createState() =>
      _InspectionEditorPageState();
}

class _InspectionEditorPageState extends ConsumerState<InspectionEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final List<_AttachmentEntry> _attachments = [];

  String _status = 'pass';
  DateTime _inspectedAt = DateTime.now();
  LocationData? _location;
  bool _saving = false;
  bool _recording = false;
  bool _initialCaptureTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerInitialCapture());
  }

  @override
  void dispose() {
    if (_recording) {
      _recorder.stop();
    }
    _notesController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titleOverride ?? 'New Inspection')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'pass', child: Text('Pass')),
                  DropdownMenuItem(value: 'fail', child: Text('Fail')),
                  DropdownMenuItem(
                    value: 'maintenance',
                    child: Text('Needs maintenance'),
                  ),
                ],
                onChanged: (value) => setState(() => _status = value ?? 'pass'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('Inspected ${_formatDateTime(_inspectedAt)}'),
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
                label: Text(_saving ? 'Saving...' : 'Save inspection'),
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

  Future<void> _triggerInitialCapture() async {
    if (_initialCaptureTriggered || widget.initialCapture == null || kIsWeb) {
      return;
    }
    _initialCaptureTriggered = true;
    if (widget.initialCapture == InspectionCaptureType.photo) {
      await _pickPhoto(ImageSource.camera);
    } else if (widget.initialCapture == InspectionCaptureType.video) {
      await _pickVideo(ImageSource.camera);
    }
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
      'inspection_audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
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
        title: 'Inspection AI Assist',
        initialText: _notesController.text.trim(),
        initialType: 'walkthrough_notes',
        allowImage: true,
        initialAudioBytes: audioDraft?.bytes,
        initialAudioName: audioDraft?.filename,
        initialAudioMimeType: audioDraft?.mimeType,
      ),
    );
    if (result == null) return;
    final output = result.outputText.trim();
    if (output.isEmpty) return;
    setState(() => _notesController.text = output);
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
              'source': 'asset_inspection',
              'equipmentId': widget.asset.id,
              'status': _status,
              'inspectedAt': _inspectedAt.toIso8601String(),
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
      initialDate: _inspectedAt,
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_inspectedAt),
    );
    if (!mounted) return;
    setState(() {
      _inspectedAt = DateTime(
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
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(assetsRepositoryProvider);
      final inspection = await repo.createInspection(
        equipmentId: widget.asset.id,
        status: _status,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        inspectedAt: _inspectedAt,
        location: _location,
        attachments: _attachments.map((e) => e.draft).toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(inspection);
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
