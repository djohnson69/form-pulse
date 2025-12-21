import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/templates_provider.dart';
import '../../../tasks/data/tasks_provider.dart';
import '../../../tasks/data/tasks_repository.dart';
import 'template_editor_page.dart';

class TemplatesPage extends ConsumerStatefulWidget {
  const TemplatesPage({super.key});

  @override
  ConsumerState<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends ConsumerState<TemplatesPage> {
  String _type = 'all';

  @override
  Widget build(BuildContext context) {
    final typeFilter = _type == 'all' ? null : _type;
    final templatesAsync = ref.watch(templatesProvider(typeFilter));
    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('New template'),
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (templates) {
          if (templates.isEmpty) {
            return const Center(child: Text('No templates yet.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'workflow', child: Text('Workflow')),
                  DropdownMenuItem(value: 'checklist', child: Text('Checklist')),
                  DropdownMenuItem(value: 'project', child: Text('Project')),
                  DropdownMenuItem(value: 'report', child: Text('Report')),
                ],
                onChanged: (value) => setState(() => _type = value ?? 'all'),
              ),
              const SizedBox(height: 16),
              ...templates.map((template) => _TemplateCard(template: template)),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TemplateEditorPage()),
    );
    if (result == true) {
      ref.invalidate(templatesProvider(null));
    }
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.template});

  final AppTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.layers),
        title: Text(template.name),
        subtitle: Text(
          [
            template.type,
            if ((template.description ?? '').isNotEmpty) template.description!,
          ].join(' • '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (template.type == 'workflow')
              IconButton(
                tooltip: 'Apply workflow template',
                icon: const Icon(Icons.playlist_add_check),
                onPressed: () => _applyWorkflowTemplate(context, ref),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => TemplateEditorPage(template: template),
            ),
          );
          if (result == true) {
            ref.invalidate(templatesProvider(null));
            ref.invalidate(templatesProvider(template.type));
          }
        },
      ),
    );
  }

  Future<void> _applyWorkflowTemplate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final steps = (template.payload['steps'] as List?) ?? const [];
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No workflow steps configured.')),
      );
      return;
    }
    final assignees = await ref.read(taskAssigneesProvider.future);
    final candidates = _resolveAssignees(assignees);
    final byId = {for (final assignee in assignees) assignee.id: assignee};
    final repo = ref.read(tasksRepositoryProvider);
    int assignedIndex = 0;
    for (final raw in steps) {
      final map = Map<String, dynamic>.from(raw as Map);
      final title = map['title']?.toString().trim().isNotEmpty == true
          ? map['title']?.toString() ?? 'Workflow step'
          : 'Workflow step';
      final dueDays = map['dueDays'] is int
          ? map['dueDays'] as int
          : int.tryParse(map['dueDays']?.toString() ?? '');
      final requiresApproval = map['requiresApproval'] == true;
      final approverRole = map['approverRole']?.toString();
      final assignedUserId = candidates.isEmpty
          ? null
          : candidates[assignedIndex % candidates.length];
      assignedIndex += 1;
      final assignee = assignedUserId == null ? null : byId[assignedUserId];
      final instructions = [
        if ((template.description ?? '').isNotEmpty) template.description!,
        if (requiresApproval)
          'Approval required${approverRole != null ? ' by $approverRole' : ''}.',
      ].where((line) => line.isNotEmpty).join('\n');
      await repo.createTask(
        title: title,
        description: template.description,
        instructions: instructions.isEmpty ? null : instructions,
        dueDate: dueDays != null
            ? DateTime.now().add(Duration(days: dueDays))
            : null,
        assignedTo: assignedUserId,
        assignedToName: assignee?.name,
        metadata: requiresApproval
            ? {
                'approval': {
                  'required': true,
                  'status': 'pending',
                  if (approverRole != null) 'approverRole': approverRole,
                },
              }
            : null,
      );
    }
    if (context.mounted) {
      ref.invalidate(tasksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workflow tasks created.')),
      );
    }
  }

  List<String> _resolveAssignees(List<TaskAssignee> assignees) {
    final assignedIds = template.assignedUserIds;
    final assignedRoles =
        template.assignedRoles.map((role) => role.toLowerCase()).toSet();
    final matches = <String>[];
    if (assignedIds.isNotEmpty) {
      for (final userId in assignedIds) {
        if (assignees.any((a) => a.id == userId)) {
          matches.add(userId);
        }
      }
    }
    if (assignedRoles.isNotEmpty) {
      for (final assignee in assignees) {
        final role = assignee.role?.toLowerCase();
        if (role != null && assignedRoles.contains(role)) {
          matches.add(assignee.id);
        }
      }
    }
    return matches.toSet().toList();
  }
}
