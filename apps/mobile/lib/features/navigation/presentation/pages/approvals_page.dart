import 'package:flutter/material.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  final TextEditingController _commentController = TextEditingController();
  _ApprovalStatusFilter _filter = _ApprovalStatusFilter.pending;
  _ApprovalItem? _selectedItem;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ApprovalColors.fromTheme(Theme.of(context));
    final items = _demoApprovalItems;
    final filteredItems = items
        .where(
          (item) => _filter == _ApprovalStatusFilter.all ||
              _filter.name == item.status.name,
        )
        .toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(muted: colors.muted),
          const SizedBox(height: 16),
          _FilterBar(
            filter: _filter,
            colors: colors,
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final list = _ApprovalList(
                items: filteredItems,
                selectedItem: _selectedItem,
                colors: colors,
                onSelect: (item) => setState(() => _selectedItem = item),
              );
              final details = _ApprovalDetail(
                item: _selectedItem,
                colors: colors,
                commentController: _commentController,
                onApprove: _handleApprove,
                onReject: _handleReject,
                onRequestRevision: _handleRequestRevision,
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

  void _handleApprove() {
    if (_selectedItem == null) return;
    _showSnackBar('Approved: ${_selectedItem!.title}');
    _commentController.clear();
  }

  void _handleReject() {
    if (_selectedItem == null) return;
    if (_commentController.text.trim().isEmpty) {
      _showSnackBar('Please provide a reason for rejection');
      return;
    }
    _showSnackBar('Rejected: ${_selectedItem!.title}');
    _commentController.clear();
  }

  void _handleRequestRevision() {
    if (_selectedItem == null) return;
    if (_commentController.text.trim().isEmpty) {
      _showSnackBar('Please provide revision instructions');
      return;
    }
    _showSnackBar('Revision requested: ${_selectedItem!.title}');
    _commentController.clear();
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
  });

  final _ApprovalStatusFilter filter;
  final _ApprovalColors colors;
  final ValueChanged<_ApprovalStatusFilter> onChanged;

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
        children: _ApprovalStatusFilter.values.map((value) {
          final selected = filter == value;
          return TextButton(
            onPressed: () => onChanged(value),
            style: TextButton.styleFrom(
              backgroundColor: selected ? colors.primary : colors.filterSurface,
              foregroundColor: selected ? Colors.white : colors.muted,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(_filterLabel(value)),
          );
        }).toList(),
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
          final cardColor = selected
              ? colors.selectedSurface
              : colors.surface;
          final borderColor = selected ? colors.primary : colors.border;
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
                      Icon(Icons.description_outlined,
                          size: 18, color: _urgencyColor(item.urgency)),
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
                          color: colors.statusStyles[item.status]!.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.status.label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color:
                                    colors.statusStyles[item.status]!.foreground,
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
                        label: item.submittedBy,
                        colors: colors,
                      ),
                      const SizedBox(width: 8),
                      _MetaPill(
                        icon: Icons.schedule_outlined,
                        label: item.submittedDate,
                        colors: colors,
                      ),
                      const SizedBox(width: 8),
                      _MetaPill(
                        icon: Icons.attach_file_outlined,
                        label: '${item.attachments} files',
                        colors: colors,
                      ),
                    ],
                  ),
                  if (item.status == _ApprovalStatus.pending) ...[
                    const SizedBox(height: 8),
                    Divider(height: 1, color: colors.border),
                    const SizedBox(height: 6),
                    Text(
                      'Current Approver: ${item.currentApprover}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.muted,
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
  });

  final _ApprovalItem? item;
  final _ApprovalColors colors;
  final TextEditingController commentController;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestRevision;

  @override
  Widget build(BuildContext context) {
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
                  'Review & Approve',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.title,
                      ),
                ),
                const SizedBox(height: 12),
                _DetailRow(label: 'Document Type', value: item!.type.label, colors: colors),
                const SizedBox(height: 12),
                Text(
                  'Approval Chain',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                ...item!.approvers.asMap().entries.map(
                      (entry) => _ApproverRow(
                        index: entry.key,
                        approver: entry.value,
                        currentApprover: item!.currentApprover,
                        colors: colors,
                      ),
                    ),
                if (item!.status == _ApprovalStatus.pending) ...[
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

class _ApproverRow extends StatelessWidget {
  const _ApproverRow({
    required this.index,
    required this.approver,
    required this.currentApprover,
    required this.colors,
  });

  final int index;
  final String approver;
  final String currentApprover;
  final _ApprovalColors colors;

  @override
  Widget build(BuildContext context) {
    final isCurrent = approver == currentApprover;
    final circleColor = isCurrent ? colors.primary : colors.subtleSurface;
    final textColor = isCurrent ? colors.primary : colors.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: circleColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isCurrent ? Colors.white : colors.muted,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            approver,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor,
                ),
          ),
        ],
      ),
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

  final _ApprovalStatus status;
  final _ApprovalColors colors;

  @override
  Widget build(BuildContext context) {
    final style = colors.statusStyles[status]!;
    final message = switch (status) {
      _ApprovalStatus.approved => 'This item has been approved',
      _ApprovalStatus.rejected => 'This item has been rejected',
      _ApprovalStatus.needsRevision => 'Revisions requested',
      _ => 'Pending approval',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            status == _ApprovalStatus.approved
                ? Icons.check_circle
                : status == _ApprovalStatus.rejected
                    ? Icons.cancel
                    : Icons.warning_amber,
            color: style.foreground,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
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

enum _ApprovalStatusFilter { all, pending, approved, rejected }

String _filterLabel(_ApprovalStatusFilter filter) {
  switch (filter) {
    case _ApprovalStatusFilter.pending:
      return 'Pending';
    case _ApprovalStatusFilter.approved:
      return 'Approved';
    case _ApprovalStatusFilter.rejected:
      return 'Rejected';
    default:
      return 'All';
  }
}

enum _ApprovalStatus { pending, approved, rejected, needsRevision }

extension on _ApprovalStatus {
  String get label {
    switch (this) {
      case _ApprovalStatus.pending:
        return 'pending';
      case _ApprovalStatus.approved:
        return 'approved';
      case _ApprovalStatus.rejected:
        return 'rejected';
      case _ApprovalStatus.needsRevision:
        return 'needs revision';
    }
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
  final Map<_ApprovalStatus, _ApprovalStatusStyle> statusStyles;

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
        _ApprovalStatus.approved: _ApprovalStatusStyle(
          label: 'approved',
          background: success.withValues(alpha: isDark ? 0.2 : 0.15),
          foreground: isDark ? const Color(0xFF4ADE80) : success,
        ),
        _ApprovalStatus.rejected: _ApprovalStatusStyle(
          label: 'rejected',
          background: danger.withValues(alpha: isDark ? 0.2 : 0.15),
          foreground: isDark ? const Color(0xFFFCA5A5) : danger,
        ),
        _ApprovalStatus.needsRevision: _ApprovalStatusStyle(
          label: 'needs revision',
          background: warning.withValues(alpha: isDark ? 0.2 : 0.15),
          foreground: isDark ? const Color(0xFFFCD34D) : warning,
        ),
        _ApprovalStatus.pending: _ApprovalStatusStyle(
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
    required this.type,
    required this.title,
    required this.submittedBy,
    required this.submittedDate,
    required this.status,
    required this.description,
    required this.attachments,
    required this.urgency,
    required this.approvers,
    required this.currentApprover,
  });

  final String id;
  final _ApprovalType type;
  final String title;
  final String submittedBy;
  final String submittedDate;
  final _ApprovalStatus status;
  final String description;
  final int attachments;
  final _ApprovalUrgency urgency;
  final List<String> approvers;
  final String currentApprover;
}

enum _ApprovalType { report, form, document, incident }

extension on _ApprovalType {
  String get label {
    switch (this) {
      case _ApprovalType.report:
        return 'Report';
      case _ApprovalType.form:
        return 'Form';
      case _ApprovalType.document:
        return 'Document';
      case _ApprovalType.incident:
        return 'Incident';
    }
  }
}

enum _ApprovalUrgency { low, medium, high }

Color _urgencyColor(_ApprovalUrgency urgency) {
  switch (urgency) {
    case _ApprovalUrgency.high:
      return const Color(0xFFEF4444);
    case _ApprovalUrgency.medium:
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF6B7280);
  }
}

const _demoApprovalItems = [
  _ApprovalItem(
    id: '1',
    type: _ApprovalType.report,
    title: 'Weekly Safety Inspection Report - Building A',
    submittedBy: 'John Smith',
    submittedDate: '12/23/2025',
    status: _ApprovalStatus.pending,
    description:
        'Comprehensive safety inspection covering all zones with photos and recommendations',
    attachments: 12,
    urgency: _ApprovalUrgency.high,
    approvers: ['Safety Manager', 'Site Supervisor', 'Project Manager'],
    currentApprover: 'Safety Manager',
  ),
  _ApprovalItem(
    id: '2',
    type: _ApprovalType.form,
    title: 'Equipment Maintenance Request - Excavator #245',
    submittedBy: 'Mike Johnson',
    submittedDate: '12/22/2025',
    status: _ApprovalStatus.pending,
    description:
        'Hydraulic system showing signs of wear, requesting immediate maintenance',
    attachments: 5,
    urgency: _ApprovalUrgency.high,
    approvers: ['Maintenance Lead', 'Operations Manager'],
    currentApprover: 'Maintenance Lead',
  ),
  _ApprovalItem(
    id: '3',
    type: _ApprovalType.incident,
    title: 'Near Miss Report - Falling Tools',
    submittedBy: 'Sarah Williams',
    submittedDate: '12/21/2025',
    status: _ApprovalStatus.approved,
    description:
        'Tools fell from scaffolding, no injuries. Immediate safety measures implemented.',
    attachments: 8,
    urgency: _ApprovalUrgency.medium,
    approvers: ['Safety Manager', 'Site Supervisor'],
    currentApprover: '',
  ),
  _ApprovalItem(
    id: '4',
    type: _ApprovalType.document,
    title: 'Material Purchase Order - Concrete Supplies',
    submittedBy: 'Tom Brown',
    submittedDate: '12/20/2025',
    status: _ApprovalStatus.needsRevision,
    description: 'Purchase order for next phase concrete delivery',
    attachments: 3,
    urgency: _ApprovalUrgency.low,
    approvers: ['Purchasing Manager', 'Project Manager', 'Finance Director'],
    currentApprover: 'Purchasing Manager',
  ),
];
