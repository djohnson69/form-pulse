import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../data/templates_provider.dart';
import 'template_editor_page.dart';

class TemplatesPage extends ConsumerStatefulWidget {
  const TemplatesPage({super.key});

  @override
  ConsumerState<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends ConsumerState<TemplatesPage> {
  _TemplateType _selectedType = _TemplateType.workflow;

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templatesProvider(null));
    final colors = _TemplateColors.fromTheme(Theme.of(context));
    final templates = templatesAsync.asData?.value ?? const <AppTemplate>[];
    final templateCards = _templatesFromModels(templates);
    final visible = templateCards
        .where((template) => template.type == _selectedType)
        .toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (templatesAsync.isLoading) const LinearProgressIndicator(),
          if (templatesAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ErrorBanner(message: templatesAsync.error.toString()),
            ),
          _Header(
            colors: colors,
            onCreate: () => _openEditor(context),
          ),
          const SizedBox(height: 16),
          _TypeTabs(
            colors: colors,
            selectedType: _selectedType,
            onSelected: (type) => setState(() => _selectedType = type),
          ),
          const SizedBox(height: 16),
          _TemplatesGrid(
            templates: visible,
            colors: colors,
            type: _selectedType,
            onCreate: () => _openEditor(context),
            onDuplicate: (template) {
              final source = template.source;
              if (source == null) return;
              final copy = AppTemplate(
                id: '',
                orgId: source.orgId,
                type: source.type,
                name: '${template.name} copy',
                description: source.description,
                payload: Map<String, dynamic>.from(source.payload),
                assignedUserIds: List<String>.from(source.assignedUserIds),
                assignedRoles: List<String>.from(source.assignedRoles),
                isActive: source.isActive,
                createdBy: source.createdBy,
                createdAt: DateTime.now(),
                updatedAt: null,
                metadata: source.metadata == null
                    ? null
                    : Map<String, dynamic>.from(source.metadata!),
              );
              _openEditor(context, template: copy);
            },
            onEdit: (template) =>
                _openEditor(context, template: template.source),
          ),
          const SizedBox(height: 16),
          _FeaturesGrid(colors: colors),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    AppTemplate? template,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TemplateEditorPage(template: template),
      ),
    );
    if (result == true) {
      ref.invalidate(templatesProvider(null));
    }
  }

  List<_TemplateCardData> _templatesFromModels(List<AppTemplate> templates) {
    return templates.map((template) {
      final normalizedType = _normalizeType(template.type);
      final payload = template.payload;
      final steps = _stepsFromPayload(payload);
      final fields = _fieldsFromPayload(payload);
      final roles = template.assignedRoles;
      final usageCount =
          _metaInt(template.metadata, ['usageCount', 'usage_count']) ?? 0;
      final lastModified = template.updatedAt ?? template.createdAt;
      return _TemplateCardData(
        id: template.id,
        name: template.name,
        type: normalizedType,
        description: template.description ?? 'Template description not set.',
        steps: steps.isEmpty ? null : steps,
        fields: fields.isEmpty ? null : fields,
        assignedRoles: roles.isEmpty ? null : roles,
        lastModified: lastModified,
        usageCount: usageCount,
        source: template,
      );
    }).toList();
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.colors,
    required this.onCreate,
  });

  final _TemplateColors colors;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Template Builder',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.title,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create and manage reusable templates for workflows, checklists, and reports',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.muted,
                  ),
            ),
          ],
        );
        final createButton = ElevatedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('New Template'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              createButton,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: createButton,
            ),
          ],
        );
      },
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({
    required this.colors,
    required this.selectedType,
    required this.onSelected,
  });

final _TemplateColors colors;
final _TemplateType selectedType;
final ValueChanged<_TemplateType> onSelected;

@override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _TemplateType.values.map((type) {
          final isSelected = selectedType == type;
          return TextButton.icon(
            onPressed: () => onSelected(type),
            icon: Icon(
              _typeIcon(type),
              size: 16,
            ),
            label: Text(_typeLabel(type)),
            style: TextButton.styleFrom(
              backgroundColor:
                  isSelected ? colors.primary : colors.tabSurface,
              foregroundColor: isSelected ? Colors.white : colors.muted,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TemplatesGrid extends StatelessWidget {
  const _TemplatesGrid({
    required this.templates,
    required this.colors,
    required this.type,
    required this.onCreate,
    required this.onDuplicate,
    required this.onEdit,
  });

  final List<_TemplateCardData> templates;
  final _TemplateColors colors;
  final _TemplateType type;
  final VoidCallback onCreate;
  final ValueChanged<_TemplateCardData> onDuplicate;
  final ValueChanged<_TemplateCardData> onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 760
                ? 2
                : 1;
        final ratio = columns == 1 ? 0.95 : 0.85;
        final items = <Widget>[
          ...templates.map<Widget>(
            (template) => _TemplateCard(
              template: template,
              colors: colors,
              onDuplicate: () => onDuplicate(template),
              onEdit: () => onEdit(template),
            ),
          ),
          _NewTemplateCard(
            colors: colors,
            type: type,
            onTap: onCreate,
          ),
        ];
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: ratio,
          children: items,
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.colors,
    required this.onDuplicate,
    required this.onEdit,
  });

  final _TemplateCardData template;
  final _TemplateColors colors;
  final VoidCallback onDuplicate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final lastUpdated = DateFormat.yMd().format(template.lastModified);
    final typeAccent = _typeAccent(template.type);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.title,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      template.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _typeBadgeLabel(template.type),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: typeAccent,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (template.steps != null && template.steps!.isNotEmpty) ...[
            Text(
              'Steps (${template.steps!.length}):',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ...template.steps!.take(3).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colors.subtleSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${idx + 1}',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: colors.muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.body),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (template.steps!.length > 3)
              Text(
                '+${template.steps!.length - 3} more steps',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colors.muted),
              ),
            const SizedBox(height: 12),
          ],
          if (template.fields != null && template.fields!.isNotEmpty) ...[
            Text(
              'Fields (${template.fields!.length}):',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...template.fields!.take(4).map(
                      (field) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.subtleSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          field,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: colors.body),
                        ),
                      ),
                    ),
                if (template.fields!.length > 4)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.subtleSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+${template.fields!.length - 4}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: colors.muted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (template.assignedRoles != null &&
              template.assignedRoles!.isNotEmpty) ...[
            Text(
              'Assigned Roles:',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: template.assignedRoles!
                  .map(
                    (role) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.purpleSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        role,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: colors.purple),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final used = Text(
                'Used ${template.usageCount} times',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colors.muted),
              );
              final updated = Text(
                'Updated $lastUpdated',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colors.muted),
              );
              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    used,
                    const SizedBox(height: 4),
                    updated,
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  used,
                  updated,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDuplicate,
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Duplicate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.muted,
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewTemplateCard extends StatelessWidget {
  const _NewTemplateCard({
    required this.colors,
    required this.type,
    required this.onTap,
  });

  final _TemplateColors colors;
  final _TemplateType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 40, color: colors.muted),
            const SizedBox(height: 12),
            Text(
              'Create New ${_typeBadgeLabel(type)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.title,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Build a custom template from scratch',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.muted,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturesGrid extends StatelessWidget {
  const _FeaturesGrid({required this.colors});

  final _TemplateColors colors;

  @override
  Widget build(BuildContext context) {
    const features = [
      _FeatureItem(
        title: 'Version Control',
        description: 'Auto-save with complete version history',
      ),
      _FeatureItem(
        title: 'Role Assignment',
        description: 'Assign templates to specific roles or teams',
      ),
      _FeatureItem(
        title: 'Conditional Logic',
        description: 'Add smart fields with dynamic behavior',
      ),
      _FeatureItem(
        title: 'Export & Share',
        description: 'Export templates or share across projects',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 680
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 1 ? 3.4 : 1.8,
          children: features.map((feature) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.save_outlined, color: colors.primary, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    feature.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.title,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.muted,
                        ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF7F1D1D)),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TemplateType { workflow, checklist, report, form }

class _TemplateCardData {
  const _TemplateCardData({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.lastModified,
    required this.usageCount,
    this.steps,
    this.fields,
    this.assignedRoles,
    this.source,
  });

  final String id;
  final String name;
  final _TemplateType type;
  final String description;
  final List<String>? steps;
  final List<String>? fields;
  final List<String>? assignedRoles;
  final DateTime lastModified;
  final int usageCount;
  final AppTemplate? source;
}

class _FeatureItem {
  const _FeatureItem({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

class _TemplateColors {
  const _TemplateColors({
    required this.background,
    required this.surface,
    required this.subtleSurface,
    required this.border,
    required this.muted,
    required this.body,
    required this.title,
    required this.primary,
    required this.primarySurface,
    required this.purple,
    required this.purpleSurface,
    required this.tabSurface,
  });

  final Color background;
  final Color surface;
  final Color subtleSurface;
  final Color border;
  final Color muted;
  final Color body;
  final Color title;
  final Color primary;
  final Color primarySurface;
  final Color purple;
  final Color purpleSurface;
  final Color tabSurface;

  factory _TemplateColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF2563EB);
    const purple = Color(0xFF8B5CF6);
    return _TemplateColors(
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      surface: isDark ? const Color(0xFF1F2937) : Colors.white,
      subtleSurface:
          isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      muted: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      body: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      title: isDark ? Colors.white : const Color(0xFF111827),
      primary: primary,
      primarySurface: isDark
          ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
          : const Color(0xFFDBEAFE),
      purple: purple,
      purpleSurface: isDark
          ? const Color(0xFF4C1D95).withValues(alpha: 0.25)
          : const Color(0xFFEDE9FE),
      tabSurface: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
    );
  }
}

_TemplateType _normalizeType(String type) {
  switch (type.toLowerCase()) {
    case 'checklist':
      return _TemplateType.checklist;
    case 'report':
      return _TemplateType.report;
    case 'form':
      return _TemplateType.form;
    case 'project':
      return _TemplateType.form;
    default:
      return _TemplateType.workflow;
  }
}

String _typeLabel(_TemplateType type) {
  switch (type) {
    case _TemplateType.checklist:
      return 'Checklists';
    case _TemplateType.report:
      return 'Reports';
    case _TemplateType.form:
      return 'Forms';
    default:
      return 'Workflows';
  }
}

String _typeBadgeLabel(_TemplateType type) {
  switch (type) {
    case _TemplateType.checklist:
      return 'Checklist';
    case _TemplateType.report:
      return 'Report';
    case _TemplateType.form:
      return 'Form';
    default:
      return 'Workflow';
  }
}

IconData _typeIcon(_TemplateType type) {
  switch (type) {
    case _TemplateType.checklist:
      return Icons.check_box_outlined;
    case _TemplateType.report:
      return Icons.description_outlined;
    case _TemplateType.form:
      return Icons.edit_outlined;
    default:
      return Icons.groups_outlined;
  }
}

List<String> _stepsFromPayload(Map<String, dynamic> payload) {
  final steps = payload['steps'] as List?;
  if (steps != null) {
    return steps
        .map(
          (step) => Map<String, dynamic>.from(step as Map)['title']?.toString(),
        )
        .whereType<String>()
        .where((title) => title.trim().isNotEmpty)
        .toList();
  }
  final items = payload['items'] as List?;
  if (items != null) {
    return items
        .map(
          (item) => Map<String, dynamic>.from(item as Map)['label']?.toString(),
        )
        .whereType<String>()
        .where((label) => label.trim().isNotEmpty)
        .toList();
  }
  return const [];
}

Color _typeAccent(_TemplateType type) {
  switch (type) {
    case _TemplateType.checklist:
      return const Color(0xFF10B981);
    case _TemplateType.report:
      return const Color(0xFFF97316);
    case _TemplateType.form:
      return const Color(0xFF8B5CF6);
    case _TemplateType.workflow:
      return const Color(0xFF2563EB);
  }
}

List<String> _fieldsFromPayload(Map<String, dynamic> payload) {
  final fields = payload['fields'] as List?;
  if (fields != null) {
    return fields
        .map((field) => Map<String, dynamic>.from(field as Map)['label']?.toString())
        .whereType<String>()
        .where((label) => label.trim().isNotEmpty)
        .toList();
  }
  final sections = payload['sections'] as List?;
  if (sections != null) {
    return sections.map((section) => section.toString()).toList();
  }
  return const [];
}

int? _metaInt(Map<String, dynamic>? metadata, List<String> keys) {
  if (metadata == null) return null;
  for (final key in keys) {
    final value = metadata[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}
