import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/approvals_provider.dart';
import '../../../dashboard/data/active_role_provider.dart';

class ApprovalsPage extends ConsumerStatefulWidget {
  const ApprovalsPage({super.key});

  @override
  ConsumerState<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends ConsumerState<ApprovalsPage> {
  final TextEditingController _commentController = TextEditingController();
  _ApprovalStatusFilter _filter = _ApprovalStatusFilter.pending;
  _ApprovalItem? _selectedItem;
  String _searchQuery = '';

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ApprovalColors.fromTheme(Theme.of(context));
    final approvalsAsync = ref.watch(approvalsProvider);
    final role = ref.watch(activeRoleProvider);
    final items = approvalsAsync.maybeWhen(
      data: (data) => data,
      orElse: () => const <ApprovalItem>[],
    );
    final viewItems = items.map(_toViewModel).toList();
    final filteredItems = viewItems.where((item) {
      final matchesFilter = _matchesFilter(item.status, _filter);
      final matchesSearch = _searchQuery.isEmpty ||
          item.title.toLowerCase().contains(_searchQuery) ||
          item.typeLabel.toLowerCase().contains(_searchQuery) ||
          item.requestedBy.toLowerCase().contains(_searchQuery);
      return matchesFilter && matchesSearch;
    }).toList();
    final selectedView = _resolveSelection(filteredItems);
    final stats = _ApprovalStats.fromItems(viewItems);

    return Scaffold(
      backgroundColor: colors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(muted: colors.muted),
          const SizedBox(height: 16),
          _ApprovalStatsGrid(colors: colors, stats: stats),
          const SizedBox(height: 12),
          _FilterBar(
            filter: _filter,
            colors: colors,
            onChanged: (value) => setState(() => _filter = value),
            searchQuery: _searchQuery,
            onSearchChanged: (value) =>
                setState(() => _searchQuery = value.toLowerCase()),
          ),
          if (approvalsAsync.isLoading) const LinearProgressIndicator(),
          if (approvalsAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Failed to load approvals',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final list = _ApprovalList(
                items: filteredItems,
                selectedItem: selectedView,
                colors: colors,
                onSelect: (item) => setState(() => _selectedItem = item),
              );
              final details = _ApprovalDetail(
                item: selectedView,
                colors: colors,
                commentController: _commentController,
                onApprove: () => _handleStatusChange(selectedView, 'approved'),
                onReject: () => _handleStatusChange(selectedView, 'rejected'),
                onRequestRevision: () =>
                    _handleStatusChange(selectedView, 'revision'),
                role: role,
              );
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: list),
                    const SizedBox(width: 16),
                    Expanded(child: details),
                  ],
                );
              }
              return Column(
                children: [
                  list,
                  const SizedBox(height: 16),
                  details,
                ],
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  _ApprovalItem? _resolveSelection(List<_ApprovalItem> items) {
    if (items.isEmpty) return null;
    if (_selectedItem != null) {
      final match = items.firstWhere(
        (item) => item.id == _selectedItem!.id,
        orElse: () => items.first,
      );
      return match;
    }
    return items.first;
  }

  Future<void> _handleStatusChange(
    _ApprovalItem? selected,
    String status,
  ) async {
    final item = selected ?? _selectedItem;
    if (item == null) return;
    if ((status == 'rejected' || status == 'revision') &&
        _commentController.text.trim().isEmpty) {
      _showSnackBar('Please add notes before ${status == 'rejected' ? 'rejecting' : 'requesting revision'}');
      return;
    }
    final repo = ref.read(approvalsRepositoryProvider);
    try {
      final updated = await repo.updateStatus(
        id: item.id,
        status: status,
        notes: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
      setState(() {
        _selectedItem = _toViewModel(updated);
      });
      ref.invalidate(approvalsProvider);
      _commentController.clear();
      _showSnackBar('${status[0].toUpperCase()}${status.substring(1)}: ${item.title}');
    } on PostgrestException catch (e) {
      _showSnackBar('Update failed: ${e.message}');
    } catch (e) {
      _showSnackBar('Update failed: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF111827);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Approval Workflow',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          "Review and approve reports, forms, and documents before they're shared with stakeholders",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.colors,
    required this.onChanged,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  final _ApprovalStatusFilter filter;
  final _ApprovalColors colors;
  final ValueChanged<_ApprovalStatusFilter> onChanged;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final buttons = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ApprovalStatusFilter.values.map((value) {
              final selected = filter == value;
              return TextButton(
                onPressed: () => onChanged(value),
                style: TextButton.styleFrom(
                  backgroundColor:
                      selected ? colors.primary : colors.filterSurface,
                  foregroundColor: selected ? Colors.white : colors.muted,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_filterLabel(value)),
              );
            }).toList(),
          );
          final searchField = SizedBox(
            width: isWide ? 280 : double.infinity,
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search approvals...',
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.primary),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: onSearchChanged,
              controller: TextEditingController.fromValue(
                TextEditingValue(
                  text: searchQuery,
                  selection:
                      TextSelection.collapsed(offset: searchQuery.length),
                ),
              ),
            ),
          );

          if (isWide) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: buttons),
                const SizedBox(width: 12),
                searchField,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buttons,
              const SizedBox(height: 12),
              searchField,
            ],
          );
        },
      ),
    );
  }
}

class _ApprovalList extends StatelessWidget {
  const _ApprovalList({
    required this.items,
    required this.selectedItem,
    required this.colors,
    required this.onSelect,
  });

  final List<_ApprovalItem> items;
  final _ApprovalItem? selectedItem;
  final _ApprovalColors colors;
  final ValueChanged<_ApprovalItem> onSelect;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.inbox_outlined, color: colors.muted),
            const SizedBox(width: 8),
            Text(
              'No approvals to review',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.muted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Items Awaiting Approval (${items.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.title,
              ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          final selected = selectedItem?.id == item.id;
          final cardColor =
              selected ? colors.selectedSurface : colors.surface;
          final borderColor = selected ? colors.primary : colors.border;
          final statusStyle = _statusStyleFor(colors, item.status);
          return GestureDetector(
            onTap: () => onSelect(item),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_typeIcon(item.type), size: 18, color: colors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.title,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusStyle.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.statusLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: statusStyle.foreground,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _MetaPill(
                        icon: Icons.person_outline,
                        label: item.requestedBy,
                        colors: colors,
                      ),
                      const SizedBox(width: 8),
                      _MetaPill(
                        icon: Icons.schedule_outlined,
                        label: item.requestedDate,
                        colors: colors,
                      ),
                      const SizedBox(width: 8),
                      _MetaPill(
                        icon: Icons.category_outlined,
                        label: item.typeLabel,
                        colors: colors,
                      ),
                    ],
                  ),
                  if (item.notes?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Requester notes: ${item.notes}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.body,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ApprovalDetail extends StatelessWidget {
  const _ApprovalDetail({
    required this.item,
    required this.colors,
    required this.commentController,
    required this.onApprove,
    required this.onReject,
    required this.onRequestRevision,
    required this.role,
  });

  final _ApprovalItem? item;
  final _ApprovalColors colors;
  final TextEditingController commentController;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestRevision;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final canAct = _canAct(role);
    final canChangeStatus = item != null && _canChangeStatus(item!.status);
    final showActions = canAct && canChangeStatus;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: item == null
          ? _EmptyDetail(colors: colors)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item!.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.title,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _DetailRow(
                      label: 'Type',
                      value: item!.typeLabel,
                      colors: colors,
                    ),
                    _DetailRow(
                      label: 'Requested by',
                      value: item!.requestedBy,
                      colors: colors,
                    ),
                    _DetailRow(
                      label: 'Requested at',
                      value: item!.requestedDate,
                      colors: colors,
                    ),
                    _DetailRow(
                      label: 'Status',
                      value: item!.statusLabel,
                      colors: colors,
                    ),
                    _DetailRow(
                      label: 'Attachments',
                      value:
                          '${item!.attachments} file${item!.attachments == 1 ? '' : 's'}',
                      colors: colors,
                    ),
                    if (item!.approvers.isNotEmpty)
                      _DetailRow(
                        label: 'Approvers',
                        value: item!.approvers.join(', '),
                        colors: colors,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  item!.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.body,
                      ),
                ),
                if (item!.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Requester notes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item!.notes!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.body,
                        ),
                  ),
                ],
                if (showActions) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Comments / Instructions',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.body,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'Add approval comments or revision instructions...',
                      filled: true,
                      fillColor: colors.subtleSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: 'Approve & Sign Off',
                    icon: Icons.check_circle_outline,
                    color: colors.success,
                    onPressed: onApprove,
                  ),
                  const SizedBox(height: 8),
                  _ActionButton(
                    label: 'Request Revisions',
                    icon: Icons.warning_amber_outlined,
                    color: colors.warning,
                    onPressed: onRequestRevision,
                  ),
                  const SizedBox(height: 8),
                  _ActionButton(
                    label: 'Reject',
                    icon: Icons.cancel_outlined,
                    color: colors.danger,
                    onPressed: onReject,
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  _StatusNotice(status: item!.status, colors: colors),
                  if (!canAct)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'You do not have permission to change this approval with the current role.',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.muted,
                                ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail({required this.colors});

  final _ApprovalColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.description_outlined, size: 48, color: colors.muted),
        const SizedBox(height: 12),
        Text(
          'Select an item to review',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.muted,
              ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final _ApprovalColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.muted,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.title,
              ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final _ApprovalColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: colors.muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.muted,
              ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({required this.status, required this.colors});

  final String status;
  final _ApprovalColors colors;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyleFor(colors, status);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _statusIcon(status),
            color: style.foreground,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage(status),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: style.foreground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ApprovalStatusFilter { all, pending, approved, rejected, revision }

String _filterLabel(_ApprovalStatusFilter filter) {
  switch (filter) {
    case _ApprovalStatusFilter.pending:
      return 'Pending';
    case _ApprovalStatusFilter.approved:
      return 'Approved';
    case _ApprovalStatusFilter.rejected:
      return 'Rejected';
    case _ApprovalStatusFilter.revision:
      return 'Needs revision';
    default:
      return 'All';
  }
}

class _ApprovalStats {
  const _ApprovalStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.revision,
  });

  final int total;
  final int pending;
  final int approved;
  final int rejected;
  final int revision;

  factory _ApprovalStats.fromItems(List<_ApprovalItem> items) {
    int pending = 0;
    int approved = 0;
    int rejected = 0;
    int revision = 0;
    for (final item in items) {
      switch (_normalizeStatus(item.status)) {
        case 'approved':
          approved++;
          break;
        case 'rejected':
          rejected++;
          break;
        case 'pending':
          pending++;
          break;
        case 'revision':
        case 'needs_revision':
          revision++;
          break;
        default:
          break;
      }
    }
    return _ApprovalStats(
      total: items.length,
      pending: pending,
      approved: approved,
      rejected: rejected,
      revision: revision,
    );
  }
}

class _ApprovalStatsGrid extends StatelessWidget {
  const _ApprovalStatsGrid({required this.colors, required this.stats});

  final _ApprovalColors colors;
  final _ApprovalStats stats;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final cards = [
      _StatCard(
        label: 'Total',
        value: stats.total.toString(),
        color: colors.primary,
        note: 'All items',
      ),
      _StatCard(
        label: 'Pending',
        value: stats.pending.toString(),
        color: colors.primary,
        note: 'Awaiting review',
      ),
      _StatCard(
        label: 'Approved',
        value: stats.approved.toString(),
        color: colors.success,
        note: 'Completed',
      ),
      _StatCard(
        label: 'Rejected',
        value: stats.rejected.toString(),
        color: colors.danger,
        note: 'Declined',
      ),
      _StatCard(
        label: 'Needs Revision',
        value: stats.revision.toString(),
        color: colors.warning,
        note: 'Pending updates',
      ),
    ];
    final crossAxisCount = isWide ? 5 : 2;
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: crossAxisCount > 2 ? 1.5 : 1.2,
      children: cards,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.note,
  });

  final String label;
  final String value;
  final Color color;
  final String note;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF0F172A) : Colors.white;
    final noteColor = isDark ? color.withValues(alpha: 0.8) : color;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: noteColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalStatusStyle {
  const _ApprovalStatusStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

class _ApprovalColors {
  const _ApprovalColors({
    required this.background,
    required this.surface,
    required this.subtleSurface,
    required this.border,
    required this.muted,
    required this.body,
    required this.title,
    required this.primary,
    required this.selectedSurface,
    required this.filterSurface,
    required this.success,
    required this.warning,
    required this.danger,
    required this.statusStyles,
  });

  final Color background;
  final Color surface;
  final Color subtleSurface;
  final Color border;
  final Color muted;
  final Color body;
  final Color title;
  final Color primary;
  final Color selectedSurface;
  final Color filterSurface;
  final Color success;
  final Color warning;
  final Color danger;
  final Map<String, _ApprovalStatusStyle> statusStyles;

  factory _ApprovalColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF2563EB);
    const success = Color(0xFF16A34A);
    const warning = Color(0xFFF59E0B);
    const danger = Color(0xFFDC2626);
    return _ApprovalColors(
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      surface: isDark ? const Color(0xFF1F2937) : Colors.white,
      subtleSurface:
          isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      muted: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      body: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      title: isDark ? Colors.white : const Color(0xFF111827),
      primary: primary,
      selectedSurface: isDark
          ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
          : const Color(0xFFDBEAFE),
      filterSurface: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
      success: success,
      warning: warning,
      danger: danger,
      statusStyles: {
        'approved': _ApprovalStatusStyle(
          label: 'approved',
          background: success.withValues(alpha: isDark ? 0.2 : 0.15),
          foreground: isDark ? const Color(0xFF4ADE80) : success,
        ),
        'rejected': _ApprovalStatusStyle(
          label: 'rejected',
          background: danger.withValues(alpha: isDark ? 0.2 : 0.15),
          foreground: isDark ? const Color(0xFFFCA5A5) : danger,
        ),
        'revision': _ApprovalStatusStyle(
          label: 'needs revision',
          background: warning.withValues(alpha: isDark ? 0.2 : 0.15),
          foreground: isDark ? const Color(0xFFFCD34D) : warning,
        ),
        'needs_revision': _ApprovalStatusStyle(
          label: 'needs revision',
          background: warning.withValues(alpha: isDark ? 0.2 : 0.15),
          foreground: isDark ? const Color(0xFFFCD34D) : warning,
        ),
        'pending': _ApprovalStatusStyle(
          label: 'pending',
          background: primary.withValues(alpha: isDark ? 0.2 : 0.15),
          foreground: isDark ? const Color(0xFF93C5FD) : primary,
        ),
      },
    );
  }
}

class _ApprovalItem {
  const _ApprovalItem({
    required this.id,
    required this.title,
    required this.description,
    required this.requestedBy,
    required this.requestedDate,
    required this.status,
    required this.statusLabel,
    required this.type,
    required this.typeLabel,
    required this.attachments,
    required this.approvers,
    this.notes,
  });

  final String id;
  final String title;
  final String description;
  final String requestedBy;
  final String requestedDate;
  final String status;
  final String statusLabel;
  final String type;
  final String typeLabel;
  final int attachments;
  final List<String> approvers;
  final String? notes;
}

_ApprovalItem _toViewModel(ApprovalItem item) {
  final statusKey = _normalizeStatus(item.status);
  final requestedBy = _formatRequestedBy(item.requestedBy);
  return _ApprovalItem(
    id: item.id,
    title: item.title.trim().isEmpty ? 'Approval' : item.title.trim(),
    description: item.description.trim().isEmpty
        ? 'No description provided'
        : item.description.trim(),
    requestedBy: requestedBy,
    requestedDate: _formatRequestedAt(item.requestedAt),
    status: statusKey,
    statusLabel: _statusLabel(statusKey),
    type: item.type,
    typeLabel: _typeLabel(item.type),
    attachments: 0,
    approvers: const [],
    notes: item.notes?.trim().isEmpty == true ? null : item.notes?.trim(),
  );
}

bool _matchesFilter(String status, _ApprovalStatusFilter filter) {
  final normalized = _normalizeStatus(status);
  switch (filter) {
    case _ApprovalStatusFilter.all:
      return true;
    case _ApprovalStatusFilter.pending:
      return normalized == 'pending';
    case _ApprovalStatusFilter.approved:
      return normalized == 'approved';
    case _ApprovalStatusFilter.rejected:
      return normalized == 'rejected';
    case _ApprovalStatusFilter.revision:
      return normalized == 'revision' || normalized == 'needs_revision';
  }
}

String _normalizeStatus(String status) =>
    status.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');

String _statusLabel(String status) {
  final normalized = _normalizeStatus(status);
  switch (normalized) {
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    case 'revision':
    case 'needs_revision':
      return 'Needs revision';
    default:
      return 'Pending';
  }
}

_ApprovalStatusStyle _statusStyleFor(
  _ApprovalColors colors,
  String status,
) {
  final normalized = _normalizeStatus(status);
  return colors.statusStyles[normalized] ??
      colors.statusStyles['pending']!;
}

String _statusMessage(String status) {
  final normalized = _normalizeStatus(status);
  switch (normalized) {
    case 'approved':
      return 'This item has been approved';
    case 'rejected':
      return 'This item has been rejected';
    case 'revision':
    case 'needs_revision':
      return 'Revisions requested';
    default:
      return 'Pending approval';
  }
}

IconData _statusIcon(String status) {
  final normalized = _normalizeStatus(status);
  switch (normalized) {
    case 'approved':
      return Icons.check_circle;
    case 'rejected':
      return Icons.cancel;
    case 'revision':
    case 'needs_revision':
      return Icons.warning_amber;
    default:
      return Icons.hourglass_bottom;
  }
}

bool _canAct(UserRole role) {
  return role == UserRole.superAdmin ||
      role == UserRole.admin ||
      role == UserRole.manager ||
      role == UserRole.supervisor ||
      role == UserRole.techSupport;
}

bool _canChangeStatus(String status) {
  final normalized = _normalizeStatus(status);
  return normalized == 'pending' ||
      normalized == 'revision' ||
      normalized == 'needs_revision';
}

String _formatRequestedAt(DateTime dateTime) {
  final date = DateFormat.yMMMd().format(dateTime);
  final time = DateFormat.jm().format(dateTime);
  return '$date · $time';
}

String _formatRequestedBy(String? value) {
  if (value == null || value.trim().isEmpty) return 'Unknown requester';
  return value.trim();
}

String _typeLabel(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'General';
  return value[0].toUpperCase() + value.substring(1);
}

IconData _typeIcon(String raw) {
  final value = raw.toLowerCase();
  if (value.contains('form')) return Icons.description_outlined;
  if (value.contains('document')) return Icons.insert_drive_file_outlined;
  if (value.contains('sop')) return Icons.rule_folder_outlined;
  if (value.contains('incident')) return Icons.report_gmailerrorred_outlined;
  if (value.contains('report')) return Icons.analytics_outlined;
  return Icons.assignment_outlined;
}
