import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/ai/ai_job_runner.dart';
import '../../../../core/ai/ai_providers.dart';
import '../../../../core/utils/file_bytes_loader.dart';
import '../../data/ops_provider.dart';
import '../../data/ops_repository.dart';

class AiToolsPage extends ConsumerStatefulWidget {
  const AiToolsPage({super.key});

  static const int _maxAiMediaBytes = 8 * 1024 * 1024;

  @override
  ConsumerState<AiToolsPage> createState() => _AiToolsPageState();
}

class _AiToolsPageState extends ConsumerState<AiToolsPage> {
  RealtimeChannel? _aiJobsChannel;

  @override
  void initState() {
    super.initState();
    _subscribeToAiJobs();
  }

  @override
  void dispose() {
    _aiJobsChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToAiJobs() {
    final client = Supabase.instance.client;
    _aiJobsChannel = client.channel('ai-jobs')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'ai_jobs',
        callback: (_) {
          if (!mounted) return;
          ref.invalidate(aiJobsProvider);
        },
      )
      ..subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(aiJobsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Tools')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New AI job'),
      ),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(child: Text('No AI jobs yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(_labelForType(job.type)),
                  subtitle: Text(job.outputText ?? job.status),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final inputController = TextEditingController();
    final languageController = TextEditingController(text: 'Spanish');
    final checklistCountController = TextEditingController(text: '8');
    Uint8List? imageBytes;
    String? imageName;
    String? imageMime;
    String? imagePath;
    Uint8List? audioBytes;
    String? audioName;
    String? audioMime;
    String? audioPath;
    String type = _aiJobOptions.first.id;
    bool isSaving = false;
    final aiRunner = _resolveAiService(ref);
    final hasAi = aiRunner != null;
    final hasFallback = aiRunner?.hasDirectFallback ?? false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Create AI job',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (!hasAi)
                    const Text(
                      'AI service is unavailable. Confirm Supabase is initialized and the AI function is deployed.',
                    )
                  else if (!hasFallback)
                    const Text(
                      'AI runs via the Supabase ai function. For client fallback, set OPENAI_API_KEY and OPENAI_CLIENT_FALLBACK=true.',
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _aiJobOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.id,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => type = value ?? _aiJobOptions.first.id),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: inputController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Input text or notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_requiresLanguage(type))
                    TextField(
                      controller: languageController,
                      decoration: const InputDecoration(
                        labelText: 'Target language',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (_requiresLanguage(type)) const SizedBox(height: 12),
                  if (_isChecklist(type))
                    TextField(
                      controller: checklistCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Checklist item count',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (_isChecklist(type)) const SizedBox(height: 12),
                  if (_allowsImage(type))
                    Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.image),
                          title: Text(imageName ?? 'Attach photo (optional)'),
                          subtitle: imageName == null
                              ? const Text('Use for captions, reports, and notes.')
                              : Text(imageMime ?? 'image'),
                          trailing: TextButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final picked = await FilePicker.platform.pickFiles(
                                      type: FileType.image,
                                      withData: true,
                                      allowMultiple: false,
                                    );
                                    final file = picked?.files.first;
                                    if (file == null) return;
                                    final bytes = file.bytes ??
                                        (file.path == null
                                            ? null
                                            : await loadFileBytes(file.path!));
                                    if (bytes == null) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Unable to load image data.'),
                                        ),
                                      );
                                      return;
                                    }
                                    if (bytes.length > AiToolsPage._maxAiMediaBytes) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Image is too large.'),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() {
                                      imageBytes = bytes;
                                      imageName = file.name;
                                      imageMime = _guessMimeType(file.name) ??
                                          'image/jpeg';
                                      imagePath = file.path;
                                    });
                                  },
                            child: const Text('Select'),
                          ),
                        ),
                        if (imageName != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => setState(() {
                                        imageBytes = null;
                                        imageName = null;
                                        imageMime = null;
                                        imagePath = null;
                                      }),
                              child: const Text('Remove image'),
                            ),
                          ),
                      ],
                    ),
                  if (_allowsImage(type)) const SizedBox(height: 12),
                  if (_allowsAudio(type))
                    Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.mic),
                          title: Text(audioName ?? 'Attach audio (optional)'),
                          subtitle: audioName == null
                              ? const Text('Use for spoken notes.')
                              : Text(audioMime ?? 'audio'),
                          trailing: TextButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final picked =
                                        await FilePicker.platform.pickFiles(
                                      type: FileType.audio,
                                      withData: true,
                                      allowMultiple: false,
                                    );
                                    final file = picked?.files.first;
                                    if (file == null) return;
                                    final bytes = file.bytes ??
                                        (file.path == null
                                            ? null
                                            : await loadFileBytes(file.path!));
                                    if (bytes == null) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Unable to load audio data.'),
                                        ),
                                      );
                                      return;
                                    }
                                    if (bytes.length > AiToolsPage._maxAiMediaBytes) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Audio file is too large.'),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() {
                                      audioBytes = bytes;
                                      audioName = file.name;
                                      audioMime = _guessMimeType(file.name) ??
                                          'audio/m4a';
                                      audioPath = file.path;
                                    });
                                  },
                            child: const Text('Select'),
                          ),
                        ),
                        if (audioName != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => setState(() {
                                        audioBytes = null;
                                        audioName = null;
                                        audioMime = null;
                                        audioPath = null;
                                      }),
                              child: const Text('Remove audio'),
                            ),
                          ),
                      ],
                    ),
                  if (_allowsAudio(type)) const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final ai = aiRunner;
                            if (ai == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('AI service is unavailable.'),
                                ),
                              );
                              return;
                            }
                            final text = inputController.text.trim();
                            if (text.isEmpty &&
                                imageBytes == null &&
                                audioBytes == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Provide notes or attach media.'),
                                ),
                              );
                              return;
                            }
                            if ((imageBytes?.length ?? 0) >
                                AiToolsPage._maxAiMediaBytes) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Image is too large.'),
                                ),
                              );
                              return;
                            }
                            if ((audioBytes?.length ?? 0) >
                                AiToolsPage._maxAiMediaBytes) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Audio file is too large.'),
                                ),
                              );
                              return;
                            }
                            setState(() => isSaving = true);
                            try {
                              final output = await ai.runJob(
                                type: type,
                                inputText: text.isEmpty ? null : text,
                                imageBytes: imageBytes,
                                audioBytes: audioBytes,
                                audioMimeType: audioMime,
                                targetLanguage: languageController.text.trim(),
                                checklistCount: int.tryParse(
                                  checklistCountController.text.trim(),
                                ),
                              );
                              final attachments = <AttachmentDraft>[];
                              if (imageBytes != null) {
                                attachments.add(
                                  AttachmentDraft(
                                    type: 'photo',
                                    bytes: imageBytes!,
                                    filename: imageName ?? 'ai-image',
                                    mimeType: imageMime ?? 'image/jpeg',
                                    metadata: {
                                      if (imagePath != null) 'path': imagePath,
                                    },
                                  ),
                                );
                              }
                              if (audioBytes != null) {
                                attachments.add(
                                  AttachmentDraft(
                                    type: 'audio',
                                    bytes: audioBytes!,
                                    filename: audioName ?? 'ai-audio',
                                    mimeType: audioMime ?? 'audio/m4a',
                                    metadata: {
                                      if (audioPath != null) 'path': audioPath,
                                    },
                                  ),
                                );
                              }
                              await ref.read(opsRepositoryProvider).createAiJob(
                                    type: type,
                                    inputText: text.isEmpty ? null : text,
                                    outputText: output,
                                    inputMedia: attachments,
                                    metadata: {
                                      'targetLanguage':
                                          languageController.text.trim().isEmpty
                                              ? null
                                              : languageController.text.trim(),
                                      'checklistCount': int.tryParse(
                                        checklistCountController.text.trim(),
                                      ),
                                      'hasImage': imageBytes != null,
                                      'hasAudio': audioBytes != null,
                                    },
                                  );
                              if (context.mounted) {
                                Navigator.of(context).pop(true);
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('AI failed: $e')),
                              );
                              setState(() => isSaving = false);
                            }
                          },
                    child: Text(isSaving ? 'Saving...' : 'Generate'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    inputController.dispose();
    languageController.dispose();
    checklistCountController.dispose();
    if (result == true) {
      ref.invalidate(aiJobsProvider);
    }
  }

  AiJobRunner? _resolveAiService(WidgetRef ref) {
    try {
      return ref.read(aiJobRunnerProvider);
    } catch (_) {
      return null;
    }
  }
}

class _AiJobOption {
  const _AiJobOption({required this.id, required this.label});

  final String id;
  final String label;
}

const _aiJobOptions = [
  _AiJobOption(id: 'summary', label: 'Summary'),
  _AiJobOption(id: 'photo_caption', label: 'Photo caption'),
  _AiJobOption(id: 'progress_recap', label: 'Progress recap'),
  _AiJobOption(id: 'translation', label: 'Translation'),
  _AiJobOption(id: 'checklist_builder', label: 'Checklist builder'),
  _AiJobOption(id: 'field_report', label: 'Field report'),
  _AiJobOption(id: 'walkthrough_notes', label: 'Walkthrough notes'),
  _AiJobOption(id: 'daily_log', label: 'Daily log'),
];

String _labelForType(String type) {
  for (final option in _aiJobOptions) {
    if (option.id == type) return option.label;
  }
  switch (type) {
    case 'caption':
      return 'Photo caption';
    case 'recap':
      return 'Progress recap';
    case 'checklist':
      return 'Checklist builder';
    default:
      break;
  }
  return type.replaceAll('_', ' ');
}

bool _requiresLanguage(String type) => type == 'translation';

bool _isChecklist(String type) => type == 'checklist_builder';

bool _allowsImage(String type) =>
    type == 'photo_caption' || type == 'field_report' || type == 'walkthrough_notes';

bool _allowsAudio(String type) =>
    type == 'field_report' ||
    type == 'walkthrough_notes' ||
    type == 'daily_log' ||
    type == 'summary' ||
    type == 'progress_recap' ||
    type == 'translation' ||
    type == 'checklist_builder';

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
