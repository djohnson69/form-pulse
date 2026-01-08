import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart' as shared;

import '../../data/dashboard_provider.dart';
import 'form_detail_page.dart';

enum FormEditorMode { create, edit, duplicate }

class CreateFormPage extends ConsumerStatefulWidget {
  const CreateFormPage({
    super.key,
    this.initialForm,
    this.mode = FormEditorMode.create,
  });

  final shared.FormDefinition? initialForm;
  final FormEditorMode mode;

  @override
  ConsumerState<CreateFormPage> createState() => _CreateFormPageState();
}

class _CreateFormPageState extends ConsumerState<CreateFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _showPreview = false;
  String _activeCategory = _fieldCategories.first;
  String? _expandedFieldId;
  late List<_FieldDraft> _fields;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialForm;
    if (initial != null) {
      final title = widget.mode == FormEditorMode.duplicate
          ? '${initial.title} (Copy)'
          : initial.title;
      _titleController.text = title;
      _descriptionController.text = initial.description;
      _fields = initial.fields
          .map(_FieldDraft.fromFormField)
          .toList(growable: true);
    } else {
      _fields = <_FieldDraft>[];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPreview = _showPreview;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: TextField(
          controller: _titleController,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Form Title',
            border: InputBorder.none,
            hintStyle: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showPreview = !_showPreview),
            icon: Icon(isPreview ? Icons.edit : Icons.visibility),
            label: Text(isPreview ? 'Edit' : 'Preview'),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: isPreview
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: FilledButton.icon(
                  onPressed: _openFieldPalette,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Field'),
                ),
              ),
            ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: isPreview ? _buildPreview(context) : _buildEditor(context),
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleController.text.isEmpty
                    ? 'Untitled Form'
                    : _titleController.text,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_descriptionController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _descriptionController.text.trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_fields.isEmpty)
                Text(
                  'No fields added yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Column(
                  children: _fields
                      .map((field) => _PreviewField(field: field))
                      .toList(),
                ),
              if (_fields.isNotEmpty) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {},
                  child: const Text('Submit Form'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditor(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          controller: _descriptionController,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Form description (optional)...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        if (_fields.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                width: 1.5,
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF374151)
                    : const Color(0xFFE5E7EB),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'No fields yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _openFieldPalette,
                  child: const Text('Tap + to add fields'),
                ),
              ],
            ),
          )
        else
          Column(
            children: _fields.asMap().entries.map((entry) {
              final index = entry.key;
              final field = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FieldCard(
                  key: ValueKey(field.id),
                  field: field,
                  isFirst: index == 0,
                  isLast: index == _fields.length - 1,
                  isExpanded: _expandedFieldId == field.id,
                  onToggle: () {
                    setState(() {
                      _expandedFieldId =
                          _expandedFieldId == field.id ? null : field.id;
                    });
                  },
                  onMoveUp: () => _moveField(index, -1),
                  onMoveDown: () => _moveField(index, 1),
                  onDelete: () => _removeField(index),
                  onUpdate: (updated) {
                    setState(() => _fields[index] = updated);
                  },
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _openFieldPalette() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        String activeCategory = _activeCategory;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFF374151)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Field',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: _fieldCategories.map((category) {
                        final selected = activeCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: selected,
                            onSelected: (_) {
                              setModalState(() => activeCategory = category);
                              setState(() => _activeCategory = category);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Expanded(
                    child: GridView.count(
                      padding: const EdgeInsets.all(16),
                      crossAxisCount: MediaQuery.of(context).size.width >= 900
                          ? 4
                          : 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: _fieldPalette
                          .where((item) => item.category == activeCategory)
                          .map(
                            (item) => _FieldPaletteCard(
                              item: item,
                              onTap: () {
                                setState(() => _activeCategory = activeCategory);
                                _addField(item);
                                Navigator.of(context).pop();
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _addField(_FieldPaletteItem item) {
    final hasOptions = _optionTypes.contains(item.typeKey);
    final hasRange = _rangeTypes.contains(item.typeKey);
    final draft = _FieldDraft(
      type: item.formType,
      typeKey: item.typeKey,
      typeLabel: item.label,
      icon: item.icon,
      label: item.label,
      placeholder: '',
      required: false,
      options: hasOptions
          ? List<String>.generate(3, (i) => 'Option ${i + 1}')
          : null,
      min: hasRange ? 0 : null,
      max: hasRange ? (item.typeKey == 'scale' ? 10 : 100) : null,
    );
    setState(() {
      _fields.add(draft);
      _expandedFieldId = draft.id;
    });
  }

  void _moveField(int index, int delta) {
    final next = index + delta;
    if (next < 0 || next >= _fields.length) return;
    setState(() {
      final item = _fields.removeAt(index);
      _fields.insert(next, item);
    });
  }

  void _removeField(int index) {
    setState(() {
      final id = _fields[index].id;
      _fields.removeAt(index);
      if (_expandedFieldId == id) _expandedFieldId = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(dashboardRepositoryProvider);
    final shouldUpdate =
        widget.mode == FormEditorMode.edit && widget.initialForm != null;
    final isDuplicate = widget.mode == FormEditorMode.duplicate;
    final initial = widget.initialForm;
    final id =
        shouldUpdate ? initial!.id : 'form-${Random().nextInt(999999)}';

    final metadata = Map<String, dynamic>.from(initial?.metadata ?? const {});
    metadata['source'] = metadata['source'] ?? 'builder';
    if (isDuplicate && initial != null) {
      metadata['duplicateOf'] = initial.id;
    }

    final form = shared.FormDefinition(
      id: id,
      title: _titleController.text.trim().isEmpty
          ? 'Untitled Form'
          : _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: initial?.category,
      tags: initial?.tags,
      fields: _fields
          .asMap()
          .entries
          .map(
            (entry) => shared.FormField(
              id: entry.value.id,
              label: entry.value.label,
              type: entry.value.type,
              placeholder: entry.value.placeholder,
              order: entry.key + 1,
              isRequired: entry.value.required,
              options: entry.value.options,
              metadata: entry.value.toMetadata(),
            ),
          )
          .toList(),
      isPublished: initial?.isPublished ?? true,
      version: initial?.version,
      createdBy: shouldUpdate ? initial!.createdBy : 'demo-user',
      createdAt: shouldUpdate ? initial!.createdAt : DateTime.now(),
      updatedAt: shouldUpdate ? DateTime.now() : null,
      metadata: metadata,
    );

    try {
      final saved =
          shouldUpdate ? await repo.updateForm(form) : await repo.createForm(form);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FormDetailPage(form: saved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    super.key,
    required this.field,
    required this.isFirst,
    required this.isLast,
    required this.isExpanded,
    required this.onToggle,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onUpdate,
  });

  final _FieldDraft field;
  final bool isFirst;
  final bool isLast;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final ValueChanged<_FieldDraft> onUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    final highlight = theme.colorScheme.primary;
    final headerColor = isExpanded ? highlight : border;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: headerColor, width: isExpanded ? 1.5 : 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(field.icon, color: highlight),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                field.label,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (field.required)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Text(
                                  '*',
                                  style: TextStyle(color: Color(0xFFEF4444)),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          field.typeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: isFirst ? null : onMoveUp,
                        icon: const Icon(Icons.expand_less),
                      ),
                      IconButton(
                        onPressed: isLast ? null : onMoveDown,
                        icon: const Icon(Icons.expand_more),
                      ),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        color: const Color(0xFFDC2626),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: border)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: field.label,
                    onChanged: (value) =>
                        onUpdate(field.copyWith(label: value)),
                  ),
                  const SizedBox(height: 12),
                  if (!_nonInputTypes.contains(field.typeKey))
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Placeholder',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: field.placeholder ?? '',
                      onChanged: (value) =>
                          onUpdate(field.copyWith(placeholder: value)),
                    ),
                  if (_optionTypes.contains(field.typeKey)) ...[
                    const SizedBox(height: 12),
                    _OptionEditor(field: field, onUpdate: onUpdate),
                  ],
                  if (_rangeTypes.contains(field.typeKey)) ...[
                    const SizedBox(height: 12),
                    _RangeEditor(field: field, onUpdate: onUpdate),
                  ],
                  if (!_nonInputTypes.contains(field.typeKey))
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Required field'),
                      value: field.required,
                      onChanged: (value) =>
                          onUpdate(field.copyWith(required: value)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionEditor extends StatelessWidget {
  const _OptionEditor({required this.field, required this.onUpdate});

  final _FieldDraft field;
  final ValueChanged<_FieldDraft> onUpdate;

  @override
  Widget build(BuildContext context) {
    final options = field.options ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Options', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...options.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    initialValue: value,
                    onChanged: (text) {
                      final updated = List<String>.from(options);
                      updated[index] = text;
                      onUpdate(field.copyWith(options: updated));
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final updated = List<String>.from(options)..removeAt(index);
                    onUpdate(field.copyWith(options: updated));
                  },
                  icon: const Icon(Icons.delete_outline),
                  color: const Color(0xFFDC2626),
                ),
              ],
            ),
          );
        }),
        TextButton(
          onPressed: () {
            final updated = List<String>.from(options)
              ..add('Option ${options.length + 1}');
            onUpdate(field.copyWith(options: updated));
          },
          child: const Text('+ Add Option'),
        ),
      ],
    );
  }
}

class _RangeEditor extends StatelessWidget {
  const _RangeEditor({required this.field, required this.onUpdate});

  final _FieldDraft field;
  final ValueChanged<_FieldDraft> onUpdate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Min',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            initialValue: (field.min ?? 0).toString(),
            onChanged: (value) {
              final parsed = int.tryParse(value) ?? 0;
              onUpdate(field.copyWith(min: parsed));
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Max',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            initialValue: (field.max ?? 100).toString(),
            onChanged: (value) {
              final parsed = int.tryParse(value) ?? 100;
              onUpdate(field.copyWith(max: parsed));
            },
          ),
        ),
      ],
    );
  }
}

class _PreviewField extends StatelessWidget {
  const _PreviewField({required this.field});

  final _FieldDraft field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Row(
      children: [
        Text(
          field.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (field.required)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              '*',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
      ],
    );

    if (field.typeKey == 'section') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          field.label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (field.typeKey == 'description') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          field.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (field.typeKey == 'divider') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(),
      );
    }
    if (field.typeKey == 'pagebreak') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF374151)
                : const Color(0xFFE5E7EB),
            style: BorderStyle.solid,
          ),
        ),
        child: Text(
          'Page Break',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          const SizedBox(height: 8),
          if (field.typeKey == 'checkbox')
            Row(
              children: [
                const Checkbox(value: false, onChanged: null),
                Text(field.placeholder?.isEmpty ?? true
                    ? 'Check this'
                    : field.placeholder!),
              ],
            )
          else if (field.typeKey == 'radio')
            Column(
              children: (field.options ?? const ['Option 1'])
                  .map(
                    (opt) => Row(
                      children: [
                        const Radio<int>(
                          value: 0,
                          groupValue: 1,
                          onChanged: null,
                        ),
                        Text(opt),
                      ],
                    ),
                  )
                  .toList(),
            )
          else if (field.typeKey == 'toggle')
            Row(
              children: [
                const Switch(value: false, onChanged: null),
                Text(field.placeholder?.isEmpty ?? true
                    ? 'No'
                    : field.placeholder!),
              ],
            )
          else
            TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: field.placeholder?.isEmpty ?? true
                    ? 'Enter ${field.typeLabel.toLowerCase()}'
                    : field.placeholder,
                border: const OutlineInputBorder(),
              ),
            ),
        ],
      ),
    );
  }
}

class _FieldPaletteCard extends StatelessWidget {
  const _FieldPaletteCard({required this.item, required this.onTap});

  final _FieldPaletteItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF374151)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldDraft {
  _FieldDraft({
    String? id,
    required this.type,
    required this.typeKey,
    required this.typeLabel,
    required this.icon,
    required this.label,
    this.placeholder,
    this.required = false,
    this.options,
    this.min,
    this.max,
  }) : id = id ?? 'fld-${Random().nextInt(999999)}';

  final String id;
  final shared.FormFieldType type;
  final String typeKey;
  final String typeLabel;
  final IconData icon;
  final String label;
  final String? placeholder;
  final bool required;
  final List<String>? options;
  final int? min;
  final int? max;

  _FieldDraft copyWith({
    String? label,
    String? placeholder,
    bool? required,
    List<String>? options,
    int? min,
    int? max,
  }) {
    return _FieldDraft(
      id: id,
      type: type,
      typeKey: typeKey,
      typeLabel: typeLabel,
      icon: icon,
      label: label ?? this.label,
      placeholder: placeholder ?? this.placeholder,
      required: required ?? this.required,
      options: options ?? this.options,
      min: min ?? this.min,
      max: max ?? this.max,
    );
  }

  Map<String, dynamic>? toMetadata() {
    final data = <String, dynamic>{};
    if (typeKey.isNotEmpty) data['typeKey'] = typeKey;
    if (typeLabel.isNotEmpty) data['typeLabel'] = typeLabel;
    if (min != null) data['min'] = min;
    if (max != null) data['max'] = max;
    return data.isEmpty ? null : data;
  }

  factory _FieldDraft.fromFormField(shared.FormField field) {
    final metadata = field.metadata ?? const <String, dynamic>{};
    final typeKey = metadata['typeKey']?.toString() ?? field.type.name;
    final typeLabel =
        metadata['typeLabel']?.toString() ?? field.type.displayName;
    final icon = _iconForTypeKey(typeKey);
    return _FieldDraft(
      id: field.id,
      type: field.type,
      typeKey: typeKey,
      typeLabel: typeLabel,
      icon: icon,
      label: field.label,
      placeholder: field.placeholder,
      required: field.isRequired,
      options: field.options,
      min: metadata['min'] is int
          ? metadata['min'] as int
          : int.tryParse(metadata['min']?.toString() ?? ''),
      max: metadata['max'] is int
          ? metadata['max'] as int
          : int.tryParse(metadata['max']?.toString() ?? ''),
    );
  }
}

class _FieldPaletteItem {
  const _FieldPaletteItem({
    required this.typeKey,
    required this.label,
    required this.icon,
    required this.category,
    required this.formType,
  });

  final String typeKey;
  final String label;
  final IconData icon;
  final String category;
  final shared.FormFieldType formType;
}

const List<String> _fieldCategories = [
  'Basic',
  'Choice',
  'Media',
  'Advanced',
  'Professional',
  'Field Service',
  'Measurement',
  'Layout',
];

const Set<String> _optionTypes = {
  'dropdown',
  'multiselect',
  'radio',
  'imagechoice',
  'ranking',
};

const Set<String> _rangeTypes = {
  'slider',
  'scale',
  'number',
};

const Set<String> _nonInputTypes = {
  'section',
  'description',
  'divider',
  'pagebreak',
  'html',
  'database',
};

const List<_FieldPaletteItem> _fieldPalette = [
  _FieldPaletteItem(
    typeKey: 'text',
    label: 'Short Text',
    icon: Icons.text_fields,
    category: 'Basic',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'textarea',
    label: 'Long Text',
    icon: Icons.notes,
    category: 'Basic',
    formType: shared.FormFieldType.textarea,
  ),
  _FieldPaletteItem(
    typeKey: 'email',
    label: 'Email',
    icon: Icons.email_outlined,
    category: 'Basic',
    formType: shared.FormFieldType.email,
  ),
  _FieldPaletteItem(
    typeKey: 'phone',
    label: 'Phone',
    icon: Icons.phone_outlined,
    category: 'Basic',
    formType: shared.FormFieldType.phone,
  ),
  _FieldPaletteItem(
    typeKey: 'number',
    label: 'Number',
    icon: Icons.confirmation_number_outlined,
    category: 'Basic',
    formType: shared.FormFieldType.number,
  ),
  _FieldPaletteItem(
    typeKey: 'date',
    label: 'Date',
    icon: Icons.calendar_today,
    category: 'Basic',
    formType: shared.FormFieldType.date,
  ),
  _FieldPaletteItem(
    typeKey: 'time',
    label: 'Time',
    icon: Icons.access_time,
    category: 'Basic',
    formType: shared.FormFieldType.time,
  ),
  _FieldPaletteItem(
    typeKey: 'url',
    label: 'Website',
    icon: Icons.link,
    category: 'Basic',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'password',
    label: 'Password',
    icon: Icons.lock_outline,
    category: 'Basic',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'dropdown',
    label: 'Dropdown',
    icon: Icons.arrow_drop_down_circle_outlined,
    category: 'Choice',
    formType: shared.FormFieldType.dropdown,
  ),
  _FieldPaletteItem(
    typeKey: 'multiselect',
    label: 'Multi-Select',
    icon: Icons.playlist_add_check,
    category: 'Choice',
    formType: shared.FormFieldType.checkbox,
  ),
  _FieldPaletteItem(
    typeKey: 'checkbox',
    label: 'Checkbox',
    icon: Icons.check_box_outlined,
    category: 'Choice',
    formType: shared.FormFieldType.checkbox,
  ),
  _FieldPaletteItem(
    typeKey: 'radio',
    label: 'Radio',
    icon: Icons.radio_button_checked,
    category: 'Choice',
    formType: shared.FormFieldType.radio,
  ),
  _FieldPaletteItem(
    typeKey: 'toggle',
    label: 'Yes/No',
    icon: Icons.toggle_on_outlined,
    category: 'Choice',
    formType: shared.FormFieldType.toggle,
  ),
  _FieldPaletteItem(
    typeKey: 'rating',
    label: 'Star Rating',
    icon: Icons.star_border,
    category: 'Choice',
    formType: shared.FormFieldType.number,
  ),
  _FieldPaletteItem(
    typeKey: 'scale',
    label: 'Scale (1-10)',
    icon: Icons.trending_up,
    category: 'Choice',
    formType: shared.FormFieldType.number,
  ),
  _FieldPaletteItem(
    typeKey: 'nps',
    label: 'NPS Score',
    icon: Icons.trending_up,
    category: 'Choice',
    formType: shared.FormFieldType.number,
  ),
  _FieldPaletteItem(
    typeKey: 'emoji',
    label: 'Emoji Rating',
    icon: Icons.emoji_emotions_outlined,
    category: 'Choice',
    formType: shared.FormFieldType.radio,
  ),
  _FieldPaletteItem(
    typeKey: 'imagechoice',
    label: 'Image Choice',
    icon: Icons.image_outlined,
    category: 'Choice',
    formType: shared.FormFieldType.radio,
  ),
  _FieldPaletteItem(
    typeKey: 'ranking',
    label: 'Ranking',
    icon: Icons.swap_vert,
    category: 'Choice',
    formType: shared.FormFieldType.dropdown,
  ),
  _FieldPaletteItem(
    typeKey: 'file',
    label: 'File Upload',
    icon: Icons.upload_file,
    category: 'Media',
    formType: shared.FormFieldType.file,
  ),
  _FieldPaletteItem(
    typeKey: 'image',
    label: 'Image',
    icon: Icons.image,
    category: 'Media',
    formType: shared.FormFieldType.file,
  ),
  _FieldPaletteItem(
    typeKey: 'photo',
    label: 'Take Photo',
    icon: Icons.camera_alt_outlined,
    category: 'Media',
    formType: shared.FormFieldType.photo,
  ),
  _FieldPaletteItem(
    typeKey: 'video',
    label: 'Video',
    icon: Icons.videocam_outlined,
    category: 'Media',
    formType: shared.FormFieldType.video,
  ),
  _FieldPaletteItem(
    typeKey: 'audio',
    label: 'Audio',
    icon: Icons.mic_none,
    category: 'Media',
    formType: shared.FormFieldType.audio,
  ),
  _FieldPaletteItem(
    typeKey: 'signature',
    label: 'Signature',
    icon: Icons.border_color,
    category: 'Media',
    formType: shared.FormFieldType.signature,
  ),
  _FieldPaletteItem(
    typeKey: 'location',
    label: 'GPS Location',
    icon: Icons.location_on_outlined,
    category: 'Advanced',
    formType: shared.FormFieldType.location,
  ),
  _FieldPaletteItem(
    typeKey: 'qrcode',
    label: 'QR Scanner',
    icon: Icons.qr_code_scanner,
    category: 'Advanced',
    formType: shared.FormFieldType.barcode,
  ),
  _FieldPaletteItem(
    typeKey: 'barcode',
    label: 'Barcode',
    icon: Icons.qr_code,
    category: 'Advanced',
    formType: shared.FormFieldType.barcode,
  ),
  _FieldPaletteItem(
    typeKey: 'currency',
    label: 'Currency',
    icon: Icons.attach_money,
    category: 'Advanced',
    formType: shared.FormFieldType.number,
  ),
  _FieldPaletteItem(
    typeKey: 'percentage',
    label: 'Percentage',
    icon: Icons.pie_chart_outline,
    category: 'Advanced',
    formType: shared.FormFieldType.number,
  ),
  _FieldPaletteItem(
    typeKey: 'slider',
    label: 'Slider',
    icon: Icons.tune,
    category: 'Advanced',
    formType: shared.FormFieldType.number,
  ),
  _FieldPaletteItem(
    typeKey: 'color',
    label: 'Color Picker',
    icon: Icons.palette_outlined,
    category: 'Advanced',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'daterange',
    label: 'Date Range',
    icon: Icons.date_range,
    category: 'Advanced',
    formType: shared.FormFieldType.date,
  ),
  _FieldPaletteItem(
    typeKey: 'timerange',
    label: 'Time Range',
    icon: Icons.schedule,
    category: 'Advanced',
    formType: shared.FormFieldType.time,
  ),
  _FieldPaletteItem(
    typeKey: 'matrix',
    label: 'Matrix/Grid',
    icon: Icons.grid_on,
    category: 'Advanced',
    formType: shared.FormFieldType.table,
  ),
  _FieldPaletteItem(
    typeKey: 'calculation',
    label: 'Calculation',
    icon: Icons.calculate_outlined,
    category: 'Advanced',
    formType: shared.FormFieldType.computed,
  ),
  _FieldPaletteItem(
    typeKey: 'hidden',
    label: 'Hidden Field',
    icon: Icons.visibility_off_outlined,
    category: 'Advanced',
    formType: shared.FormFieldType.computed,
  ),
  _FieldPaletteItem(
    typeKey: 'name',
    label: 'Full Name',
    icon: Icons.person_outline,
    category: 'Professional',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'address',
    label: 'Full Address',
    icon: Icons.home,
    category: 'Professional',
    formType: shared.FormFieldType.textarea,
  ),
  _FieldPaletteItem(
    typeKey: 'company',
    label: 'Company',
    icon: Icons.business,
    category: 'Professional',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'country',
    label: 'Country',
    icon: Icons.public,
    category: 'Professional',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'payment',
    label: 'Payment',
    icon: Icons.credit_card,
    category: 'Professional',
    formType: shared.FormFieldType.number,
  ),
  _FieldPaletteItem(
    typeKey: 'appointment',
    label: 'Appointment',
    icon: Icons.event_available,
    category: 'Professional',
    formType: shared.FormFieldType.datetime,
  ),
  _FieldPaletteItem(
    typeKey: 'terms',
    label: 'Terms & Conditions',
    icon: Icons.description_outlined,
    category: 'Professional',
    formType: shared.FormFieldType.checkbox,
  ),
  _FieldPaletteItem(
    typeKey: 'consent',
    label: 'Legal Consent',
    icon: Icons.verified_user,
    category: 'Professional',
    formType: shared.FormFieldType.toggle,
  ),
  _FieldPaletteItem(
    typeKey: 'captcha',
    label: 'Captcha',
    icon: Icons.android,
    category: 'Professional',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'employeeid',
    label: 'Employee ID',
    icon: Icons.card_membership,
    category: 'Field Service',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'department',
    label: 'Department',
    icon: Icons.layers,
    category: 'Field Service',
    formType: shared.FormFieldType.dropdown,
  ),
  _FieldPaletteItem(
    typeKey: 'costcode',
    label: 'Cost Code',
    icon: Icons.local_offer,
    category: 'Field Service',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'equipment',
    label: 'Equipment ID',
    icon: Icons.build,
    category: 'Field Service',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'vehicle',
    label: 'Vehicle/Plate',
    icon: Icons.local_shipping,
    category: 'Field Service',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'vin',
    label: 'VIN Number',
    icon: Icons.confirmation_number,
    category: 'Field Service',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'serial',
    label: 'Serial Number',
    icon: Icons.confirmation_number,
    category: 'Field Service',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'asset',
    label: 'Asset Selector',
    icon: Icons.archive,
    category: 'Field Service',
    formType: shared.FormFieldType.dropdown,
  ),
  _FieldPaletteItem(
    typeKey: 'workorder',
    label: 'Work Order',
    icon: Icons.list_alt,
    category: 'Field Service',
    formType: shared.FormFieldType.text,
  ),
  _FieldPaletteItem(
    typeKey: 'teammember',
    label: 'Team Member',
    icon: Icons.group,
    category: 'Field Service',
    formType: shared.FormFieldType.dropdown,
  ),
  _FieldPaletteItem(
    typeKey: 'temperature',
    label: 'Temperature',
    icon: Icons.ac_unit,
    category: 'Measurement',
    formType: shared.FormFieldType.number,
  ),
  _FieldPaletteItem(
    typeKey: 'pressure',
    label: 'Pressure',
    icon: Icons.speed,
    category: 'Measurement',
    formType: shared.FormFieldType.number,
  ),
  _FieldPaletteItem(
    typeKey: 'measurement',
    label: 'Measurement',
    icon: Icons.straighten,
    category: 'Measurement',
    formType: shared.FormFieldType.number,
  ),
  _FieldPaletteItem(
    typeKey: 'safety',
    label: 'Safety Check',
    icon: Icons.warning_amber_outlined,
    category: 'Measurement',
    formType: shared.FormFieldType.checkbox,
  ),
  _FieldPaletteItem(
    typeKey: 'inspection',
    label: 'Inspection',
    icon: Icons.fact_check_outlined,
    category: 'Measurement',
    formType: shared.FormFieldType.checkbox,
  ),
  _FieldPaletteItem(
    typeKey: 'section',
    label: 'Section Header',
    icon: Icons.view_week,
    category: 'Layout',
    formType: shared.FormFieldType.sectionHeader,
  ),
  _FieldPaletteItem(
    typeKey: 'description',
    label: 'Text Block',
    icon: Icons.subject_outlined,
    category: 'Layout',
    formType: shared.FormFieldType.infoText,
  ),
  _FieldPaletteItem(
    typeKey: 'divider',
    label: 'Divider',
    icon: Icons.horizontal_rule,
    category: 'Layout',
    formType: shared.FormFieldType.infoText,
  ),
  _FieldPaletteItem(
    typeKey: 'pagebreak',
    label: 'Page Break',
    icon: Icons.view_stream,
    category: 'Layout',
    formType: shared.FormFieldType.infoText,
  ),
  _FieldPaletteItem(
    typeKey: 'html',
    label: 'HTML Block',
    icon: Icons.code_outlined,
    category: 'Layout',
    formType: shared.FormFieldType.infoText,
  ),
  _FieldPaletteItem(
    typeKey: 'database',
    label: 'Data Lookup',
    icon: Icons.storage_outlined,
    category: 'Layout',
    formType: shared.FormFieldType.infoText,
  ),
];

IconData _iconForTypeKey(String key) {
  for (final item in _fieldPalette) {
    if (item.typeKey == key) return item.icon;
  }
  return Icons.text_fields;
}
