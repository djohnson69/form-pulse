import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/ai/ai_assist_sheet.dart';
import '../../../../core/ai/ai_parsers.dart';
import '../../../ops/data/ops_provider.dart';
import '../../../ops/data/ops_repository.dart' as ops_repo;
import '../../../teams/data/teams_provider.dart';
import '../../data/tasks_provider.dart';
import '../../data/tasks_repository.dart';

class TaskEditorPage extends ConsumerStatefulWidget {
  const TaskEditorPage({this.existing, super.key});

  final Task? existing;

  @override
  ConsumerState<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends ConsumerState<TaskEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _teamController = TextEditingController();
  DateTime? _dueDate;
  String _priority = 'normal';
  String? _assigneeId;
  String? _assigneeName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
      _instructionsController.text = existing.instructions ?? '';
      _teamController.text = existing.assignedTeam ?? '';
      _dueDate = existing.dueDate;
      _priority = existing.priority ?? 'normal';
      _assigneeId = existing.assignedTo;
      _assigneeName = existing.assignedToName;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _teamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assigneesAsync = ref.watch(taskAssigneesProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Task' : 'New Task')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task title',
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
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructionsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
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
              assigneesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Assignees unavailable: $e'),
                data: (assignees) {
                  final options = _buildAssigneeOptions(assignees);
                  return DropdownButtonFormField<String?>(
                    initialValue: _assigneeId,
                    decoration: const InputDecoration(
                      labelText: 'Assign to',
                      border: OutlineInputBorder(),
                    ),
                    items: options
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.id,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      final selected =
                          options.firstWhere((o) => o.id == value);
                      setState(() {
                        _assigneeId = selected.id;
                        _assigneeName = selected.name;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _teamController,
                decoration: const InputDecoration(
                  labelText: 'Assign to team (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              teamsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (teams) {
                  if (teams.isEmpty) return const SizedBox.shrink();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: teams
                        .map(
                          (team) => ActionChip(
                            label: Text(team.name),
                            onPressed: () {
                              setState(() => _teamController.text = team.name);
                            },
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (value) => setState(() => _priority = value ?? 'normal'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _dueDate == null
                      ? 'No due date'
                      : _formatDate(_dueDate!),
                ),
                trailing: TextButton(
                  onPressed: _pickDueDate,
                  child: const Text('Select'),
                ),
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
                label: Text(_saving ? 'Saving...' : 'Save task'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_AssigneeOption> _buildAssigneeOptions(List<TaskAssignee> assignees) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final options = <_AssigneeOption>[
      const _AssigneeOption(id: null, label: 'Unassigned', name: null),
      if (currentUser != null)
        _AssigneeOption(
          id: currentUser.id,
          label: 'Assign to me',
          name: currentUser.email,
        ),
    ];
    options.addAll(
      assignees
          .where((assignee) => assignee.id != currentUser?.id)
          .map(
            (assignee) => _AssigneeOption(
              id: assignee.id,
              label: assignee.name,
              name: assignee.name,
            ),
          ),
    );
    if (_assigneeId != null &&
        !options.any((option) => option.id == _assigneeId)) {
      options.add(
        _AssigneeOption(
          id: _assigneeId,
          label: _assigneeName ?? 'Assigned user',
          name: _assigneeName,
        ),
      );
    }
    if (_assigneeId == null) {
      _assigneeName = null;
    }
    return options;
  }

  Future<void> _pickDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (selected == null) return;
    setState(() => _dueDate = selected);
  }

  Future<void> _openAiAssist() async {
    final result = await showModalBottomSheet<AiAssistResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AiAssistSheet(
        title: 'AI Task Builder',
        initialText: _buildAiInput(),
        initialType: 'checklist_builder',
        options: const [
          AiAssistOption(id: 'summary', label: 'Summary', allowsAudio: true),
          AiAssistOption(
            id: 'checklist_builder',
            label: 'Checklist builder',
            requiresChecklist: true,
            allowsAudio: true,
          ),
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
    final firstSuggestion = _suggestTitle(output);
    setState(() {
      if (_titleController.text.trim().isEmpty && firstSuggestion.isNotEmpty) {
        _titleController.text = firstSuggestion;
      }
      if (_descriptionController.text.trim().isEmpty &&
          firstSuggestion.isNotEmpty) {
        _descriptionController.text = firstSuggestion;
      }
      _instructionsController.text = output;
    });
    await _recordAiUsage(result);
  }

  String _buildAiInput() {
    final parts = <String>[];
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final instructions = _instructionsController.text.trim();
    if (title.isNotEmpty) parts.add('Title: $title');
    if (description.isNotEmpty) parts.add('Description: $description');
    if (instructions.isNotEmpty) parts.add('Instructions: $instructions');
    return parts.isEmpty ? '' : parts.join('\n');
  }

  String _suggestTitle(String output) {
    final items = parseChecklistItems(output);
    if (items.isNotEmpty) return items.first;
    final firstLine = output.split('\n').first.trim();
    return firstLine;
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
              'source': 'task_editor',
              'priority': _priority,
              if (_dueDate != null) 'dueDate': _dueDate!.toIso8601String(),
              if (result.targetLanguage != null &&
                  result.targetLanguage!.isNotEmpty)
                'targetLanguage': result.targetLanguage,
              if (result.checklistCount != null)
                'checklistCount': result.checklistCount,
            },
          );
    } catch (_) {
      // Ignore AI logging failures for task assist.
    }
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(tasksRepositoryProvider);
    try {
      Task task;
      if (widget.existing == null) {
        task = await repo.createTask(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          instructions: _instructionsController.text.trim().isEmpty
              ? null
              : _instructionsController.text.trim(),
          dueDate: _dueDate,
          priority: _priority,
          assignedTo: _assigneeId,
          assignedToName: _assigneeName,
          assignedTeam:
              _teamController.text.trim().isEmpty ? null : _teamController.text.trim(),
        );
      } else {
        task = await repo.updateTask(
          taskId: widget.existing!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          instructions: _instructionsController.text.trim(),
          dueDate: _dueDate,
          priority: _priority,
          assignedTo: _assigneeId,
          assignedToName: _assigneeName,
          assignedTeam: _teamController.text.trim().isEmpty
              ? null
              : _teamController.text.trim(),
        );
      }
      if (!mounted) return;
      ref.invalidate(tasksProvider);
      Navigator.pop(context, task);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}

class _AssigneeOption {
  const _AssigneeOption({
    required this.id,
    required this.label,
    required this.name,
  });

  final String? id;
  final String label;
  final String? name;
}
