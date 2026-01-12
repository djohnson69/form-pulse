import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../dashboard/data/dashboard_provider.dart';
import '../../../dashboard/data/active_role_provider.dart';
import '../../../dashboard/presentation/pages/create_form_page.dart';
import '../../../dashboard/presentation/pages/form_detail_page.dart';
import '../../../dashboard/presentation/pages/form_fill_page.dart';
import '../../data/quick_action_provider.dart';

enum _FormsViewMode { grid, list }

class FormsPage extends ConsumerStatefulWidget {
  const FormsPage({super.key});

  @override
  ConsumerState<FormsPage> createState() => _FormsPageState();
}

class _FormsPageState extends ConsumerState<FormsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterCategory = 'all';
  _FormsViewMode _viewMode = _FormsViewMode.grid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dashboardDataProvider);
    final role = ref.watch(activeRoleProvider);
    final canManageForms = _canManageForms(role);
    ref.listen<int>(createFormTriggerProvider, (previous, next) {
      if (previous == next) return;
      if (!canManageForms) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFormEditor(context);
      });
    });
    return Scaffold(
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _FormsErrorView(error: e.toString()),
        data: (payload) {
          final submissionsByForm = _buildSubmissionCounts(payload.submissions);
          final models = payload.forms
              .map(
                (form) => _FormViewModel.fromForm(
                  form,
                  submissions: submissionsByForm[form.id] ?? 0,
                ),
              )
              .toList();
          final categories = _buildCategories(models);
          final filtered = _applyFilters(models);
          final stats = _FormStats.fromModels(
            models,
            totalSubmissions: payload.submissions.length,
            categoryCount: categories.isEmpty ? 0 : categories.length - 1,
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardDataProvider);
              await ref.read(dashboardDataProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(context, canManageForms),
                const SizedBox(height: 16),
                _FormStatsGrid(stats: stats),
                const SizedBox(height: 16),
                _buildFilters(context, categories),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  _EmptyFormsCard(
                    onClear: _clearFilters,
                    onCreate:
                        canManageForms ? () => _openFormEditor(context) : null,
                  )
                else
                  _buildFormsBody(context, filtered, canManageForms),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool canManageForms) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Forms Management',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create and manage forms for data collection',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );

        final controls = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ViewToggle(
              selected: _viewMode,
              onChanged: (mode) => setState(() => _viewMode = mode),
            ),
            if (canManageForms)
              FilledButton.icon(
                onPressed: () => _openFormEditor(context),
                icon: const Icon(Icons.add),
                label: Text(isWide ? 'Create New Form' : 'New Form'),
              ),
          ],
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              controls,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 12),
            controls,
          ],
        );
      },
    );
  }

  Widget _buildFilters(BuildContext context, List<String> categories) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;
          final children = [
            Expanded(
              flex: isWide ? 2 : 0,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search forms...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
              ),
            ),
            SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _filterCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(
                          category == 'all' ? 'All Categories' : category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _filterCategory = value ?? 'all');
                },
              ),
            ),
            SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_list),
              label: const Text('More Filters'),
            ),
          ];

          if (isWide) {
            return Row(children: children);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        },
      ),
    );
  }

  Widget _buildFormsBody(
    BuildContext context,
    List<_FormViewModel> forms,
    bool canManageForms,
  ) {
    if (_viewMode == _FormsViewMode.grid) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 1100 ? 3 : (width >= 720 ? 2 : 1);
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: crossAxisCount > 1 ? 0.9 : 0.85,
            children: forms
                .map(
                  (form) => _FormGridCard(
                    model: form,
                    canManageForms: canManageForms,
                    onFill: () => _startForm(context, form.form),
                    onView: () => _openDetail(context, form.form),
                    onEdit: () => _openFormEditor(
                      context,
                      form: form.form,
                      mode: FormEditorMode.edit,
                    ),
                    onDuplicate: () => _openFormEditor(
                      context,
                      form: form.form,
                      mode: FormEditorMode.duplicate,
                    ),
                  ),
                )
                .toList(),
          );
        },
      );
    }

    return _FormListTable(
      forms: forms,
      onFill: (form) => _startForm(context, form),
      onEdit: (form) => _openFormEditor(
        context,
        form: form,
        mode: FormEditorMode.edit,
      ),
      canManageForms: canManageForms,
    );
  }

  void _openDetail(BuildContext context, FormDefinition form) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FormDetailPage(form: form)),
    );
  }

  void _startForm(BuildContext context, FormDefinition form) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FormFillPage(form: form)),
    );
  }

  void _openFormEditor(
    BuildContext context, {
    FormDefinition? form,
    FormEditorMode mode = FormEditorMode.create,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateFormPage(
          initialForm: form,
          mode: mode,
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _filterCategory = 'all';
    });
  }

  List<String> _buildCategories(List<_FormViewModel> forms) {
    final set = <String>{};
    for (final form in forms) {
      if (form.category.trim().isEmpty) continue;
      set.add(form.category);
    }
    final categories = set.toList()..sort();
    return ['all', ...categories];
  }

  List<_FormViewModel> _applyFilters(List<_FormViewModel> forms) {
    return forms.where((form) {
      final matchesSearch = _searchQuery.isEmpty ||
          form.title.toLowerCase().contains(_searchQuery) ||
          form.category.toLowerCase().contains(_searchQuery) ||
          form.tags.any((tag) => tag.toLowerCase().contains(_searchQuery));
      final matchesCategory =
          _filterCategory == 'all' || form.category == _filterCategory;
      return matchesSearch && matchesCategory;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Map<String, int> _buildSubmissionCounts(List<FormSubmission> submissions) {
    final counts = <String, int>{};
    for (final submission in submissions) {
      counts.update(submission.formId, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  bool _canManageForms(UserRole role) {
    return role == UserRole.supervisor || role.canManage;
  }
}

class _FormStats {
  const _FormStats({
    required this.totalForms,
    required this.activeForms,
    required this.draftForms,
    required this.totalSubmissions,
    required this.categoryCount,
    required this.avgCompletionMinutes,
  });

  final int totalForms;
  final int activeForms;
  final int draftForms;
  final int totalSubmissions;
  final int categoryCount;
  final double avgCompletionMinutes;

  String get activeLabel => '$activeForms active, $draftForms draft';

  factory _FormStats.fromModels(
    List<_FormViewModel> forms, {
    required int totalSubmissions,
    required int categoryCount,
  }) {
    final active = forms.where((form) => form.status == 'active').length;
    final draft = forms.length - active;
    final avgCompletion = _avgCompletion(forms) ?? 4.2;
    return _FormStats(
      totalForms: forms.length,
      activeForms: active,
      draftForms: draft,
      totalSubmissions: totalSubmissions,
      categoryCount: categoryCount,
      avgCompletionMinutes: avgCompletion,
    );
  }

  static double? _avgCompletion(List<_FormViewModel> forms) {
    final values = <double>[];
    for (final form in forms) {
      final meta = form.form.metadata ?? const <String, dynamic>{};
      final raw = meta['avgCompletionMinutes'] ??
          meta['avgCompletion'] ??
          meta['avgMinutes'];
      if (raw is num) {
        values.add(raw.toDouble());
      } else if (raw is String) {
        final parsed = double.tryParse(raw);
        if (parsed != null) values.add(parsed);
      }
    }
    if (values.isEmpty) return null;
    final total = values.fold<double>(0, (sum, v) => sum + v);
    return total / values.length;
  }
}

class _FormStatsGrid extends StatelessWidget {
  const _FormStatsGrid({required this.stats});

  final _FormStats stats;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final submissionsNoteColor =
        isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: crossAxisCount > 2 ? 2.3 : 1.5,
          children: [
            _FormStatCard(
              label: 'Total Forms',
              value: formatter.format(stats.totalForms),
              note: stats.activeLabel,
              icon: Icons.description_outlined,
              color: const Color(0xFF3B82F6),
            ),
            _FormStatCard(
              label: 'Total Submissions',
              value: formatter.format(stats.totalSubmissions),
              note: '+23% this month',
              icon: Icons.trending_up,
              color: const Color(0xFF22C55E),
              noteColor: submissionsNoteColor,
            ),
            _FormStatCard(
              label: 'Avg. Completion',
              value: '${stats.avgCompletionMinutes.toStringAsFixed(1)} min',
              note: 'Average time',
              icon: Icons.schedule,
              color: const Color(0xFF8B5CF6),
            ),
            _FormStatCard(
              label: 'Categories',
              value: formatter.format(stats.categoryCount),
              note: 'Form types',
              icon: Icons.star_rate_outlined,
              color: const Color(0xFFF59E0B),
            ),
          ],
        );
      },
    );
  }
}

class _FormStatCard extends StatelessWidget {
  const _FormStatCard({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
    this.noteColor,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
  final Color? noteColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final resolvedNoteColor = noteColor ?? const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              Icon(icon, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: resolvedNoteColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormGridCard extends StatelessWidget {
  const _FormGridCard({
    required this.model,
    required this.canManageForms,
    required this.onFill,
    required this.onView,
    required this.onEdit,
    required this.onDuplicate,
  });

  final _FormViewModel model;
  final bool canManageForms;
  final VoidCallback onFill;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final formatter = NumberFormat.decimalPattern();
    final menuItems = <PopupMenuEntry<String>>[
      const PopupMenuItem(value: 'view', child: Text('View details')),
      if (canManageForms)
        const PopupMenuItem(value: 'edit', child: Text('Edit form')),
      if (canManageForms)
        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
    ];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FormIconBadge(isDark: isDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (model.starred)
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Color(0xFFFBBF24),
                          ),
                        if (model.starred) const SizedBox(width: 6),
                        _StatusPill(status: model.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      model.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      model.category,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'view':
                      onView();
                      break;
                    case 'edit':
                      onEdit();
                      break;
                    case 'duplicate':
                      onDuplicate();
                      break;
                  }
                },
                itemBuilder: (context) => menuItems,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FormStatTile(
                  label: 'Submissions',
                  value: formatter.format(model.submissions),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FormStatTile(
                  label: 'Fields',
                  value: '${model.fields}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FormStatTile(
                  label: 'Author',
                  value: model.authorShort,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FormStatTile(
                  label: 'Updated',
                  value: model.updatedLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onFill,
                  child: const Text('Fill Form'),
                ),
              ),
              const SizedBox(width: 8),
              _IconActionButton(
                icon: Icons.visibility_outlined,
                onPressed: onView,
              ),
              if (canManageForms) ...[
                const SizedBox(width: 8),
                _IconActionButton(
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                ),
                const SizedBox(width: 8),
                _IconActionButton(
                  icon: Icons.copy_outlined,
                  onPressed: onDuplicate,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FormListTable extends StatelessWidget {
  const _FormListTable({
    required this.forms,
    required this.onFill,
    required this.onEdit,
    required this.canManageForms,
  });

  final List<_FormViewModel> forms;
  final ValueChanged<FormDefinition> onFill;
  final ValueChanged<FormDefinition> onEdit;
  final bool canManageForms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final formatter = NumberFormat.decimalPattern();
    final headerBackground = isDark
        ? const Color(0xFF111827).withValues(alpha: 0.5)
        : const Color(0xFFF9FAFB);
    final fillColor =
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final editColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1000),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: headerBackground,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  children: const [
                    _TableHeader(label: 'Form', flex: 3),
                    _TableHeader(label: 'Category', flex: 2),
                    _TableHeader(label: 'Submissions', flex: 2),
                    _TableHeader(label: 'Fields', flex: 1),
                    _TableHeader(label: 'Author', flex: 2),
                    _TableHeader(label: 'Updated', flex: 1),
                    _TableHeader(label: 'Status', flex: 1),
                    _TableHeader(label: 'Actions', flex: 2),
                  ],
                ),
              ),
              ...forms.map(
                (form) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: border)),
                  ),
                  child: Row(
                    children: [
                      _TableCell(
                        flex: 3,
                        child: Row(
                          children: [
                            if (form.starred)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Color(0xFFFBBF24),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                form.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TableCell(flex: 2, child: Text(form.category)),
                      _TableCell(
                        flex: 2,
                        child: Text(
                          formatter.format(form.submissions),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _TableCell(flex: 1, child: Text('${form.fields}')),
                      _TableCell(flex: 2, child: Text(form.author)),
                      _TableCell(flex: 1, child: Text(form.updatedLabel)),
                      _TableCell(
                        flex: 1,
                        child: _StatusPill(status: form.status),
                      ),
                      _TableCell(
                        flex: 2,
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () => onFill(form.form),
                              style: TextButton.styleFrom(
                                foregroundColor: fillColor,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Fill'),
                            ),
                            if (canManageForms) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => onEdit(form.form),
                                style: TextButton.styleFrom(
                                  foregroundColor: editColor,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Edit'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormViewModel {
  _FormViewModel({
    required this.form,
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.starred,
    required this.submissions,
    required this.fields,
    required this.author,
    required this.authorShort,
    required this.updatedAt,
    required this.tags,
  });

  final FormDefinition form;
  final String id;
  final String title;
  final String category;
  final String status;
  final bool starred;
  final int submissions;
  final int fields;
  final String author;
  final String authorShort;
  final DateTime updatedAt;
  final List<String> tags;

  String get updatedLabel => DateFormat('MMM d').format(updatedAt);

  factory _FormViewModel.fromForm(
    FormDefinition form, {
    required int submissions,
  }) {
    final metadata = form.metadata ?? const <String, dynamic>{};
    final status = _readString(metadata['status'], '').toLowerCase().trim();
    final resolvedStatus = status.isEmpty
        ? (form.isPublished ? 'active' : 'draft')
        : status;
    final starred = metadata['starred'] == true ||
        metadata['isStarred'] == true ||
        metadata['favorite'] == true;
    final category = (form.category ?? 'Other').trim();
    final author = _readAuthor(form, metadata);
    final authorShort = author.split(' ').first.isEmpty ? 'Team' : author.split(' ').first;
    return _FormViewModel(
      form: form,
      id: form.id,
      title: form.title,
      category: category.isEmpty ? 'Other' : category,
      status: resolvedStatus,
      starred: starred,
      submissions: submissions,
      fields: form.fields.length,
      author: author,
      authorShort: authorShort,
      updatedAt: form.updatedAt ?? form.createdAt,
      tags: form.tags ?? const <String>[],
    );
  }

  static String _readAuthor(
    FormDefinition form,
    Map<String, dynamic> metadata,
  ) {
    final author = _readString(
      metadata['author'] ??
          metadata['createdByName'] ??
          metadata['owner'] ??
          metadata['created_by_name'],
      '',
    );
    if (author.isNotEmpty) return author;
    final createdBy = form.createdBy.trim();
    if (createdBy.contains(' ')) return createdBy;
    if (createdBy.isNotEmpty) return 'Form Team';
    return 'Form Team';
  }

  static String _readString(dynamic value, String fallback) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }
}

class _FormStatTile extends StatelessWidget {
  const _FormStatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FormIconBadge extends StatelessWidget {
  const _FormIconBadge({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF2563EB), Color(0xFF1D4ED8)]
              : const [Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.description_outlined,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Icon(icon, size: 16),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = status.toLowerCase() == 'active';
    final background = isActive
        ? const Color(0xFF22C55E).withValues(alpha: 0.2)
        : (isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6));
    final foreground = isActive
        ? const Color(0xFF4ADE80)
        : (isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.selected, required this.onChanged});

  final _FormsViewMode selected;
  final ValueChanged<_FormsViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            icon: Icons.grid_view_outlined,
            isSelected: selected == _FormsViewMode.grid,
            onTap: () => onChanged(_FormsViewMode.grid),
          ),
          _ToggleButton(
            icon: Icons.view_list_outlined,
            isSelected: selected == _FormsViewMode.list,
            onTap: () => onChanged(_FormsViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF374151) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF111827))
              : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.label, required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.child, required this.flex});

  final Widget child;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodySmall!,
        child: child,
      ),
    );
  }
}

class _EmptyFormsCard extends StatelessWidget {
  const _EmptyFormsCard({required this.onClear, required this.onCreate});

  final VoidCallback onClear;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No forms match your filters.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Clear filters or create a new form to get started.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Clear filters'),
                  onPressed: onClear,
                ),
                if (onCreate != null)
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create form'),
                    onPressed: onCreate,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormsErrorView extends StatelessWidget {
  const _FormsErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $error'),
      ),
    );
  }
}
