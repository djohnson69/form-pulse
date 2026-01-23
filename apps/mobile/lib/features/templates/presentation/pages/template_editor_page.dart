import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../../core/ai/ai_assist_sheet.dart';
import '../../../../core/ai/ai_parsers.dart';
import '../../../ops/data/ops_provider.dart';
import '../../../ops/data/ops_repository.dart' as ops_repo;
import '../../data/templates_provider.dart';

class TemplateEditorPage extends ConsumerStatefulWidget {
  const TemplateEditorPage({this.template, super.key});

  final AppTemplate? template;

  @override
  ConsumerState<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends ConsumerState<TemplateEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _assignedUsersController = TextEditingController();
  final _assignedRolesController = TextEditingController();
  final _projectStatusController = TextEditingController();
  final _projectLabelsController = TextEditingController();
  final _reportSectionController = TextEditingController();
  final _checklistItemController = TextEditingController();
  final _workflowStepController = TextEditingController();
  final _workflowApproverController = TextEditingController();
  final _workflowDueController = TextEditingController();

  String _type = 'workflow';
  bool _isActive = true;
  bool _workflowRequiresApproval = false;
  bool _checklistRequired = false;
  final List<_ChecklistItem> _checklistItems = [];
  final List<_WorkflowStep> _workflowSteps = [];
  final List<String> _reportSections = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    if (template != null) {
      _type = template.type;
      _nameController.text = template.name;
      _descriptionController.text = template.description ?? '';
      _assignedUsersController.text = template.assignedUserIds.join(', ');
      _assignedRolesController.text = template.assignedRoles.join(', ');
      _isActive = template.isActive;
      _hydratePayload(template);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _assignedUsersController.dispose();
    _assignedRolesController.dispose();
    _projectStatusController.dispose();
    _projectLabelsController.dispose();
    _reportSectionController.dispose();
    _checklistItemController.dispose();
    _workflowStepController.dispose();
    _workflowApproverController.dispose();
    _workflowDueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.template != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Template' : 'New Template')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'workflow', child: Text('Workflow')),
                  DropdownMenuItem(value: 'checklist', child: Text('Checklist')),
                  DropdownMenuItem(value: 'project', child: Text('Project')),
                  DropdownMenuItem(value: 'report', child: Text('Report')),
                ],
                onChanged: (value) => setState(() => _type = value ?? 'workflow'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _assignedRolesController,
                decoration: const InputDecoration(
                  labelText: 'Assigned roles (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _assignedUsersController,
                decoration: const InputDecoration(
                  labelText: 'Assigned user IDs (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 12),
              if (_type == 'checklist') _buildChecklistEditor(),
              if (_type == 'workflow') _buildWorkflowEditor(),
              if (_type == 'project') _buildProjectEditor(),
              if (_type == 'report') _buildReportEditor(),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save template'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Checklist items', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _checklistItemController,
          decoration: const InputDecoration(
            labelText: 'Item',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _openChecklistAiAssist,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI Assist'),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Required'),
          value: _checklistRequired,
          onChanged: (value) => setState(() => _checklistRequired = value),
        ),
        FilledButton(
          onPressed: () {
            final label = _checklistItemController.text.trim();
            if (label.isEmpty) return;
            setState(() {
              _checklistItems.add(
                _ChecklistItem(label: label, required: _checklistRequired),
              );
              _checklistItemController.clear();
              _checklistRequired = false;
            });
          },
          child: const Text('Add item'),
        ),
        const SizedBox(height: 8),
        ..._checklistItems.map(
          (item) => ListTile(
            leading: Icon(
              item.required ? Icons.check_box : Icons.check_box_outline_blank,
            ),
            title: Text(item.label),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _checklistItems.remove(item)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openChecklistAiAssist() async {
    final result = await showModalBottomSheet<AiAssistResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AiAssistSheet(
        title: 'AI Checklist Builder',
        initialText: _descriptionController.text.trim(),
        initialType: 'checklist_builder',
        options: const [
          AiAssistOption(
            id: 'checklist_builder',
            label: 'Checklist builder',
            requiresChecklist: true,
            allowsAudio: true,
          ),
          AiAssistOption(id: 'summary', label: 'Summary', allowsAudio: true),
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
    final items = parseChecklistItems(output);
    if (items.isEmpty) return;
    if (!mounted) return;
    setState(() {
      for (final item in items) {
        final exists = _checklistItems.any(
          (existing) => existing.label.toLowerCase() == item.toLowerCase(),
        );
        if (!exists) {
          _checklistItems.add(
            _ChecklistItem(label: item, required: _checklistRequired),
          );
        }
      }
    });
    await _recordChecklistAiUsage(result);
  }

  Future<void> _recordChecklistAiUsage(AiAssistResult result) async {
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
              'source': 'template_checklist',
              'templateType': _type,
              if (result.targetLanguage != null &&
                  result.targetLanguage!.isNotEmpty)
                'targetLanguage': result.targetLanguage,
              if (result.checklistCount != null)
                'checklistCount': result.checklistCount,
            },
          );
    } catch (e, st) {
      // Ignore AI logging failures for checklist generation.
      developer.log('TemplateEditorPage AI assist logging failed',
          error: e, stackTrace: st, name: 'TemplateEditorPage._logAiUsage');
    }
  }

  Widget _buildWorkflowEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Workflow steps', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _workflowStepController,
          decoration: const InputDecoration(
            labelText: 'Step title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Requires approval'),
          value: _workflowRequiresApproval,
          onChanged: (value) => setState(() => _workflowRequiresApproval = value),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _workflowApproverController,
          decoration: const InputDecoration(
            labelText: 'Approver role (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _workflowDueController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Due days (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {
            final title = _workflowStepController.text.trim();
            if (title.isEmpty) return;
            setState(() {
              _workflowSteps.add(
                _WorkflowStep(
                  title: title,
                  requiresApproval: _workflowRequiresApproval,
                  approverRole: _workflowApproverController.text.trim().isEmpty
                      ? null
                      : _workflowApproverController.text.trim(),
                  dueDays: int.tryParse(_workflowDueController.text.trim()),
                ),
              );
              _workflowStepController.clear();
              _workflowApproverController.clear();
              _workflowDueController.clear();
              _workflowRequiresApproval = false;
            });
          },
          child: const Text('Add step'),
        ),
        const SizedBox(height: 8),
        ..._workflowSteps.map(
          (step) => ListTile(
            leading: Icon(
              step.requiresApproval ? Icons.approval : Icons.flag_outlined,
            ),
            title: Text(step.title),
            subtitle: Text(
              [
                if (step.approverRole != null)
                  'Approver: ${step.approverRole}',
                if (step.dueDays != null) 'Due ${step.dueDays}d',
              ].join(' • '),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _workflowSteps.remove(step)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Project defaults', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _projectStatusController,
          decoration: const InputDecoration(
            labelText: 'Default status',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _projectLabelsController,
          decoration: const InputDecoration(
            labelText: 'Default labels (comma separated)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildReportEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Report sections', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _reportSectionController,
          decoration: const InputDecoration(
            labelText: 'Section title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {
            final title = _reportSectionController.text.trim();
            if (title.isEmpty) return;
            setState(() {
              _reportSections.add(title);
              _reportSectionController.clear();
            });
          },
          child: const Text('Add section'),
        ),
        const SizedBox(height: 8),
        ..._reportSections.map(
          (section) => ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(section),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _reportSections.remove(section)),
            ),
          ),
        ),
      ],
    );
  }

  void _hydratePayload(AppTemplate template) {
    final payload = template.payload;
    if (template.type == 'checklist') {
      final items = payload['items'] as List? ?? const [];
      for (final item in items) {
        final map = Map<String, dynamic>.from(item as Map);
        _checklistItems.add(
          _ChecklistItem(
            label: map['label']?.toString() ?? 'Item',
            required: map['required'] as bool? ?? false,
          ),
        );
      }
    } else if (template.type == 'workflow') {
      final steps = payload['steps'] as List? ?? const [];
      for (final step in steps) {
        final map = Map<String, dynamic>.from(step as Map);
        _workflowSteps.add(
          _WorkflowStep(
            title: map['title']?.toString() ?? 'Step',
            requiresApproval: map['requiresApproval'] as bool? ?? false,
            approverRole: map['approverRole']?.toString(),
            dueDays: map['dueDays'] is int
                ? map['dueDays'] as int
                : int.tryParse(map['dueDays']?.toString() ?? ''),
          ),
        );
      }
    } else if (template.type == 'project') {
      final defaults = payload['defaults'] as Map<String, dynamic>? ?? const {};
      _projectStatusController.text = defaults['status']?.toString() ?? '';
      _projectLabelsController.text =
          (defaults['labels'] as List?)?.join(', ') ?? '';
    } else if (template.type == 'report') {
      final sections = payload['sections'] as List? ?? const [];
      _reportSections.addAll(sections.map((e) => e.toString()));
    }
  }

  Map<String, dynamic> _buildPayload() {
    switch (_type) {
      case 'checklist':
        return {
          'items': _checklistItems
              .map((item) => {'label': item.label, 'required': item.required})
              .toList(),
        };
      case 'workflow':
        return {
          'steps': _workflowSteps
              .map(
                (step) => {
                  'title': step.title,
                  'requiresApproval': step.requiresApproval,
                  'approverRole': step.approverRole,
                  'dueDays': step.dueDays,
                },
              )
              .toList(),
        };
      case 'project':
        return {
          'defaults': {
            'status': _projectStatusController.text.trim(),
            'labels': _projectLabelsController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
          },
        };
      case 'report':
        return {'sections': _reportSections};
      default:
        return {};
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(templatesRepositoryProvider);
      final assignedUsers = _assignedUsersController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final assignedRoles = _assignedRolesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final payload = _buildPayload();

      final template = widget.template;
      final isCreating = template == null || template.id.isEmpty;
      if (isCreating) {
        await repo.createTemplate(
          type: _type,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          payload: payload,
          assignedUserIds: assignedUsers,
          assignedRoles: assignedRoles,
          isActive: _isActive,
        );
      } else {
        await repo.updateTemplate(
          template: template,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          payload: payload,
          assignedUserIds: assignedUsers,
          assignedRoles: assignedRoles,
          isActive: _isActive,
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
}

class _ChecklistItem {
  _ChecklistItem({required this.label, required this.required});

  final String label;
  final bool required;
}

class _WorkflowStep {
  _WorkflowStep({
    required this.title,
    required this.requiresApproval,
    this.approverRole,
    this.dueDays,
  });

  final String title;
  final bool requiresApproval;
  final String? approverRole;
  final int? dueDays;
}
