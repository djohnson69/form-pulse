import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../../core/ai/ai_assist_sheet.dart';
import '../../data/ops_provider.dart';
import '../../data/ops_repository.dart' as ops_repo;
import '../../../projects/data/projects_provider.dart';

class NotebookEditorPage extends ConsumerStatefulWidget {
  const NotebookEditorPage({super.key, this.existing});

  final NotebookPage? existing;

  @override
  ConsumerState<NotebookEditorPage> createState() => _NotebookEditorPageState();
}

class _NotebookEditorPageState extends ConsumerState<NotebookEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _projectId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _bodyController.text = existing.body ?? '';
      _projectId = existing.projectId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Page' : 'New Page')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
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
                controller: _bodyController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _openAiAssist,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI Assist'),
                ),
              ),
              const SizedBox(height: 12),
              projectsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
                data: (projects) {
                  return DropdownButtonFormField<String?>(
                    initialValue: _projectId,
                    decoration: const InputDecoration(
                      labelText: 'Project (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No project'),
                      ),
                      ...projects.map((project) {
                        return DropdownMenuItem<String?>(
                          value: project.id,
                          child: Text(project.name),
                        );
                      }),
                    ],
                    onChanged: (value) => setState(() => _projectId = value),
                  );
                },
              ),
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
                label: Text(_saving ? 'Saving...' : 'Save page'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(opsRepositoryProvider);
      final existing = widget.existing;
      if (existing == null) {
        await repo.createNotebookPage(
          title: _titleController.text.trim(),
          body: _bodyController.text.trim().isEmpty
              ? null
              : _bodyController.text.trim(),
          projectId: _projectId,
          tags: const [],
        );
      } else {
        await repo.updateNotebookPage(
          pageId: existing.id,
          title: _titleController.text.trim(),
          body: _bodyController.text.trim().isEmpty
              ? null
              : _bodyController.text.trim(),
        );
      }
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

  Future<void> _openAiAssist() async {
    final result = await showModalBottomSheet<AiAssistResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AiAssistSheet(
        title: 'AI Notebook Assist',
        initialText: _bodyController.text.trim(),
        initialType: 'summary',
        options: const [
          AiAssistOption(id: 'summary', label: 'Summary', allowsAudio: true),
          AiAssistOption(
            id: 'field_report',
            label: 'Field report',
            allowsAudio: true,
          ),
          AiAssistOption(
            id: 'walkthrough_notes',
            label: 'Walkthrough notes',
            allowsAudio: true,
          ),
          AiAssistOption(id: 'daily_log', label: 'Daily log', allowsAudio: true),
          AiAssistOption(
            id: 'translation',
            label: 'Translation',
            requiresLanguage: true,
            allowsAudio: true,
          ),
        ],
        allowImage: false,
        allowAudio: true,
      ),
    );
    if (result == null) return;
    final output = result.outputText.trim();
    if (output.isEmpty) return;
    if (!mounted) return;
    setState(() => _bodyController.text = output);
    await _recordAiUsage(result);
  }

  Future<void> _recordAiUsage(AiAssistResult result) async {
    try {
      final attachments = <ops_repo.AttachmentDraft>[];
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
              'source': 'notebook_editor',
              if (_projectId != null) 'projectId': _projectId!,
              if (result.targetLanguage != null &&
                  result.targetLanguage!.isNotEmpty)
                'targetLanguage': result.targetLanguage,
              if (result.checklistCount != null)
                'checklistCount': result.checklistCount,
            },
          );
    } catch (_) {
      // Ignore AI logging failures for notebook assist.
    }
  }
}
