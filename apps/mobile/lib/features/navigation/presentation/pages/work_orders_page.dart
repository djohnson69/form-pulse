import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../dashboard/data/active_role_provider.dart';

class WorkOrdersPage extends ConsumerStatefulWidget {
  const WorkOrdersPage({super.key});

  @override
  ConsumerState<WorkOrdersPage> createState() => _WorkOrdersPageState();
}

enum _WorkOrderViewMode { list, board }

class _WorkOrdersPageState extends ConsumerState<WorkOrdersPage> {
  _WorkOrderViewMode _viewMode = _WorkOrderViewMode.list;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _priorityFilter = 'all';
  String _typeFilter = 'all';
  String? _expandedOrderId;
  List<WorkOrder> _orders = const [];
  bool _loading = true;
  final _supabase = Supabase.instance.client;
  String? _orgId;
  String? _userName;
  List<String> _teamMembers = const [];

  String _resolveUserName() {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'User';
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return metadata['name']?.toString() ??
        metadata['full_name']?.toString() ??
        user.email ??
        'User';
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final role = ref.read(activeRoleProvider);
      final isGlobal = role == UserRole.techSupport;
      final orgId = isGlobal ? null : await _resolveOrgId();
      _orgId = orgId;
      _userName = _resolveUserName();
      _teamMembers = await _resolveTeamMembers(orgId);
      await _loadOrders(role, orgId: orgId, isGlobal: isGlobal);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOrders(
    UserRole role, {
    required String? orgId,
    required bool isGlobal,
  }) async {
    try {
      dynamic query = _supabase.from('work_orders').select();
      if (!isGlobal && orgId != null) {
        query = query.eq('org_id', orgId);
      }
      query = query
          .order('due_date', ascending: true)
          .order('created_at', ascending: false);
      final res = await query;
      final rows = (res as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map(_mapOrder)
          .toList();
      setState(() => _orders = rows);
    } catch (_) {
      setState(() => _orders = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final isWide = MediaQuery.sizeOf(context).width >= 768;
    final role = ref.watch(activeRoleProvider);
    final userName = _userName ?? _resolveUserName();
    final teamMembers = _teamMembers;
    final visibleOrders =
        _applyRoleVisibility(_orders, role, userName, teamMembers);
    final filteredOrders = _applyFilters(visibleOrders);
    final stats = _WorkOrderStats.fromOrders(visibleOrders);
    final canManage = _canManageOrders(role);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.all(isWide ? 24 : 16),
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
        final showExportLabel = constraints.maxWidth >= 640;
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
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A8A).withOpacity(0.2)
                      : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(8),
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
                      Icons.error_outline,
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

        final exportButton = OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
            foregroundColor:
                isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            side: BorderSide(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _orders.isEmpty ? null : _handleExport,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: showExportLabel ? const Text('Export') : const SizedBox.shrink(),
        );

        final createButton = FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
          ),
          onPressed: () => _openCreateDialog(context),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Create Work Order'),
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  exportButton,
                  if (canManage) const SizedBox(width: 12),
                  if (canManage) createButton,
                ],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 16),
            Row(
              children: [
                exportButton,
                if (canManage) const SizedBox(width: 12),
                if (canManage) Expanded(child: createButton),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, _WorkOrderStats stats) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
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
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
      ),
    );
    final inputDecoration = InputDecoration(
      prefixIcon: const Icon(Icons.search, size: 20),
      hintText: 'Search work orders, assets, locations...',
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      ),
      prefixIconColor:
          isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      filled: true,
      fillColor: isDark ? const Color(0xFF374151) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
                    decoration: inputDecoration,
                    style: TextStyle(
                      color:
                          isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.trim().toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildStatusFilter(inputDecoration)),
                const SizedBox(width: 12),
                Expanded(child: _buildPriorityFilter(inputDecoration)),
                const SizedBox(width: 12),
                Expanded(child: _buildTypeFilter(inputDecoration)),
              ],
            );
          }
          return Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: inputDecoration,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
              ),
              const SizedBox(height: 12),
              _buildStatusFilter(inputDecoration),
              const SizedBox(height: 12),
              _buildPriorityFilter(inputDecoration),
              const SizedBox(height: 12),
              _buildTypeFilter(inputDecoration),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusFilter(InputDecoration decoration) {
    return DropdownButtonFormField<String>(
      value: _statusFilter,
      isExpanded: true,
      decoration: decoration.copyWith(prefixIcon: null),
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF111827),
      ),
      dropdownColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1F2937)
          : Colors.white,
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

  Widget _buildPriorityFilter(InputDecoration decoration) {
    return DropdownButtonFormField<String>(
      value: _priorityFilter,
      isExpanded: true,
      decoration: decoration.copyWith(prefixIcon: null),
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF111827),
      ),
      dropdownColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1F2937)
          : Colors.white,
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

  Widget _buildTypeFilter(InputDecoration decoration) {
    return DropdownButtonFormField<String>(
      value: _typeFilter,
      isExpanded: true,
      decoration: decoration.copyWith(prefixIcon: null),
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF111827),
      ),
      dropdownColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1F2937)
          : Colors.white,
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
    final isDark = theme.brightness == Brightness.dark;
    if (orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${orders.length} Work Order${orders.length == 1 ? '' : 's'}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            _WorkOrderViewToggle(
              viewMode: _viewMode,
              onChanged: (mode) => setState(() => _viewMode = mode),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_viewMode == _WorkOrderViewMode.list)
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
                onDelete: () => _showDeleteConfirmation(order.id),
              ),
            ),
          )
        else
          _WorkOrderBoard(
            orders: orders,
            canManage: canManage,
            onEdit: (order) => _openEditDialog(context, order),
            onViewDetails: (order) =>
                _openDetailsDialog(context, order, canManage),
            onDelete: (order) => _showDeleteConfirmation(order.id),
            isDark: isDark,
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
    await _createWorkOrder(result);
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
    await _updateWorkOrder(order.id, result);
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

  Future<void> _createWorkOrder(WorkOrderFormData data) async {
    final orgId = _orgId ?? await _resolveOrgId();
    if (orgId == null) {
      _showSnackBar(context, 'Organization required to create work orders.');
      return;
    }
    try {
      final payload = {
        'org_id': orgId,
        'title': data.title,
        'description': data.description,
        'priority': data.priority.filterValue,
        'type': data.type.filterValue,
        'asset_name': data.assetName,
        'asset_location': data.assetLocation,
        'assigned_to': data.assignedTo,
        'due_date': data.dueDate?.toIso8601String(),
        'estimated_hours': data.estimatedHours,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      final res = await _supabase
          .from('work_orders')
          .insert(payload)
          .select()
          .single();
      final created = _mapOrder(Map<String, dynamic>.from(res as Map));
      if (!mounted) return;
      setState(() => _orders = [created, ..._orders]);
      _showSnackBar(context, 'Work order created: ${data.title}');
    } catch (_) {
      _showSnackBar(context, 'Failed to create work order.');
    }
  }

  Future<void> _updateWorkOrder(String id, WorkOrderFormData data) async {
    try {
      final payload = {
        'title': data.title,
        'description': data.description,
        'priority': data.priority.filterValue,
        'type': data.type.filterValue,
        'asset_name': data.assetName,
        'asset_location': data.assetLocation,
        'assigned_to': data.assignedTo,
        'due_date': data.dueDate?.toIso8601String(),
        'estimated_hours': data.estimatedHours,
        'updated_at': DateTime.now().toIso8601String(),
      };
      final res = await _supabase
          .from('work_orders')
          .update(payload)
          .eq('id', id)
          .select()
          .maybeSingle();
      final updated = res == null
          ? null
          : _mapOrder(Map<String, dynamic>.from(res as Map));
      if (!mounted) return;
      setState(() {
        _orders = _orders
            .map((o) => o.id == id ? (updated ?? o) : o)
            .toList();
      });
      _showSnackBar(context, 'Work order updated: ${data.title}');
    } catch (_) {
      _showSnackBar(context, 'Failed to update work order.');
    }
  }

  Future<void> _handleExport() async {
    if (_orders.isEmpty) {
      _showSnackBar(context, 'No work orders to export.');
      return;
    }
    final csv = _buildWorkOrdersCsv(_orders);
    final filename =
        'work-orders-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
    final file = XFile.fromData(
      utf8.encode(csv),
      mimeType: 'text/csv',
      name: filename,
    );
    try {
      await Share.shareXFiles([file], text: 'Work orders export');
    } catch (_) {
      await Share.share(csv);
    }
  }

  String _buildWorkOrdersCsv(List<WorkOrder> orders) {
    const headers = [
      'Number',
      'Title',
      'Status',
      'Priority',
      'Type',
      'Asset',
      'Location',
      'Assigned To',
      'Requester',
      'Due Date',
      'Estimated Hours',
      'Actual Hours',
    ];
    final rows = orders.map((order) {
      return [
        order.number,
        order.title,
        order.status.label,
        order.priority.label,
        order.type.label,
        order.asset.name,
        order.asset.location,
        order.assignedTo ?? '-',
        order.requester,
        DateFormat('yyyy-MM-dd').format(order.dueDate),
        order.estimatedHours.toString(),
        order.actualHours?.toString() ?? '',
      ];
    });
    return ([headers, ...rows])
        .map((row) => row.map(_csvEscape).join(','))
        .join('\n');
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  Future<void> _deleteWorkOrder(String id) async {
    try {
      await _supabase.from('work_orders').delete().eq('id', id);
      if (!mounted) return;
      setState(() {
        _orders = _orders.where((o) => o.id != id).toList();
      });
    } catch (_) {
      _showSnackBar(context, 'Failed to delete work order.');
    }
  }

  Future<void> _showDeleteConfirmation(String id) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete work order?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _deleteWorkOrder(id);
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<String?> _resolveOrgId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      final res = await _supabase
          .from('org_members')
          .select('org_id')
          .eq('user_id', user.id)
          .limit(1)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final res = await _supabase
          .from('profiles')
          .select('org_id')
          .eq('id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    return null;
  }

  WorkOrder _mapOrder(Map<String, dynamic> row) {
    final status = _statusFromString(row['status']?.toString() ?? 'open');
    final priority =
        _priorityFromString(row['priority']?.toString() ?? 'medium');
    final type = _typeFromString(row['type']?.toString() ?? 'repair');
    final dueDate = row['due_date'] == null
        ? null
        : DateTime.tryParse(row['due_date'].toString());
    final createdDate = row['created_at'] == null
        ? DateTime.now()
        : DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now();
    final safeDueDate = dueDate ?? createdDate.add(const Duration(days: 7));
    final parts = (row['parts'] as List?)
            ?.map((e) => WorkOrderPart.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const [];
    final notes = (row['notes'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];
    final checklist = (row['checklist'] as List?)
            ?.map((e) => WorkOrderChecklistItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const [];
    return WorkOrder(
      id: row['id']?.toString() ?? '',
      number: row['number']?.toString() ?? 'WO-${row['id'] ?? ''}',
      title: row['title']?.toString() ?? 'Untitled',
      description: row['description']?.toString() ?? '',
      status: status,
      priority: priority,
      type: type,
      asset: WorkOrderAsset(
        id: (row['asset_id'] ?? '').toString(),
        name: row['asset_name']?.toString() ?? 'Unassigned Asset',
        location: row['asset_location']?.toString() ?? 'Unknown',
        category: row['asset_category']?.toString() ?? 'Uncategorized',
      ),
      assignedTo: row['assigned_to']?.toString(),
      requester: row['requester']?.toString() ?? 'Requester',
      createdDate: createdDate,
      dueDate: safeDueDate,
      completedDate: row['completed_at'] == null
          ? null
          : DateTime.tryParse(row['completed_at'].toString()),
      estimatedHours:
          (row['estimated_hours'] as num?)?.toDouble() ?? 0.0,
      actualHours: (row['actual_hours'] as num?)?.toDouble(),
      parts: parts,
      notes: notes,
      checklist: checklist,
    );
  }

  WorkOrderStatus _statusFromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'assigned':
        return WorkOrderStatus.assigned;
      case 'in-progress':
      case 'in_progress':
        return WorkOrderStatus.inProgress;
      case 'on-hold':
      case 'on_hold':
        return WorkOrderStatus.onHold;
      case 'completed':
        return WorkOrderStatus.completed;
      case 'cancelled':
        return WorkOrderStatus.cancelled;
      case 'open':
      default:
        return WorkOrderStatus.open;
    }
  }

  WorkOrderPriority _priorityFromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'low':
        return WorkOrderPriority.low;
      case 'high':
        return WorkOrderPriority.high;
      case 'urgent':
        return WorkOrderPriority.urgent;
      case 'medium':
      default:
        return WorkOrderPriority.medium;
    }
  }

  WorkOrderType _typeFromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'repair':
        return WorkOrderType.repair;
      case 'preventive':
        return WorkOrderType.preventive;
      case 'inspection':
        return WorkOrderType.inspection;
      case 'installation':
        return WorkOrderType.installation;
      case 'emergency':
        return WorkOrderType.emergency;
      default:
        return WorkOrderType.repair;
    }
  }
}

class _WorkOrderViewToggle extends StatelessWidget {
  const _WorkOrderViewToggle({
    required this.viewMode,
    required this.onChanged,
  });

  final _WorkOrderViewMode viewMode;
  final ValueChanged<_WorkOrderViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _ViewToggleButton(
            label: 'List',
            icon: Icons.list,
            selected: viewMode == _WorkOrderViewMode.list,
            onTap: () => onChanged(_WorkOrderViewMode.list),
          ),
          _ViewToggleButton(
            label: 'Board',
            icon: Icons.grid_view,
            selected: viewMode == _WorkOrderViewMode.board,
            onTap: () => onChanged(_WorkOrderViewMode.board),
          ),
        ],
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedBackground = isDark ? const Color(0xFF374151) : Colors.white;
    final selectedColor = isDark ? Colors.white : Colors.black;
    final unselectedColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? selectedBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? selectedColor : unselectedColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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

class _WorkOrderBoard extends StatelessWidget {
  const _WorkOrderBoard({
    required this.orders,
    required this.canManage,
    required this.onEdit,
    required this.onViewDetails,
    required this.onDelete,
    required this.isDark,
  });

  final List<WorkOrder> orders;
  final bool canManage;
  final ValueChanged<WorkOrder> onEdit;
  final ValueChanged<WorkOrder> onViewDetails;
  final ValueChanged<WorkOrder> onDelete;
  final bool isDark;

  static const _columns = [
    WorkOrderStatus.open,
    WorkOrderStatus.assigned,
    WorkOrderStatus.inProgress,
    WorkOrderStatus.onHold,
    WorkOrderStatus.completed,
    WorkOrderStatus.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _columns.length; i++) ...[
              Expanded(
                child: _WorkOrderBoardColumn(
                  status: _columns[i],
                  orders: orders
                      .where((o) => o.status == _columns[i])
                      .toList(),
                  canManage: canManage,
                  onEdit: onEdit,
                  onViewDetails: onViewDetails,
                  onDelete: onDelete,
                  isDark: isDark,
                ),
              ),
              if (i != _columns.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
        if (constraints.maxWidth < 1100) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _columns.length * 280,
              child: content,
            ),
          );
        }
        return content;
      },
    );
  }
}

class _WorkOrderBoardColumn extends StatelessWidget {
  const _WorkOrderBoardColumn({
    required this.status,
    required this.orders,
    required this.canManage,
    required this.onEdit,
    required this.onViewDetails,
    required this.onDelete,
    required this.isDark,
  });

  final WorkOrderStatus status;
  final List<WorkOrder> orders;
  final bool canManage;
  final ValueChanged<WorkOrder> onEdit;
  final ValueChanged<WorkOrder> onViewDetails;
  final ValueChanged<WorkOrder> onDelete;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${orders.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            Text(
              'No items',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            )
          else
            Column(
              children: orders
                  .map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _WorkOrderBoardCard(
                        order: order,
                        canManage: canManage,
                        onEdit: () => onEdit(order),
                        onViewDetails: () => onViewDetails(order),
                        onDelete: () => onDelete(order),
                        isDark: isDark,
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _WorkOrderBoardCard extends StatelessWidget {
  const _WorkOrderBoardCard({
    required this.order,
    required this.canManage,
    required this.onEdit,
    required this.onViewDetails,
    required this.onDelete,
    required this.isDark,
  });

  final WorkOrder order;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onViewDetails;
  final VoidCallback onDelete;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor = _priorityColor(order.priority, isDark);
    final statusColor = _statusColor(order.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.number,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order.title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MiniTag(
                icon: Icons.person_outline,
                label: order.assignedTo ?? 'Unassigned',
              ),
              _MiniTag(
                icon: Icons.calendar_today_outlined,
                label: DateFormat('MMM d').format(order.dueDate),
              ),
              _MiniTag(
                icon: Icons.place_outlined,
                label: order.asset.location,
              ),
              _StatusPill(
                label: order.status.label,
                color: statusColor,
              ),
              _MiniPriority(priorityColor: priorityColor, label: order.priority.label),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: onViewDetails,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('View'),
              ),
              const SizedBox(width: 8),
              if (canManage)
                FilledButton.tonal(
                  onPressed: onEdit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Edit'),
                ),
              if (canManage) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.redAccent,
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? Colors.grey[300] : Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniPriority extends StatelessWidget {
  const _MiniPriority({required this.priorityColor, required this.label});

  final Color priorityColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: priorityColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: priorityColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber, size: 14, color: priorityColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: priorityColor,
              fontWeight: FontWeight.w700,
            ),
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
    required this.onDelete,
  });

  final WorkOrder order;
  final bool isExpanded;
  final bool canManage;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onViewDetails;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final statusColor = _statusColor(order.status);
    final priorityColor = _priorityColor(order.priority, isDark);
    final typeIcon = _typeIcon(order.type);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
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
                    ? const Color(0xFF1F2937)
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
                  Container(
                    padding: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        if (canManage)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit'),
                          ),
                        if (canManage) const SizedBox(width: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                            foregroundColor:
                                isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: onViewDetails,
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('View Details'),
                        ),
                      ],
                    ),
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
                        width: 20,
                        height: 20,
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.item,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
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
                    'Parts & Materials',
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
                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
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
          label: 'Estimated Hours:',
          value: '${order.estimatedHours}h',
        ),
        if (order.actualHours != null)
          _TimeRow(
            label: 'Actual Hours:',
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
        borderRadius: BorderRadius.circular(8),
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
                  fontSize: 11,
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

  factory WorkOrderPart.fromJson(Map<String, dynamic> json) {
    return WorkOrderPart(
      name: json['name']?.toString() ?? 'Part',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'cost': cost,
    };
  }
}

class WorkOrderChecklistItem {
  const WorkOrderChecklistItem({required this.item, required this.completed});

  final String item;
  final bool completed;

  factory WorkOrderChecklistItem.fromJson(Map<String, dynamic> json) {
    return WorkOrderChecklistItem(
      item: json['item']?.toString() ?? 'Item',
      completed: json['completed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item': item,
      'completed': completed,
    };
  }
}

// ignore: unused_element
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

// ignore: unused_element
String _demoUserName(UserRole role) {
  final user = Supabase.instance.client.auth.currentUser;
  return user?.userMetadata?['name']?.toString() ??
      user?.email ??
      'User';
}

Future<List<String>> _resolveTeamMembers(String? orgId) async {
  if (orgId == null) return const [];
  try {
    final res = await Supabase.instance.client
        .from('org_members')
        .select('user_id')
        .eq('org_id', orgId);
    return (res as List<dynamic>)
        .map((row) => (row as Map)['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
}
