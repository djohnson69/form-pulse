import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart' as shared;

import '../../data/dashboard_provider.dart';
import 'form_detail_page.dart';

/// Guided form creation wizard (lightweight) for demo purposes.
class CreateFormPage extends ConsumerStatefulWidget {
  const CreateFormPage({super.key});

  @override
  ConsumerState<CreateFormPage> createState() => _CreateFormPageState();
}

class _CreateFormPageState extends ConsumerState<CreateFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();

  final List<_FieldDraft> _fields = [
    _FieldDraft(type: shared.FormFieldType.text, label: 'Title'),
    _FieldDraft(type: shared.FormFieldType.textarea, label: 'Details'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Form')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Form title'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Fields', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add field',
                    onPressed: _addFieldSheet,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_fields.isEmpty)
                const Text('Add at least one field to create the form.')
              else
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _fields.removeAt(oldIndex);
                      _fields.insert(newIndex, item);
                    });
                  },
                  children: _fields.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final field = entry.value;
                    return Card(
                      key: ValueKey(field.id),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${idx + 1}')),
                        title: Text(field.label),
                        subtitle: Text(field.type.displayName),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editField(idx),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                setState(() {
                                  _fields.removeAt(idx);
                                });
                              },
                            ),
                            const Icon(Icons.drag_handle),
                          ],
                        ),
                        onTap: () => _editField(idx),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Create Form'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addFieldSheet() async {
    final result = await showModalBottomSheet<_FieldDraft>(
      context: context,
      builder: (_) => _FieldChooser(),
    );
    if (result != null) {
      setState(() => _fields.add(result));
    }
  }

  Future<void> _editField(int index) async {
    final current = _fields[index];
    final result = await showModalBottomSheet<_FieldDraft>(
      context: context,
      builder: (_) => _FieldChooser(initial: current),
    );
    if (result != null) {
      setState(() => _fields[index] = result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _fields.isEmpty) return;
    final repo = ref.read(dashboardRepositoryProvider);
    final id = 'form-${Random().nextInt(999999)}';
    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final form = shared.FormDefinition(
      id: id,
      title: _titleController.text,
      description: _descriptionController.text,
      category: _categoryController.text.isEmpty
          ? null
          : _categoryController.text,
      tags: tags.isEmpty ? null : tags,
      fields: _fields
          .asMap()
          .entries
          .map(
            (entry) => shared.FormField(
              id: entry.value.id,
              label: entry.value.label,
              type: entry.value.type,
              order: entry.key + 1,
              isRequired: entry.value.required,
              options: entry.value.options,
            ),
          )
          .toList(),
      isPublished: true,
      createdBy: 'demo-user',
      createdAt: DateTime.now(),
      metadata: {'source': 'builder'},
    );

    try {
      await repo.createForm(form);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FormDetailPage(form: form)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }
}

class _FieldDraft {
  _FieldDraft({
    required this.type,
    this.label = 'New field',
    this.required = false,
    this.options,
  }) : id = 'fld-${Random().nextInt(999999)}';

  final String id;
  final shared.FormFieldType type;
  final String label;
  final bool required;
  final List<String>? options;
}

class _FieldChooser extends StatefulWidget {
  const _FieldChooser({this.initial});

  final _FieldDraft? initial;

  @override
  State<_FieldChooser> createState() => _FieldChooserState();
}

class _FieldChooserState extends State<_FieldChooser> {
  late shared.FormFieldType _type;
  late TextEditingController _label;
  late TextEditingController _options;
  late bool _required;

  @override
  void initState() {
    super.initState();
    _type = widget.initial?.type ?? shared.FormFieldType.text;
    _label = TextEditingController(text: widget.initial?.label ?? 'New field');
    _options = TextEditingController(
      text: widget.initial?.options?.join(', ') ?? '',
    );
    _required = widget.initial?.required ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _options.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.initial == null ? 'Add Field' : 'Edit Field',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<shared.FormFieldType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items:
                [
                      shared.FormFieldType.text,
                      shared.FormFieldType.textarea,
                      shared.FormFieldType.number,
                      shared.FormFieldType.dropdown,
                      shared.FormFieldType.checkbox,
                      shared.FormFieldType.radio,
                      shared.FormFieldType.photo,
                      shared.FormFieldType.signature,
                      shared.FormFieldType.location,
                      shared.FormFieldType.barcode,
                    ]
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      ),
                    )
                    .toList(),
            onChanged: (val) {
              setState(() {
                _type = val ?? shared.FormFieldType.text;
              });
            },
          ),
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Label'),
          ),
          if (_type == shared.FormFieldType.dropdown ||
              _type == shared.FormFieldType.checkbox ||
              _type == shared.FormFieldType.radio)
            TextField(
              controller: _options,
              decoration: const InputDecoration(
                labelText: 'Options (comma separated)',
              ),
            ),
          SwitchListTile(
            title: const Text('Required'),
            value: _required,
            onChanged: (val) => setState(() => _required = val),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              final opts = _options.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              Navigator.pop(
                context,
                _FieldDraft(
                  type: _type,
                  label: _label.text,
                  required: _required,
                  options: opts.isEmpty ? null : opts,
                ),
              );
            },
            child: const Text('Save field'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
