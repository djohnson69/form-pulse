import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../dashboard/data/active_role_provider.dart';

class WorkOrdersPage extends ConsumerStatefulWidget {
  const WorkOrdersPage({super.key});

  @override
  ConsumerState<WorkOrdersPage> createState() => _WorkOrdersPageState();
}

class _WorkOrdersPageState extends ConsumerState<WorkOrdersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _priorityFilter = 'all';
  String _typeFilter = 'all';
  String? _expandedOrderId;
  late final List<WorkOrder> _orders = _seedOrders();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(activeRoleProvider);
    final userName = _demoUserName(role);
    final teamMembers = _demoTeamMembers(role);
    final visibleOrders =
        _applyRoleVisibility(_orders, role, userName, teamMembers);
    final filteredOrders = _applyFilters(visibleOrders);
    final stats = _WorkOrderStats.fromOrders(visibleOrders);
    final canManage = _canManageOrders(role);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(
            context,
            role,
            filteredOrders.length,
            canManage,
          ),
          const SizedBox(height: 16),
          _buildStatsGrid(context, stats),
          const SizedBox(height: 16),
          _buildFilters(context),
          const SizedBox(height: 16),
          _buildOrdersSection(
            context,
            filteredOrders,
            canManage,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    UserRole role,
    int visibleCount,
    bool canManage,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accessLabel = _accessLabel(role, visibleCount);
    final roleDescription = _roleDescription(role);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Work Orders',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              roleDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            if (accessLabel != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A8A).withOpacity(0.2)
                      : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF60A5FA).withOpacity(0.3)
                        : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        accessLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isDark
                              ? const Color(0xFFBFDBFE)
                              : const Color(0xFF1D4ED8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );

        final actions = Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export'),
            ),
            if (canManage)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _openCreateDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Create Work Order'),
              ),
          ],
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 16),
            actions,
          ],
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, _WorkOrderStats stats) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = 2;
        if (constraints.maxWidth >= 1100) {
          columns = 6;
        } else if (constraints.maxWidth >= 780) {
          columns = 3;
        }
        final aspectRatio = columns >= 6
            ? 1.15
            : columns == 3
                ? 1.4
                : 1.55;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(
              title: 'Total',
              value: stats.total.toString(),
              subtitle: 'All work orders',
              icon: Icons.bar_chart,
              iconColor: isDark ? Colors.grey[500]! : Colors.grey[400]!,
              borderColor: borderColor,
            ),
            _StatCard(
              title: 'Open',
              value: stats.open.toString(),
              subtitle: 'Awaiting assignment',
              icon: Icons.error_outline,
              iconColor: const Color(0xFF3B82F6),
              borderColor: borderColor,
            ),
            _StatCard(
              title: 'In Progress',
              value: stats.inProgress.toString(),
              subtitle: 'Currently active',
              icon: Icons.play_circle_outline,
              iconColor: const Color(0xFFF59E0B),
              borderColor: borderColor,
            ),
            _StatCard(
              title: 'On Hold',
              value: stats.onHold.toString(),
              subtitle: 'Waiting on parts',
              icon: Icons.pause_circle_outline,
              iconColor: const Color(0xFFF97316),
              borderColor: borderColor,
            ),
            _StatCard(
              title: 'Completed',
              value: stats.completed.toString(),
              subtitle: 'This month',
              icon: Icons.check_circle_outline,
              iconColor: const Color(0xFF22C55E),
              borderColor: borderColor,
            ),
            _StatCard(
              title: 'Urgent',
              value: stats.urgent.toString(),
              subtitle: 'Immediate attention',
              icon: Icons.warning_amber,
              iconColor: const Color(0xFFEF4444),
              borderColor: borderColor,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          if (isWide) {
            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search work orders, assets, locations...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.trim().toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildStatusFilter()),
                const SizedBox(width: 12),
                Expanded(child: _buildPriorityFilter()),
                const SizedBox(width: 12),
                Expanded(child: _buildTypeFilter()),
              ],
            );
          }
          return Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search work orders, assets, locations...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
              ),
              const SizedBox(height: 12),
              _buildStatusFilter(),
              const SizedBox(height: 12),
              _buildPriorityFilter(),
              const SizedBox(height: 12),
              _buildTypeFilter(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<String>(
      value: _statusFilter,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text('All Statuses', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'open',
          child: Text('Open', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'assigned',
          child: Text('Assigned', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'in-progress',
          child: Text('In Progress', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'on-hold',
          child: Text('On Hold', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'completed',
          child: Text('Completed', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'cancelled',
          child: Text('Cancelled', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: (value) {
        setState(() => _statusFilter = value ?? 'all');
      },
    );
  }

  Widget _buildPriorityFilter() {
    return DropdownButtonFormField<String>(
      value: _priorityFilter,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(
          value: 'all',
          child:
              Text('All Priorities', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'low',
          child: Text('Low', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'medium',
          child: Text('Medium', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'high',
          child: Text('High', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'urgent',
          child: Text('Urgent', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: (value) {
        setState(() => _priorityFilter = value ?? 'all');
      },
    );
  }

  Widget _buildTypeFilter() {
    return DropdownButtonFormField<String>(
      value: _typeFilter,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text('All Types', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'repair',
          child: Text('Repair', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'preventive',
          child:
              Text('Preventive', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'inspection',
          child: Text('Inspection', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'installation',
          child:
              Text('Installation', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'emergency',
          child: Text('Emergency', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: (value) {
        setState(() => _typeFilter = value ?? 'all');
      },
    );
  }

  Widget _buildOrdersSection(
    BuildContext context,
    List<WorkOrder> orders,
    bool canManage,
  ) {
    final theme = Theme.of(context);
    if (orders.isEmpty) {
      final isDark = theme.brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.handyman_outlined,
              size: 44,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No work orders found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your filters or create a new work order.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${orders.length} Work Order${orders.length == 1 ? '' : 's'}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...orders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WorkOrderCard(
              order: order,
              isExpanded: _expandedOrderId == order.id,
              canManage: canManage,
              onToggle: () {
                setState(() {
                  _expandedOrderId =
                      _expandedOrderId == order.id ? null : order.id;
                });
              },
              onEdit: () => _openEditDialog(context, order),
              onViewDetails: () =>
                  _openDetailsDialog(context, order, canManage),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final result = await showDialog<WorkOrderFormData>(
      context: context,
      builder: (context) => _WorkOrderFormDialog(
        title: 'Create New Work Order',
        actionLabel: 'Create Work Order',
        isCreate: true,
        initialData: WorkOrderFormData.empty(),
      ),
    );
    if (result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Work order created: ${result.title}'),
      ),
    );
  }

  Future<void> _openEditDialog(BuildContext context, WorkOrder order) async {
    final result = await showDialog<WorkOrderFormData>(
      context: context,
      builder: (context) => _WorkOrderFormDialog(
        title: 'Edit: ${order.number}',
        actionLabel: 'Save Changes',
        isCreate: false,
        initialData: WorkOrderFormData.fromOrder(order),
      ),
    );
    if (result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Work order updated: ${result.title}'),
      ),
    );
  }

  Future<void> _openDetailsDialog(
    BuildContext context,
    WorkOrder order,
    bool canManage,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _WorkOrderDetailsDialog(
        order: order,
        canManage: canManage,
        onEdit: () {
          Navigator.of(context).pop();
          _openEditDialog(context, order);
        },
      ),
    );
  }

  List<WorkOrder> _applyRoleVisibility(
    List<WorkOrder> orders,
    UserRole role,
    String userName,
    List<String> teamMembers,
  ) {
    if (role == UserRole.superAdmin ||
        role == UserRole.admin ||
        role == UserRole.techSupport) {
      return orders;
    }
    if (role == UserRole.manager) {
      return orders;
    }
    if (role == UserRole.supervisor) {
      return orders.where((order) {
        final assigned = order.assignedTo ?? '';
        return teamMembers.contains(assigned) ||
            teamMembers.contains(order.requester);
      }).toList();
    }
    if (role == UserRole.employee || role == UserRole.maintenance) {
      return orders.where((order) => order.assignedTo == userName).toList();
    }
    return orders;
  }

  List<WorkOrder> _applyFilters(List<WorkOrder> orders) {
    return orders.where((order) {
      final matchesSearch = _searchQuery.isEmpty ||
          order.title.toLowerCase().contains(_searchQuery) ||
          order.number.toLowerCase().contains(_searchQuery) ||
          order.asset.name.toLowerCase().contains(_searchQuery) ||
          order.asset.location.toLowerCase().contains(_searchQuery);
      final matchesStatus =
          _statusFilter == 'all' || order.status.filterValue == _statusFilter;
      final matchesPriority = _priorityFilter == 'all' ||
          order.priority.filterValue == _priorityFilter;
      final matchesType =
          _typeFilter == 'all' || order.type.filterValue == _typeFilter;
      return matchesSearch &&
          matchesStatus &&
          matchesPriority &&
          matchesType;
    }).toList();
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              Icon(icon, color: iconColor, size: 20),
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
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({
    required this.order,
    required this.isExpanded,
    required this.canManage,
    required this.onToggle,
    required this.onEdit,
    required this.onViewDetails,
  });

  final WorkOrder order;
  final bool isExpanded;
  final bool canManage;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final statusColor = _statusColor(order.status);
    final priorityColor = _priorityColor(order.priority, isDark);
    final typeIcon = _typeIcon(order.type);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            order.number,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontFamily: 'monospace',
                            ),
                          ),
                          _StatusBadge(
                            label: order.status.label.toUpperCase(),
                            color: statusColor,
                            icon: _statusIcon(order.status),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber,
                                  size: 16, color: priorityColor),
                              const SizedBox(width: 4),
                              Text(
                                order.priority.label,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: priorityColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(typeIcon,
                                  size: 16,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                order.type.label,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        order.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _MetaRow(
                            icon: Icons.inventory_2_outlined,
                            label: order.asset.name,
                          ),
                          _MetaRow(
                            icon: Icons.place_outlined,
                            label: order.asset.location,
                          ),
                          if (order.assignedTo != null)
                            _MetaRow(
                              icon: Icons.person_outline,
                              label: order.assignedTo!,
                            ),
                          _MetaRow(
                            icon: Icons.event_outlined,
                            label:
                                'Due: ${DateFormat('MMM d, yyyy').format(order.dueDate)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onToggle,
                  icon: Icon(
                    isExpanded
                        ? Icons.expand_less_outlined
                        : Icons.expand_more_outlined,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF111827)
                    : const Color(0xFFF9FAFB),
                border: Border(
                  top: BorderSide(color: borderColor),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _ChecklistAndParts(order: order)),
                            const SizedBox(width: 20),
                            Expanded(child: _NotesAndTime(order: order)),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _ChecklistAndParts(order: order),
                          const SizedBox(height: 16),
                          _NotesAndTime(order: order),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (canManage)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                      if (canManage) const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: onViewDetails,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('View Details'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChecklistAndParts extends StatelessWidget {
  const _ChecklistAndParts({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final partsTotal =
        order.parts.fold<double>(0, (sum, part) => sum + part.cost);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.checklist.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.list_alt,
                      size: 16,
                      color: isDark ? Colors.grey[300] : Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Checklist',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...order.checklist.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: item.completed
                              ? const Color(0xFF22C55E)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: item.completed
                                ? const Color(0xFF22C55E)
                                : isDark
                                    ? const Color(0xFF4B5563)
                                    : const Color(0xFFD1D5DB),
                            width: 2,
                          ),
                        ),
                        child: item.completed
                            ? const Icon(Icons.check,
                                size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.item,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: item.completed
                                ? (isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[400])
                                : (isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700]),
                            decoration: item.completed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        if (order.parts.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 16,
                      color: isDark ? Colors.grey[300] : Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Parts and Materials',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...order.parts.map(
                (part) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${part.name} (x${part.quantity})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? Colors.grey[300]
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                      Text(
                        '\$${part.cost.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.grey[100]
                              : Colors.grey[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Parts Cost',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey[200]
                            : Colors.grey[800],
                      ),
                    ),
                    Text(
                      '\$${partsTotal.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.grey[200]
                            : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _NotesAndTime extends StatelessWidget {
  const _NotesAndTime({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.notes.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.description_outlined,
                      size: 16,
                      color: isDark ? Colors.grey[300] : Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Notes',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...order.notes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1F2937)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF374151)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      '• $note',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        Row(
          children: [
            Icon(Icons.schedule_outlined,
                size: 16,
                color: isDark ? Colors.grey[300] : Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              'Time Tracking',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _TimeRow(
          label: 'Estimated Hours',
          value: '${order.estimatedHours}h',
        ),
        if (order.actualHours != null)
          _TimeRow(
            label: 'Actual Hours',
            value: '${order.actualHours}h',
          ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[100] : Colors.grey[900],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(isDark ? 0.4 : 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _WorkOrderFormDialog extends StatefulWidget {
  const _WorkOrderFormDialog({
    required this.title,
    required this.actionLabel,
    required this.isCreate,
    required this.initialData,
  });

  final String title;
  final String actionLabel;
  final bool isCreate;
  final WorkOrderFormData initialData;

  @override
  State<_WorkOrderFormDialog> createState() => _WorkOrderFormDialogState();
}

class _WorkOrderFormDialogState extends State<_WorkOrderFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _assetNameController;
  late final TextEditingController _assetLocationController;
  late final TextEditingController _assignedToController;
  late final TextEditingController _estimatedHoursController;
  late final TextEditingController _dueDateController;
  late WorkOrderPriority _priority;
  late WorkOrderType _type;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _titleController = TextEditingController(text: data.title);
    _descriptionController = TextEditingController(text: data.description);
    _assetNameController = TextEditingController(text: data.assetName);
    _assetLocationController = TextEditingController(text: data.assetLocation);
    _assignedToController = TextEditingController(text: data.assignedTo);
    _estimatedHoursController =
        TextEditingController(text: data.estimatedHours.toString());
    _priority = data.priority;
    _type = data.type;
    _dueDate = data.dueDate;
    _dueDateController = TextEditingController(
      text: _dueDate == null ? '' : DateFormat('yyyy-MM-dd').format(_dueDate!),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _assetNameController.dispose();
    _assetLocationController.dispose();
    _assignedToController.dispose();
    _estimatedHoursController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _FormField(
                      label: widget.isCreate ? 'Title *' : 'Title',
                      child: TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter work order title',
                        ),
                      ),
                    ),
                    _FormField(
                      label: widget.isCreate ? 'Description *' : 'Description',
                      child: TextFormField(
                        controller: _descriptionController,
                        minLines: 3,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Describe the issue or maintenance required',
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _FormField(
                            label: widget.isCreate ? 'Priority *' : 'Priority',
                            child: DropdownButtonFormField<WorkOrderPriority>(
                              value: _priority,
                              decoration:
                                  const InputDecoration(border: OutlineInputBorder()),
                              items: WorkOrderPriority.values
                                  .map(
                                    (priority) => DropdownMenuItem(
                                      value: priority,
                                      child: Text(priority.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _priority = value);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FormField(
                            label: widget.isCreate ? 'Type *' : 'Type',
                            child: DropdownButtonFormField<WorkOrderType>(
                              value: _type,
                              decoration:
                                  const InputDecoration(border: OutlineInputBorder()),
                              items: WorkOrderType.values
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _type = value);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.isCreate) ...[
                      _FormField(
                        label: 'Asset Name *',
                        child: TextFormField(
                          controller: _assetNameController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'e.g. HVAC Unit #1',
                          ),
                        ),
                      ),
                      _FormField(
                        label: 'Location *',
                        child: TextFormField(
                          controller: _assetLocationController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'e.g. Building A - Roof',
                          ),
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _FormField(
                            label: 'Assign To',
                            child: TextFormField(
                              controller: _assignedToController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Technician name',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FormField(
                            label: widget.isCreate ? 'Due Date *' : 'Due Date',
                            child: TextFormField(
                              controller: _dueDateController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Select date',
                              ),
                              onTap: () => _pickDueDate(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.isCreate)
                      _FormField(
                        label: 'Estimated Hours *',
                        child: TextFormField(
                          controller: _estimatedHoursController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF111827)
                    : const Color(0xFFF9FAFB),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _submit,
                    child: Text(widget.actionLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDueDate(BuildContext context) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (selected == null) return;
    setState(() {
      _dueDate = selected;
      _dueDateController.text = DateFormat('yyyy-MM-dd').format(selected);
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final assetName = _assetNameController.text.trim();
    final assetLocation = _assetLocationController.text.trim();
    if (title.isEmpty ||
        description.isEmpty ||
        assetName.isEmpty ||
        assetLocation.isEmpty ||
        _dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }
    final estimated = double.tryParse(_estimatedHoursController.text) ?? 1;
    Navigator.of(context).pop(
      WorkOrderFormData(
        title: title,
        description: description,
        priority: _priority,
        type: _type,
        assetName: assetName,
        assetLocation: assetLocation,
        assignedTo: _assignedToController.text.trim(),
        dueDate: _dueDate!,
        estimatedHours: estimated,
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _WorkOrderDetailsDialog extends StatelessWidget {
  const _WorkOrderDetailsDialog({
    required this.order,
    required this.canManage,
    required this.onEdit,
  });

  final WorkOrder order;
  final bool canManage;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final statusColor = _statusColor(order.status);
    final priorityColor = _priorityColor(order.priority, isDark);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              order.number,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(
                              label: order.status.label.toUpperCase(),
                              color: statusColor,
                              icon: _statusIcon(order.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          order.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 680;
                    final descriptionBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          order.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _DetailField(
                                label: 'Priority',
                                child: Text(
                                  order.priority.label,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: priorityColor,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _DetailField(
                                label: 'Type',
                                child: Text(
                                  order.type.label,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DetailField(
                          label: 'Asset',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.asset.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                ),
                              ),
                              Text(
                                order.asset.location,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    final notesBlock = order.notes.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notes',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...order.notes.map(
                                (note) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '• $note',
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: descriptionBlock),
                          const SizedBox(width: 24),
                          Expanded(child: notesBlock),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        descriptionBlock,
                        const SizedBox(height: 16),
                        notesBlock,
                      ],
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF111827)
                    : const Color(0xFFF9FAFB),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  if (canManage) ...[
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onEdit,
                      child: const Text('Edit Work Order'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _WorkOrderStats {
  const _WorkOrderStats({
    required this.total,
    required this.open,
    required this.inProgress,
    required this.onHold,
    required this.completed,
    required this.urgent,
  });

  final int total;
  final int open;
  final int inProgress;
  final int onHold;
  final int completed;
  final int urgent;

  factory _WorkOrderStats.fromOrders(List<WorkOrder> orders) {
    return _WorkOrderStats(
      total: orders.length,
      open: orders.where((o) => o.status == WorkOrderStatus.open).length,
      inProgress:
          orders.where((o) => o.status == WorkOrderStatus.inProgress).length,
      onHold: orders.where((o) => o.status == WorkOrderStatus.onHold).length,
      completed:
          orders.where((o) => o.status == WorkOrderStatus.completed).length,
      urgent:
          orders.where((o) => o.priority == WorkOrderPriority.urgent).length,
    );
  }
}

class WorkOrderFormData {
  WorkOrderFormData({
    required this.title,
    required this.description,
    required this.priority,
    required this.type,
    required this.assetName,
    required this.assetLocation,
    required this.assignedTo,
    required this.dueDate,
    required this.estimatedHours,
  });

  final String title;
  final String description;
  final WorkOrderPriority priority;
  final WorkOrderType type;
  final String assetName;
  final String assetLocation;
  final String assignedTo;
  final DateTime? dueDate;
  final double estimatedHours;

  factory WorkOrderFormData.empty() {
    return WorkOrderFormData(
      title: '',
      description: '',
      priority: WorkOrderPriority.medium,
      type: WorkOrderType.repair,
      assetName: '',
      assetLocation: '',
      assignedTo: '',
      dueDate: null,
      estimatedHours: 1,
    );
  }

  factory WorkOrderFormData.fromOrder(WorkOrder order) {
    return WorkOrderFormData(
      title: order.title,
      description: order.description,
      priority: order.priority,
      type: order.type,
      assetName: order.asset.name,
      assetLocation: order.asset.location,
      assignedTo: order.assignedTo ?? '',
      dueDate: order.dueDate,
      estimatedHours: order.estimatedHours,
    );
  }
}

enum WorkOrderStatus {
  open,
  assigned,
  inProgress,
  onHold,
  completed,
  cancelled,
}

extension WorkOrderStatusX on WorkOrderStatus {
  String get label {
    switch (this) {
      case WorkOrderStatus.open:
        return 'Open';
      case WorkOrderStatus.assigned:
        return 'Assigned';
      case WorkOrderStatus.inProgress:
        return 'In Progress';
      case WorkOrderStatus.onHold:
        return 'On Hold';
      case WorkOrderStatus.completed:
        return 'Completed';
      case WorkOrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get filterValue {
    switch (this) {
      case WorkOrderStatus.open:
        return 'open';
      case WorkOrderStatus.assigned:
        return 'assigned';
      case WorkOrderStatus.inProgress:
        return 'in-progress';
      case WorkOrderStatus.onHold:
        return 'on-hold';
      case WorkOrderStatus.completed:
        return 'completed';
      case WorkOrderStatus.cancelled:
        return 'cancelled';
    }
  }
}

enum WorkOrderPriority { low, medium, high, urgent }

extension WorkOrderPriorityX on WorkOrderPriority {
  String get label {
    switch (this) {
      case WorkOrderPriority.low:
        return 'Low';
      case WorkOrderPriority.medium:
        return 'Medium';
      case WorkOrderPriority.high:
        return 'High';
      case WorkOrderPriority.urgent:
        return 'Urgent';
    }
  }

  String get filterValue => name;
}

enum WorkOrderType { repair, preventive, inspection, installation, emergency }

extension WorkOrderTypeX on WorkOrderType {
  String get label {
    switch (this) {
      case WorkOrderType.repair:
        return 'Repair';
      case WorkOrderType.preventive:
        return 'Preventive';
      case WorkOrderType.inspection:
        return 'Inspection';
      case WorkOrderType.installation:
        return 'Installation';
      case WorkOrderType.emergency:
        return 'Emergency';
    }
  }

  String get filterValue => name;
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.number,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.type,
    required this.asset,
    required this.requester,
    required this.createdDate,
    required this.dueDate,
    required this.estimatedHours,
    this.assignedTo,
    this.completedDate,
    this.actualHours,
    this.parts = const [],
    this.photos = const [],
    this.notes = const [],
    this.checklist = const [],
  });

  final String id;
  final String number;
  final String title;
  final String description;
  final WorkOrderStatus status;
  final WorkOrderPriority priority;
  final WorkOrderType type;
  final WorkOrderAsset asset;
  final String? assignedTo;
  final String requester;
  final DateTime createdDate;
  final DateTime dueDate;
  final DateTime? completedDate;
  final double estimatedHours;
  final double? actualHours;
  final List<WorkOrderPart> parts;
  final List<String> photos;
  final List<String> notes;
  final List<WorkOrderChecklistItem> checklist;
}

class WorkOrderAsset {
  const WorkOrderAsset({
    required this.id,
    required this.name,
    required this.location,
    required this.category,
  });

  final String id;
  final String name;
  final String location;
  final String category;
}

class WorkOrderPart {
  const WorkOrderPart({
    required this.name,
    required this.quantity,
    required this.cost,
  });

  final String name;
  final int quantity;
  final double cost;
}

class WorkOrderChecklistItem {
  const WorkOrderChecklistItem({required this.item, required this.completed});

  final String item;
  final bool completed;
}

List<WorkOrder> _seedOrders() {
  return [
    WorkOrder(
      id: '1',
      number: 'WO-2026-001',
      title: 'HVAC Unit Repair - Building A',
      description:
          'Air conditioning unit not cooling properly. Temperature readings show 78F instead of target 72F.',
      status: WorkOrderStatus.inProgress,
      priority: WorkOrderPriority.high,
      type: WorkOrderType.repair,
      asset: const WorkOrderAsset(
        id: 'A-101',
        name: 'HVAC Unit #1',
        location: 'Building A - Roof',
        category: 'HVAC Systems',
      ),
      assignedTo: 'Mike Johnson',
      requester: 'Sarah Chen',
      createdDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 1, 5),
      estimatedHours: 4,
      actualHours: 2.5,
      parts: const [
        WorkOrderPart(name: 'Refrigerant R-410A', quantity: 2, cost: 85),
        WorkOrderPart(name: 'Capacitor 45/5 MFD', quantity: 1, cost: 32.5),
      ],
      notes: const [
        'Initial inspection completed - found low refrigerant levels',
        'Ordered replacement capacitor - delivery expected today',
      ],
      checklist: const [
        WorkOrderChecklistItem(item: 'Inspect refrigerant levels', completed: true),
        WorkOrderChecklistItem(item: 'Check electrical connections', completed: true),
        WorkOrderChecklistItem(item: 'Replace capacitor', completed: false),
        WorkOrderChecklistItem(item: 'Recharge refrigerant', completed: false),
        WorkOrderChecklistItem(item: 'Test system operation', completed: false),
      ],
    ),
    WorkOrder(
      id: '2',
      number: 'WO-2026-002',
      title: 'Monthly Generator Maintenance',
      description:
          'Scheduled preventive maintenance for emergency backup generator.',
      status: WorkOrderStatus.assigned,
      priority: WorkOrderPriority.medium,
      type: WorkOrderType.preventive,
      asset: const WorkOrderAsset(
        id: 'G-001',
        name: 'Emergency Generator #1',
        location: 'Building B - Mechanical Room',
        category: 'Power Systems',
      ),
      assignedTo: 'Mike Johnson',
      requester: 'System (Auto)',
      createdDate: DateTime(2026, 1, 2),
      dueDate: DateTime(2026, 1, 8),
      estimatedHours: 2,
      parts: const [
        WorkOrderPart(name: 'Oil Filter', quantity: 1, cost: 28),
        WorkOrderPart(name: 'Air Filter', quantity: 1, cost: 22),
        WorkOrderPart(name: 'Engine Oil 15W-40', quantity: 4, cost: 48),
      ],
      notes: const ['PM scheduled as per maintenance plan'],
      checklist: const [
        WorkOrderChecklistItem(item: 'Check oil level and quality', completed: false),
        WorkOrderChecklistItem(item: 'Replace oil and filter', completed: false),
        WorkOrderChecklistItem(item: 'Replace air filter', completed: false),
        WorkOrderChecklistItem(item: 'Inspect battery connections', completed: false),
        WorkOrderChecklistItem(item: 'Test auto-start function', completed: false),
        WorkOrderChecklistItem(item: 'Run load test for 30 minutes', completed: false),
      ],
    ),
    WorkOrder(
      id: '3',
      number: 'WO-2026-003',
      title: 'Plumbing Leak - Restroom',
      description:
          "Water leak detected under sink in women's restroom, 2nd floor.",
      status: WorkOrderStatus.open,
      priority: WorkOrderPriority.urgent,
      type: WorkOrderType.emergency,
      asset: const WorkOrderAsset(
        id: 'P-205',
        name: 'Restroom Plumbing',
        location: 'Building A - Floor 2',
        category: 'Plumbing',
      ),
      requester: 'Janet Smith',
      createdDate: DateTime(2026, 1, 2),
      dueDate: DateTime(2026, 1, 2),
      estimatedHours: 1.5,
      parts: const [],
      notes: const ['Urgent - water damage possible'],
    ),
    WorkOrder(
      id: '4',
      number: 'WO-2025-458',
      title: 'Fire Alarm System Inspection',
      description: 'Quarterly fire alarm system inspection and testing.',
      status: WorkOrderStatus.completed,
      priority: WorkOrderPriority.medium,
      type: WorkOrderType.inspection,
      asset: const WorkOrderAsset(
        id: 'S-001',
        name: 'Fire Alarm System',
        location: 'All Buildings',
        category: 'Safety Systems',
      ),
      assignedTo: 'David Lee',
      requester: 'System (Auto)',
      createdDate: DateTime(2025, 12, 20),
      dueDate: DateTime(2025, 12, 31),
      completedDate: DateTime(2025, 12, 28),
      estimatedHours: 6,
      actualHours: 5.5,
      parts: const [
        WorkOrderPart(name: 'Smoke Detector Battery', quantity: 12, cost: 84),
      ],
      notes: const [
        'All zones tested successfully',
        'Replaced 12 batteries in smoke detectors',
        'System functioning normally',
      ],
      checklist: const [
        WorkOrderChecklistItem(item: 'Test all pull stations', completed: true),
        WorkOrderChecklistItem(item: 'Test smoke detectors', completed: true),
        WorkOrderChecklistItem(item: 'Replace batteries as needed', completed: true),
        WorkOrderChecklistItem(item: 'Test alarm notification', completed: true),
        WorkOrderChecklistItem(item: 'Document all findings', completed: true),
      ],
    ),
    WorkOrder(
      id: '5',
      number: 'WO-2026-004',
      title: 'Elevator Safety Inspection',
      description: 'Annual elevator safety inspection and certification.',
      status: WorkOrderStatus.assigned,
      priority: WorkOrderPriority.high,
      type: WorkOrderType.inspection,
      asset: const WorkOrderAsset(
        id: 'E-001',
        name: 'Elevator #1',
        location: 'Building A',
        category: 'Elevators',
      ),
      assignedTo: 'External Contractor',
      requester: 'Facilities Manager',
      createdDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 1, 15),
      estimatedHours: 4,
      parts: const [],
      notes: const ['Contractor scheduled for Jan 10th'],
    ),
  ];
}

Color _statusColor(WorkOrderStatus status) {
  switch (status) {
    case WorkOrderStatus.open:
      return const Color(0xFF3B82F6);
    case WorkOrderStatus.assigned:
      return const Color(0xFF8B5CF6);
    case WorkOrderStatus.inProgress:
      return const Color(0xFFF59E0B);
    case WorkOrderStatus.onHold:
      return const Color(0xFFF97316);
    case WorkOrderStatus.completed:
      return const Color(0xFF22C55E);
    case WorkOrderStatus.cancelled:
      return const Color(0xFFEF4444);
  }
}

Color _priorityColor(WorkOrderPriority priority, bool isDark) {
  switch (priority) {
    case WorkOrderPriority.low:
      return isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    case WorkOrderPriority.medium:
      return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    case WorkOrderPriority.high:
      return isDark ? const Color(0xFFFBBF24) : const Color(0xFFF97316);
    case WorkOrderPriority.urgent:
      return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  }
}

IconData _statusIcon(WorkOrderStatus status) {
  switch (status) {
    case WorkOrderStatus.open:
      return Icons.error_outline;
    case WorkOrderStatus.assigned:
      return Icons.person_outline;
    case WorkOrderStatus.inProgress:
      return Icons.play_circle_outline;
    case WorkOrderStatus.onHold:
      return Icons.pause_circle_outline;
    case WorkOrderStatus.completed:
      return Icons.check_circle_outline;
    case WorkOrderStatus.cancelled:
      return Icons.cancel_outlined;
  }
}

IconData _typeIcon(WorkOrderType type) {
  switch (type) {
    case WorkOrderType.repair:
      return Icons.build_outlined;
    case WorkOrderType.preventive:
      return Icons.settings_outlined;
    case WorkOrderType.inspection:
      return Icons.rule_outlined;
    case WorkOrderType.installation:
      return Icons.handyman_outlined;
    case WorkOrderType.emergency:
      return Icons.bolt_outlined;
  }
}

String _roleDescription(UserRole role) {
  switch (role) {
    case UserRole.employee:
    case UserRole.maintenance:
      return 'Your assigned work orders and maintenance tasks';
    case UserRole.supervisor:
      return "Your team's work orders and maintenance tasks";
    case UserRole.manager:
      return 'Department work orders and maintenance tasks';
    default:
      return 'Manage maintenance requests, repairs, and preventive maintenance';
  }
}

String? _accessLabel(UserRole role, int count) {
  switch (role) {
    case UserRole.employee:
    case UserRole.maintenance:
      return 'Showing only work orders assigned to you ($count)';
    case UserRole.supervisor:
      return "Showing only your team's work orders ($count)";
    default:
      return null;
  }
}

bool _canManageOrders(UserRole role) {
  return role == UserRole.manager ||
      role == UserRole.admin ||
      role == UserRole.superAdmin ||
      role == UserRole.techSupport;
}

String _demoUserName(UserRole role) {
  switch (role) {
    case UserRole.employee:
    case UserRole.maintenance:
      return 'Mike Johnson';
    case UserRole.supervisor:
      return 'Sarah Chen';
    case UserRole.manager:
      return 'Alex Morgan';
    case UserRole.techSupport:
      return 'Casey Jordan';
    case UserRole.admin:
    case UserRole.superAdmin:
      return 'Admin User';
    case UserRole.client:
    case UserRole.vendor:
    case UserRole.viewer:
      return 'Guest User';
  }
}

List<String> _demoTeamMembers(UserRole role) {
  switch (role) {
    case UserRole.supervisor:
      return const [
        'Mike Johnson',
        'Janet Smith',
        'Sarah Chen',
        'David Lee',
      ];
    default:
      return const [];
  }
}
