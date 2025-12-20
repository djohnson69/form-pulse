import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
