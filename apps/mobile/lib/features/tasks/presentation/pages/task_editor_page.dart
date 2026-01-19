import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../teams/data/teams_provider.dart';
import '../../data/tasks_provider.dart';
import '../../data/tasks_repository.dart';

final _teamMemberCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final teams = await ref.watch(teamsProvider.future);
  if (teams.isEmpty) return const {};
  final teamIds = teams.map((team) => team.id).toList();
  if (teamIds.isEmpty) return const {};
  try {
    final rows = await Supabase.instance.client
        .from('team_members')
        .select('team_id')
        .inFilter('team_id', teamIds);
    final teamNameById = {
      for (final team in teams) team.id: team.name,
    };
    final counts = {
      for (final team in teams) team.name.toLowerCase(): 0,
    };
    for (final row in rows as List<dynamic>) {
      final data = Map<String, dynamic>.from(row as Map);
      final teamId = data['team_id']?.toString();
      final teamName = teamId == null ? null : teamNameById[teamId];
      if (teamName == null) continue;
      final key = teamName.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  } catch (_) {
    return const {};
  }
});

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
  final _locationController = TextEditingController();
  DateTime? _dueDate;
  String _priority = 'medium';
  String _category = 'Safety';
  String? _assigneeId;
  String? _assigneeName;
  String? _assignedTeam;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      final metadata = existing.metadata ?? const <String, dynamic>{};
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
      _dueDate = existing.dueDate;
      _priority = _normalizePriority(existing.priority ?? 'medium');
      _category =
          _normalizeCategory(metadata['category']?.toString() ?? 'Safety');
      _locationController.text = metadata['location']?.toString() ?? '';
      _assigneeId = existing.assignedTo;
      _assigneeName = existing.assignedToName;
      _assignedTeam = existing.assignedTeam;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assigneesAsync = ref.watch(taskAssigneesProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final teamCountsAsync = ref.watch(_teamMemberCountsProvider);
    final isEditing = widget.existing != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.grey[300] : Colors.grey[700],
    );
    final assignees = assigneesAsync.asData?.value ?? const <TaskAssignee>[];
    final teams = teamsAsync.asData?.value ?? const <Team>[];
    final teamMemberCounts =
        teamCountsAsync.asData?.value ?? const <String, int>{};

    Widget labeledField(String label, Widget field) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 8),
          field,
        ],
      );
    }

    final dateField = InkWell(
      onTap: _saving ? null : _pickDueDate,
      child: InputDecorator(
        decoration: const InputDecoration(border: OutlineInputBorder()),
        child: Text(
          _dueDate == null ? 'Select date' : _formatDate(_dueDate!),
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );

    List<DropdownMenuItem<String?>> assigneeItems() {
      final items = assignees
          .map(
            (assignee) => DropdownMenuItem<String?>(
              value: assignee.id,
              child: Text(assignee.name),
            ),
          )
          .toList();
      final hasSelected = _assigneeId != null &&
          assignees.any((assignee) => assignee.id == _assigneeId);
      if (_assigneeId != null && !hasSelected) {
        items.insert(
          0,
          DropdownMenuItem<String?>(
            value: _assigneeId,
            child: Text(_assigneeName ?? 'Assigned user'),
          ),
        );
      }
      return items;
    }

    List<DropdownMenuItem<String>> teamItems() {
      final items = teams
          .map(
            (team) => DropdownMenuItem<String>(
              value: team.name,
              child: Text(
                '${team.name} (${teamMemberCounts[team.name.toLowerCase()] ?? 0} members)',
              ),
            ),
          )
          .toList();
      if (_assignedTeam != null &&
          !teams.any((team) => team.name == _assignedTeam)) {
        items.insert(
          0,
          DropdownMenuItem<String>(
            value: _assignedTeam,
            child: Text(_assignedTeam ?? 'Assigned team'),
          ),
        );
      }
      return items;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Task' : 'Create New Task',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      labeledField(
                        'Task Title',
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: 'Enter task title',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Title is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      labeledField(
                        'Description',
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            hintText: 'Enter task description',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 600;
                          final assigneeField = labeledField(
                            'Assign to Individual',
                            DropdownButtonFormField<String?>(
                              value: _assigneeId,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              hint: const Text('Select individual...'),
                              items: assigneeItems(),
                              onChanged: (value) {
                                if (value == null) {
                                  setState(() {
                                    _assigneeId = null;
                                    _assigneeName = null;
                                  });
                                  return;
                                }
                                final selected = assignees.firstWhere(
                                  (assignee) => assignee.id == value,
                                  orElse: () => TaskAssignee(
                                    id: value,
                                    name: _assigneeName ?? 'Assigned user',
                                  ),
                                );
                                setState(() {
                                  _assigneeId = value;
                                  _assigneeName = selected.name;
                                });
                              },
                            ),
                          );
                          final teamField = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              labeledField(
                                'Assign to Team',
                                DropdownButtonFormField<String>(
                                  value: _assignedTeam,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                  ),
                                  hint: Text(
                                    teams.isEmpty
                                        ? 'No teams available'
                                        : 'Select team (optional)...',
                                  ),
                                  items: teamItems(),
                                  onChanged: teams.isEmpty
                                      ? null
                                      : (value) =>
                                          setState(() => _assignedTeam = value),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Team assignment enables collaboration and shared progress tracking',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          );
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: assigneeField),
                                const SizedBox(width: 16),
                                Expanded(child: teamField),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              assigneeField,
                              const SizedBox(height: 12),
                              teamField,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 600;
                          final priorityField = labeledField(
                            'Priority',
                            DropdownButtonFormField<String>(
                              value: _priority,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'high',
                                  child: Text('High'),
                                ),
                                DropdownMenuItem(
                                  value: 'medium',
                                  child: Text('Medium'),
                                ),
                                DropdownMenuItem(
                                  value: 'low',
                                  child: Text('Low'),
                                ),
                              ],
                              onChanged: (value) => setState(
                                () => _priority = value ?? 'medium',
                              ),
                            ),
                          );
                          final dueDateField = labeledField('Due Date', dateField);
                          final categoryField = labeledField(
                            'Category',
                            DropdownButtonFormField<String>(
                              value: _category,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Safety',
                                  child: Text('Safety'),
                                ),
                                DropdownMenuItem(
                                  value: 'Maintenance',
                                  child: Text('Maintenance'),
                                ),
                                DropdownMenuItem(
                                  value: 'Installation',
                                  child: Text('Installation'),
                                ),
                                DropdownMenuItem(
                                  value: 'Quality',
                                  child: Text('Quality'),
                                ),
                                DropdownMenuItem(
                                  value: 'Reporting',
                                  child: Text('Reporting'),
                                ),
                              ],
                              onChanged: (value) => setState(
                                () => _category = value ?? 'Safety',
                              ),
                            ),
                          );
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: priorityField),
                                const SizedBox(width: 16),
                                Expanded(child: dueDateField),
                                const SizedBox(width: 16),
                                Expanded(child: categoryField),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              priorityField,
                              const SizedBox(height: 12),
                              dueDateField,
                              const SizedBox(height: 12),
                              categoryField,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      labeledField(
                        'Location',
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            hintText: 'Enter task location',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(height: 1, color: border),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.track_changes, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Milestones (Optional)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add milestones to track progress and receive proactive reminders',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add),
                        label: const Text('Add Milestone'),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving ? null : _submit,
                              child: Text(
                                _saving
                                    ? 'Saving...'
                                    : (isEditing
                                        ? 'Save Task'
                                        : 'Create Task'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).maybePop(),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      final location = _locationController.text.trim();
      final assignedTeam = _assignedTeam == null || _assignedTeam!.trim().isEmpty
          ? null
          : _assignedTeam;
      final metadata = <String, dynamic>{
        'location': location,
        'category': _category,
      };
      if (widget.existing == null) {
        task = await repo.createTask(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          dueDate: _dueDate,
          priority: _priority,
          assignedTo: _assigneeId,
          assignedToName: _assigneeName,
          assignedTeam: assignedTeam,
          metadata: metadata,
        );
      } else {
        final existingMetadata =
            Map<String, dynamic>.from(widget.existing?.metadata ?? {});
        existingMetadata.addAll(metadata);
        task = await repo.updateTask(
          taskId: widget.existing!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          dueDate: _dueDate,
          priority: _priority,
          assignedTo: _assigneeId,
          assignedToName: _assigneeName,
          assignedTeam: assignedTeam,
          metadata: existingMetadata,
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

  String _normalizePriority(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'normal') return 'medium';
    if (value == 'urgent') return 'high';
    if (value == 'low' || value == 'medium' || value == 'high') {
      return value;
    }
    return 'medium';
  }

  String _normalizeCategory(String raw) {
    const options = [
      'Safety',
      'Maintenance',
      'Installation',
      'Quality',
      'Reporting',
    ];
    for (final option in options) {
      if (option.toLowerCase() == raw.toLowerCase()) {
        return option;
      }
    }
    return 'Safety';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}
