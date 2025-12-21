import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../utils/file_bytes_loader.dart';
import 'ai_providers.dart';

class AiAssistResult {
  const AiAssistResult({
    required this.type,
    required this.inputText,
    required this.outputText,
    this.targetLanguage,
    this.checklistCount,
    this.imageBytes,
    this.imageName,
    this.imageMimeType,
    this.audioBytes,
    this.audioName,
    this.audioMimeType,
  });

  final String type;
  final String inputText;
  final String outputText;
  final String? targetLanguage;
  final int? checklistCount;
  final Uint8List? imageBytes;
  final String? imageName;
  final String? imageMimeType;
  final Uint8List? audioBytes;
  final String? audioName;
  final String? audioMimeType;
}

class AiAssistSheet extends ConsumerStatefulWidget {
  const AiAssistSheet({
    super.key,
    this.title = 'AI Assist',
    this.initialText = '',
    this.initialType,
    this.options,
    this.allowImage = true,
    this.allowAudio = true,
    this.initialAudioBytes,
    this.initialAudioName,
    this.initialAudioMimeType,
  });

  final String title;
  final String initialText;
  final String? initialType;
  final List<AiAssistOption>? options;
  final bool allowImage;
  final bool allowAudio;
  final Uint8List? initialAudioBytes;
  final String? initialAudioName;
  final String? initialAudioMimeType;

  @override
  ConsumerState<AiAssistSheet> createState() => _AiAssistSheetState();
}

class _AiAssistSheetState extends ConsumerState<AiAssistSheet> {
  static const int _maxMediaBytes = 8 * 1024 * 1024;
  late final List<AiAssistOption> _options;
  late String _type;
  late final TextEditingController _inputController;
  final TextEditingController _languageController =
      TextEditingController(text: 'Spanish');
  final TextEditingController _checklistController =
      TextEditingController(text: '8');
  final TextEditingController _outputController = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageMimeType;
  Uint8List? _audioBytes;
  String? _audioName;
  String? _audioMimeType;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _options = widget.options ?? AiAssistOption.defaults;
    _type = widget.initialType != null &&
            _options.any((opt) => opt.id == widget.initialType)
        ? widget.initialType!
        : _options.first.id;
    _inputController = TextEditingController(text: widget.initialText);
    if (widget.initialAudioBytes != null) {
      _audioBytes = widget.initialAudioBytes;
      _audioName = widget.initialAudioName;
      _audioMimeType = widget.initialAudioMimeType;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _languageController.dispose();
    _checklistController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _options.firstWhere((opt) => opt.id == _type);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'AI task',
                border: OutlineInputBorder(),
              ),
              items: _options
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.id,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inputController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Input text or notes',
                border: OutlineInputBorder(),
              ),
            ),
            if (selected.requiresLanguage) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _languageController,
                decoration: const InputDecoration(
                  labelText: 'Target language',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (selected.requiresChecklist) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _checklistController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Checklist item count',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (widget.allowImage && selected.allowsImage) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image),
                title: Text(_imageName ?? 'Attach photo (optional)'),
                subtitle:
                    _imageName == null ? const Text('Use for visual context.') : null,
                trailing: TextButton(
                  onPressed: _generating ? null : _pickImage,
                  child: const Text('Select'),
                ),
              ),
              if (_imageName != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _generating
                        ? null
                        : () => setState(() {
                              _imageBytes = null;
                              _imageName = null;
                              _imageMimeType = null;
                            }),
                    child: const Text('Remove image'),
                  ),
                ),
            ],
            if (widget.allowAudio && selected.allowsAudio) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mic),
                title: Text(_audioName ?? 'Attach audio (optional)'),
                subtitle: _audioName == null
                    ? const Text('Use for spoken notes.')
                    : null,
                trailing: TextButton(
                  onPressed: _generating ? null : _pickAudio,
                  child: const Text('Select'),
                ),
              ),
              if (_audioName != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _generating
                        ? null
                        : () => setState(() {
                              _audioBytes = null;
                              _audioName = null;
                              _audioMimeType = null;
                            }),
                    child: const Text('Remove audio'),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _generating ? null : _generate,
                    child: Text(_generating ? 'Generating...' : 'Generate'),
                  ),
                ),
              ],
            ),
            if (_outputController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _outputController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'AI output',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(
                        AiAssistResult(
                          type: _type,
                          inputText: _inputController.text.trim(),
                          outputText: _outputController.text.trim(),
                          targetLanguage: _languageController.text.trim(),
                          checklistCount:
                              int.tryParse(_checklistController.text.trim()),
                          imageBytes: _imageBytes,
                          imageName: _imageName,
                          imageMimeType: _imageMimeType,
                          audioBytes: _audioBytes,
                          audioName: _audioName,
                          audioMimeType: _audioMimeType,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Use output'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    final file = picked?.files.first;
    if (file == null) return;
    final bytes = file.bytes ??
        (file.path == null ? null : await loadFileBytes(file.path!));
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load image data.')),
      );
      return;
    }
    if (bytes.length > _maxMediaBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image is too large for AI processing.')),
      );
      return;
    }
    setState(() {
      _imageBytes = bytes;
      _imageName = file.name;
      _imageMimeType = _guessMimeType(file.name) ?? 'image/jpeg';
    });
  }

  Future<void> _pickAudio() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
      allowMultiple: false,
    );
    final file = picked?.files.first;
    if (file == null) return;
    final bytes = file.bytes ??
        (file.path == null ? null : await loadFileBytes(file.path!));
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load audio data.')),
      );
      return;
    }
    if (bytes.length > _maxMediaBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio file is too large.')),
      );
      return;
    }
    setState(() {
      _audioBytes = bytes;
      _audioName = file.name;
      _audioMimeType = _guessMimeType(file.name) ?? 'audio/m4a';
    });
  }

  Future<void> _generate() async {
    final input = _inputController.text.trim();
    if (input.isEmpty && _imageBytes == null && _audioBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provide notes or attach media.')),
      );
      return;
    }
    if ((_imageBytes?.length ?? 0) > _maxMediaBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image is too large for AI processing.')),
      );
      return;
    }
    if ((_audioBytes?.length ?? 0) > _maxMediaBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio file is too large.')),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      final ai = ref.read(aiJobRunnerProvider);
      final output = await ai.runJob(
        type: _type,
        inputText: input.isEmpty ? null : input,
        imageBytes: _imageBytes,
        audioBytes: _audioBytes,
        audioMimeType: _audioMimeType,
        targetLanguage: _languageController.text.trim().isEmpty
            ? null
            : _languageController.text.trim(),
        checklistCount: int.tryParse(_checklistController.text.trim()),
      );
      if (!mounted) return;
      setState(() {
        _outputController.text = output;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI failed: $e')),
      );
    }
  }
}

class AiAssistOption {
  const AiAssistOption({
    required this.id,
    required this.label,
    this.requiresLanguage = false,
    this.requiresChecklist = false,
    this.allowsImage = false,
    this.allowsAudio = false,
  });

  final String id;
  final String label;
  final bool requiresLanguage;
  final bool requiresChecklist;
  final bool allowsImage;
  final bool allowsAudio;

  static const defaults = [
    AiAssistOption(id: 'summary', label: 'Summary', allowsAudio: true),
    AiAssistOption(id: 'photo_caption', label: 'Photo caption', allowsImage: true),
    AiAssistOption(
      id: 'progress_recap',
      label: 'Progress recap',
      allowsAudio: true,
    ),
    AiAssistOption(
      id: 'translation',
      label: 'Translation',
      requiresLanguage: true,
      allowsAudio: true,
    ),
    AiAssistOption(
      id: 'checklist_builder',
      label: 'Checklist builder',
      requiresChecklist: true,
      allowsAudio: true,
    ),
    AiAssistOption(
      id: 'field_report',
      label: 'Field report',
      allowsImage: true,
      allowsAudio: true,
    ),
    AiAssistOption(
      id: 'walkthrough_notes',
      label: 'Walkthrough notes',
      allowsImage: true,
      allowsAudio: true,
    ),
    AiAssistOption(id: 'daily_log', label: 'Daily log', allowsAudio: true),
  ];
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
    case '.ogg':
      return 'audio/ogg';
    default:
      return null;
  }
}
