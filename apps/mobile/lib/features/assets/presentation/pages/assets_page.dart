import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/assets_provider.dart';
import '../../../dashboard/data/active_role_provider.dart';
import '../../../navigation/presentation/pages/qr_scanner_page.dart';
import 'asset_detail_page.dart';
import 'asset_editor_page.dart';
import 'inspection_editor_page.dart';

enum _AssetsViewMode { grid, list }

class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({super.key});

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _categoryFilter = 'all';
  String _locationFilter = 'all';
  String _contactFilter = '';
  _AssetsViewMode _viewMode = _AssetsViewMode.grid;
  RealtimeChannel? _assetsChannel;

  @override
  void initState() {
    super.initState();
    _subscribeToAssetChanges();
  }

  @override
  void dispose() {
    _assetsChannel?.unsubscribe();
    _searchController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _subscribeToAssetChanges() {
    final client = Supabase.instance.client;
    _assetsChannel = client.channel('assets-changes')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'equipment',
        callback: (_) {
          if (!mounted) return;
          ref.invalidate(equipmentProvider);
        },
      )
      ..subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final equipmentAsync = ref.watch(equipmentProvider);
    final role = ref.watch(activeRoleProvider);
    final canManageAssets = _canManageAssets(role);
    return Scaffold(
      body: equipmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _AssetsErrorView(error: e.toString()),
        data: (assets) {
          final models =
              assets.map((asset) => _AssetViewModel.fromEquipment(asset)).toList();
          final scopedModels = _applyRoleFilter(models, role);
          final categories = _buildCategorySummaries(scopedModels);
          final locations = _buildLocations(scopedModels);
          final filtered = _applyFilters(scopedModels);
          final stats = _AssetStats.fromModels(scopedModels);
          final maintenanceSchedule = _buildMaintenanceSchedule(scopedModels);
          final maintenancePreview = maintenanceSchedule.take(4).toList();
          final totalNote = _totalAssetsNote(role);
          final roleIndicator = _roleIndicator(role, filtered.length);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(equipmentProvider);
              await ref.read(equipmentProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(
                  context,
                  role: role,
                  canManageAssets: canManageAssets,
                  roleIndicator: roleIndicator,
                  exportAssets: filtered,
                ),
                const SizedBox(height: 16),
                _AssetStatsGrid(stats: stats, totalAssetsNote: totalNote),
                const SizedBox(height: 16),
                _CategorySection(
                  categories: categories,
                  selected: _categoryFilter,
                  onSelected: (value) =>
                      setState(() => _categoryFilter = value),
                ),
                const SizedBox(height: 16),
                _MaintenanceScheduleCard(
                  schedule: maintenancePreview,
                  onViewAll: () => _showMaintenanceSheet(
                    context,
                    maintenanceSchedule,
                  ),
                ),
                const SizedBox(height: 16),
                _InspectionToolsCard(
                  onScan: () => _openQrScanner(context),
                  onInspection: () => _openInspectionTool(context, models),
                  onPhoto: () => _openInspectionTool(context, models),
                  onSchedule: () => _openScheduleTool(context, models),
                ),
                const SizedBox(height: 16),
                _buildAdvancedFilters(context, categories, locations),
                const SizedBox(height: 16),
                _buildFilters(context),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  _EmptyAssetsCard(
                    onClear: _clearFilters,
                    onCreate: () => _openEditor(context),
                  )
                else
                  _buildAssetsBody(context, filtered),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required UserRole role,
    required bool canManageAssets,
    required String? roleIndicator,
    required List<_AssetViewModel> exportAssets,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final subtitle = _roleSubtitle(role);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final indicatorBackground =
            isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
        final indicatorBorder =
            isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE);
        final indicatorText =
            isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1D4ED8);
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asset Management',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (roleIndicator != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: indicatorBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: indicatorBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: indicatorText),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        roleIndicator,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: indicatorText,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            OutlinedButton.icon(
              onPressed: () => _exportAssets(context, exportAssets),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export'),
            ),
            if (canManageAssets)
              FilledButton.icon(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Asset'),
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

  bool _canManageAssets(UserRole role) {
    return role == UserRole.manager ||
        role == UserRole.admin ||
        role == UserRole.superAdmin ||
        role == UserRole.techSupport ||
        role == UserRole.supervisor;
  }

  String _roleSubtitle(UserRole role) {
    switch (role) {
      case UserRole.employee:
      case UserRole.maintenance:
        return 'Your assigned equipment and assets';
      case UserRole.supervisor:
        return "Your team's equipment and assets";
      case UserRole.manager:
        return 'Department equipment and assets';
      default:
        return 'Track and manage all equipment, vehicles, and assets';
    }
  }

  String _totalAssetsNote(UserRole role) {
    switch (role) {
      case UserRole.employee:
      case UserRole.maintenance:
        return 'Assigned to you';
      case UserRole.supervisor:
        return 'Team assets';
      case UserRole.manager:
        return 'Department assets';
      default:
        return 'Across all locations';
    }
  }

  String? _roleIndicator(UserRole role, int count) {
    switch (role) {
      case UserRole.employee:
      case UserRole.maintenance:
        return 'Showing only assets assigned to you ($count)';
      case UserRole.supervisor:
        return 'Showing only your team\'s assets ($count)';
      default:
        return null;
    }
  }

  List<_AssetViewModel> _applyRoleFilter(
    List<_AssetViewModel> models,
    UserRole role,
  ) {
    if (role != UserRole.employee && role != UserRole.maintenance) {
      return models;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return models;
    final userId = user.id.toLowerCase();
    final email = user.email?.toLowerCase();
    final filtered = models.where((model) {
      final assigned = model.equipment.assignedTo?.toLowerCase();
      if (assigned != null && assigned == userId) return true;
      final contactEmail = model.equipment.contactEmail?.toLowerCase();
      if (email != null && contactEmail == email) return true;
      return false;
    }).toList();
    return filtered.isEmpty ? models : filtered;
  }

  Widget _buildAdvancedFilters(
    BuildContext context,
    List<_CategorySummary> categories,
    List<String> locations,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final categoryNames = categories.map((c) => c.name).toList();
    final activeCount = [
      if (_categoryFilter != 'all') true,
      if (_locationFilter != 'all') true,
      if (_contactFilter.isNotEmpty) true,
    ].length;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Advanced Search & Filters', style: titleStyle),
              if (activeCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$activeCount active',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final categoryField = _FilterField(
                label: 'Category',
                child: DropdownButtonFormField<String>(
                  value: _categoryFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        'All Categories',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...categoryNames.map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _categoryFilter = value ?? 'all');
                  },
                ),
              );
              final locationField = _FilterField(
                label: 'Location',
                child: DropdownButtonFormField<String>(
                  value: _locationFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        'All Locations',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...locations.map(
                      (location) => DropdownMenuItem(
                        value: location,
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _locationFilter = value ?? 'all');
                  },
                ),
              );
              final contactField = _FilterField(
                label: 'Contact Person',
                child: TextField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: 'Search by name...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(
                      () => _contactFilter = value.trim().toLowerCase(),
                    );
                  },
                ),
              );
              final actionField = _FilterField(
                label: 'Actions',
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear'),
                  ),
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: categoryField),
                    const SizedBox(width: 12),
                    Expanded(child: locationField),
                    const SizedBox(width: 12),
                    Expanded(child: contactField),
                    const SizedBox(width: 12),
                    Expanded(child: actionField),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  categoryField,
                  const SizedBox(height: 12),
                  locationField,
                  const SizedBox(height: 12),
                  contactField,
                  const SizedBox(height: 12),
                  actionField,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final children = [
            Expanded(
              flex: isWide ? 2 : 0,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search assets by name or serial number...',
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
                value: _statusFilter,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (value) {
                  setState(() => _statusFilter = value ?? 'all');
                },
              ),
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

  Widget _buildAssetsBody(
    BuildContext context,
    List<_AssetViewModel> assets,
  ) {
    if (_viewMode == _AssetsViewMode.list) {
      return _AssetsListTable(
        assets: assets,
        onOpen: (asset) => _openDetail(context, asset),
        onEdit: (asset) => _openEditor(context, existing: asset),
        onDelete: (asset) => _confirmDelete(context, asset),
      );
    }

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
          childAspectRatio: crossAxisCount > 1 ? 0.9 : 0.95,
          children: assets
              .map(
                (asset) => _AssetGridCard(
                  model: asset,
                  onOpen: () => _openDetail(context, asset.equipment),
                  onEdit: () => _openEditor(context, existing: asset.equipment),
                  onInspect: () => _openInspection(context, asset.equipment),
                ),
              )
              .toList(),
        );
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _contactController.clear();
      _searchQuery = '';
      _statusFilter = 'all';
      _categoryFilter = 'all';
      _locationFilter = 'all';
      _contactFilter = '';
    });
  }

  Future<void> _exportAssets(
    BuildContext context,
    List<_AssetViewModel> assets,
  ) async {
    if (assets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assets to export.')),
      );
      return;
    }
    final csv = _buildAssetsCsv(assets);
    final filename =
        'assets-export-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
    final file = XFile.fromData(
      utf8.encode(csv),
      mimeType: 'text/csv',
      name: filename,
    );
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Asset export',
          files: [file],
        ),
      );
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: csv));
    }
  }

  String _buildAssetsCsv(List<_AssetViewModel> assets) {
    final rows = <List<String>>[
      [
        'Name',
        'Serial Number',
        'Category',
        'Status',
        'Location',
        'Assigned To',
        'Value',
        'Condition',
      ],
      ...assets.map((asset) {
        return [
          asset.name,
          asset.serialNumber,
          asset.category,
          asset.status,
          asset.location,
          asset.assignedTo,
          asset.valueAmount.toStringAsFixed(2),
          asset.condition,
        ];
      }),
    ];
    return rows
        .map((row) => row.map(_csvEscape).join(','))
        .join('\n');
  }

  String _csvEscape(String value) {
    final sanitized = value.replaceAll('"', '""');
    if (sanitized.contains(',') || sanitized.contains('\n')) {
      return '"$sanitized"';
    }
    return sanitized;
  }

  List<_AssetViewModel> _applyFilters(List<_AssetViewModel> assets) {
    return assets.where((asset) {
      final matchesSearch = _searchQuery.isEmpty ||
          asset.name.toLowerCase().contains(_searchQuery) ||
          asset.category.toLowerCase().contains(_searchQuery) ||
          asset.serialNumber.toLowerCase().contains(_searchQuery) ||
          asset.location.toLowerCase().contains(_searchQuery) ||
          asset.assignedTo.toLowerCase().contains(_searchQuery);
      final matchesContact = _contactFilter.isEmpty ||
          asset.assignedTo.toLowerCase().contains(_contactFilter);
      final matchesStatus =
          _statusFilter == 'all' || asset.status == _statusFilter;
      final matchesCategory =
          _categoryFilter == 'all' || asset.category == _categoryFilter;
      final matchesLocation =
          _locationFilter == 'all' || asset.location == _locationFilter;
      return matchesSearch &&
          matchesContact &&
          matchesStatus &&
          matchesCategory &&
          matchesLocation;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<_CategorySummary> _buildCategorySummaries(
    List<_AssetViewModel> assets,
  ) {
    final counts = <String, int>{};
    for (final asset in assets) {
      if (asset.category.isEmpty) continue;
      counts.update(asset.category, (value) => value + 1, ifAbsent: () => 1);
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map((entry) => _CategorySummary.fromName(entry.key, entry.value))
        .toList();
  }

  List<String> _buildLocations(List<_AssetViewModel> assets) {
    final locations = assets
        .map((asset) => asset.location.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return locations;
  }

  List<_MaintenanceItem> _buildMaintenanceSchedule(
    List<_AssetViewModel> assets,
  ) {
    final upcoming = assets
        .where((asset) => asset.nextMaintenanceDate != null)
        .map(
          (asset) => _MaintenanceItem.fromAsset(
            asset.name,
            asset.nextMaintenanceDate!,
            asset.type,
          ),
        )
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return upcoming;
  }

  Future<void> _openEditor(BuildContext context, {Equipment? existing}) async {
    final result = await Navigator.of(context).push<Equipment?>(
      MaterialPageRoute(builder: (_) => AssetEditorPage(existing: existing)),
    );
    if (!mounted) return;
    if (result != null) {
      ref.invalidate(equipmentProvider);
      final message = existing == null
          ? 'Asset added successfully.'
          : 'Asset updated successfully.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _openDetail(BuildContext context, Equipment asset) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AssetDetailPage(asset: asset)),
    );
    if (!mounted) return;
    ref.invalidate(equipmentProvider);
  }

  Future<void> _openInspection(BuildContext context, Equipment asset) async {
    final result = await Navigator.of(context).push<AssetInspection?>(
      MaterialPageRoute(builder: (_) => InspectionEditorPage(asset: asset)),
    );
    if (!mounted) return;
    if (result != null) {
      ref.invalidate(assetInspectionsProvider(asset.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection scheduled successfully.')),
      );
    }
  }

  Future<void> _openQrScanner(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
  }

  Future<void> _openInspectionTool(
    BuildContext context,
    List<_AssetViewModel> assets,
  ) async {
    final selection = await _pickAsset(context, assets);
    if (selection == null || !mounted) return;
    await _openInspection(context, selection);
  }

  Future<void> _openScheduleTool(
    BuildContext context,
    List<_AssetViewModel> assets,
  ) async {
    final selection = await _pickAsset(context, assets);
    if (selection == null || !mounted) return;
    await _openEditor(context, existing: selection);
  }

  Future<Equipment?> _pickAsset(
    BuildContext context,
    List<_AssetViewModel> assets,
  ) async {
    if (assets.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assets available.')),
      );
      return null;
    }
    return showModalBottomSheet<Equipment>(
      context: context,
      builder: (context) => _AssetPickerSheet(assets: assets),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Equipment asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete asset?'),
        content: const Text(
          'This will permanently remove the asset and its history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _deleteAsset(asset);
  }

  Future<void> _deleteAsset(Equipment asset) async {
    final repo = ref.read(assetsRepositoryProvider);
    try {
      await repo.deleteEquipment(equipment: asset);
      if (!mounted) return;
      ref.invalidate(equipmentProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _showMaintenanceSheet(
    BuildContext context,
    List<_MaintenanceItem> items,
  ) async {
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No upcoming maintenance.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => _MaintenanceSheet(items: items),
    );
  }
}

class _AssetStats {
  const _AssetStats({
    required this.totalAssets,
    required this.activeAssets,
    required this.maintenanceAssets,
    required this.totalValue,
  });

  final int totalAssets;
  final int activeAssets;
  final int maintenanceAssets;
  final double totalValue;

  String get totalValueLabel {
    if (totalValue <= 0) return 'TBD';
    return NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 0)
        .format(totalValue);
  }

  factory _AssetStats.fromModels(List<_AssetViewModel> assets) {
    final active = assets.where((asset) => asset.status == 'active').length;
    final maintenance =
        assets.where((asset) => asset.status == 'maintenance').length;
    final totalValue =
        assets.fold<double>(0, (sum, asset) => sum + asset.valueAmount);
    return _AssetStats(
      totalAssets: assets.length,
      activeAssets: active,
      maintenanceAssets: maintenance,
      totalValue: totalValue,
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _AssetStatsGrid extends StatelessWidget {
  const _AssetStatsGrid({
    required this.stats,
    required this.totalAssetsNote,
  });

  final _AssetStats stats;
  final String totalAssetsNote;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: crossAxisCount > 2 ? 2.3 : 1.5,
          children: [
            _AssetStatCard(
              label: 'Total Assets',
              value: formatter.format(stats.totalAssets),
              note: totalAssetsNote,
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFF3B82F6),
            ),
            _AssetStatCard(
              label: 'Active Assets',
              value: formatter.format(stats.activeAssets),
              note: 'Currently in use',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF22C55E),
            ),
            _AssetStatCard(
              label: 'Maintenance',
              value: formatter.format(stats.maintenanceAssets),
              note: 'Requires attention',
              icon: Icons.warning_amber_outlined,
              color: const Color(0xFFF59E0B),
            ),
            _AssetStatCard(
              label: 'Total Value',
              value: stats.totalValueLabel,
              note: 'Asset portfolio',
              icon: Icons.trending_up,
              color: const Color(0xFF8B5CF6),
            ),
          ],
        );
      },
    );
  }
}

class _AssetStatCard extends StatelessWidget {
  const _AssetStatCard({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySummary {
  _CategorySummary({
    required this.name,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String name;
  final int count;
  final IconData icon;
  final Color color;

  factory _CategorySummary.fromName(String name, int count) {
    final lower = name.toLowerCase();
    if (lower.contains('machinery') || lower.contains('equipment')) {
      return _CategorySummary(
        name: name,
        count: count,
        icon: Icons.precision_manufacturing_outlined,
        color: const Color(0xFF3B82F6),
      );
    }
    if (lower.contains('vehicle') || lower.contains('transport')) {
      return _CategorySummary(
        name: name,
        count: count,
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFF8B5CF6),
      );
    }
    if (lower.contains('tool') || lower.contains('power')) {
      return _CategorySummary(
        name: name,
        count: count,
        icon: Icons.build_outlined,
        color: const Color(0xFFF59E0B),
      );
    }
    if (lower.contains('safety')) {
      return _CategorySummary(
        name: name,
        count: count,
        icon: Icons.health_and_safety_outlined,
        color: const Color(0xFF10B981),
      );
    }
    return _CategorySummary(
      name: name,
      count: count,
      icon: Icons.category_outlined,
      color: const Color(0xFF64748B),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<_CategorySummary> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asset Categories',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 1100 ? 3 : (width >= 720 ? 2 : 1);
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.8,
              children: categories.map((category) {
                final isSelected = selected == category.name;
                return InkWell(
                  onTap: () => onSelected(isSelected ? 'all' : category.name),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? category.color.withValues(alpha: 0.12)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? category.color
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: category.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(category.icon, color: category.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                category.name,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${category.count} assets',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _MaintenanceItem {
  _MaintenanceItem({
    required this.assetName,
    required this.dueDate,
    required this.priority,
    required this.type,
  });

  final String assetName;
  final DateTime dueDate;
  final String priority;
  final String type;

  factory _MaintenanceItem.fromAsset(
    String name,
    DateTime dueDate,
    String type,
  ) {
    final daysUntil = dueDate.difference(DateTime.now()).inDays;
    final priority = daysUntil <= 0
        ? 'high'
        : daysUntil <= 7
            ? 'high'
            : daysUntil <= 14
                ? 'medium'
                : 'low';
    return _MaintenanceItem(
      assetName: name,
      dueDate: dueDate,
      priority: priority,
      type: type,
    );
  }
}

class _MaintenanceScheduleCard extends StatelessWidget {
  const _MaintenanceScheduleCard({
    required this.schedule,
    required this.onViewAll,
  });

  final List<_MaintenanceItem> schedule;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upcoming Maintenance',
                  style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              TextButton(onPressed: onViewAll, child: const Text('View All')),
            ],
          ),
          const SizedBox(height: 12),
          if (schedule.isEmpty)
            Column(
              children: [
                const SizedBox(height: 16),
                Icon(
                  Icons.event_available,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'No upcoming maintenance',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount =
                    width >= 1100 ? 4 : (width >= 720 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: crossAxisCount > 1 ? 1.6 : 2.4,
                  children: schedule
                      .map((item) => _MaintenanceTile(item: item))
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MaintenanceTile extends StatelessWidget {
  const _MaintenanceTile({required this.item});

  final _MaintenanceItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = _priorityColors(item.priority, isDark);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.badge,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.priority.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.assetName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Due: ${DateFormat('MMM d').format(item.dueDate)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.type,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityColors {
  const _PriorityColors({
    required this.background,
    required this.border,
    required this.text,
    required this.badge,
  });

  final Color background;
  final Color border;
  final Color text;
  final Color badge;
}

_PriorityColors _priorityColors(String priority, bool isDark) {
  if (priority == 'high') {
    return _PriorityColors(
      background: isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEE2E2),
      border: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
      text: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
      badge: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
    );
  }
  if (priority == 'medium') {
    return _PriorityColors(
      background: isDark ? const Color(0xFF3D2F0E) : const Color(0xFFFEF3C7),
      border: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
      text: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
      badge: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
    );
  }
  return _PriorityColors(
    background: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
    border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
    text: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280),
    badge: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
  );
}

class _InspectionToolsCard extends StatelessWidget {
  const _InspectionToolsCard({
    required this.onScan,
    required this.onInspection,
    required this.onPhoto,
    required this.onSchedule,
  });

  final VoidCallback onScan;
  final VoidCallback onInspection;
  final VoidCallback onPhoto;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1F2937), Color(0xFF111827)]
              : const [Color(0xFFF5F3FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check, size: 18),
              const SizedBox(width: 8),
              Text(
                'Asset Inspection & Tracking Tools',
                style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 900 ? 4 : (width >= 720 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _ToolTile(
                    icon: Icons.qr_code_scanner,
                    title: 'QR Code Scanner',
                    subtitle: 'Link assets via QR codes',
                    color: const Color(0xFF7C3AED),
                    onTap: onScan,
                  ),
                  _ToolTile(
                    icon: Icons.videocam_outlined,
                    title: 'Video Inspection',
                    subtitle: 'Record inspections',
                    color: const Color(0xFF2563EB),
                    onTap: onInspection,
                  ),
                  _ToolTile(
                    icon: Icons.photo_camera_outlined,
                    title: 'Photo Documentation',
                    subtitle: 'Capture conditions',
                    color: const Color(0xFF16A34A),
                    onTap: onPhoto,
                  ),
                  _ToolTile(
                    icon: Icons.calendar_month_outlined,
                    title: 'Schedule Inspections',
                    subtitle: 'Manage cadence',
                    color: const Color(0xFFF97316),
                    onTap: onSchedule,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetGridCard extends StatelessWidget {
  const _AssetGridCard({
    required this.model,
    required this.onOpen,
    required this.onEdit,
    required this.onInspect,
  });

  final _AssetViewModel model;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onInspect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
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
              _AssetIconBadge(type: model.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusPill(status: model.status),
                    const SizedBox(height: 8),
                    Text(
                      model.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.category,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: border),
          const SizedBox(height: 12),
          _MetaRow(label: 'Location', value: model.location),
          _MetaRow(label: 'Assigned', value: model.assignedTo),
          _MetaRow(label: 'Next Maint.', value: model.nextMaintenanceLabel),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onInspect,
                  child: const Text('Inspect'),
                ),
              ),
              const SizedBox(width: 8),
              _IconActionButton(
                icon: Icons.visibility_outlined,
                tooltip: 'View',
                onPressed: onOpen,
              ),
              const SizedBox(width: 8),
              _IconActionButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                onPressed: onEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssetsListTable extends StatelessWidget {
  const _AssetsListTable({
    required this.assets,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final List<_AssetViewModel> assets;
  final ValueChanged<Equipment> onOpen;
  final ValueChanged<Equipment> onEdit;
  final ValueChanged<Equipment> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1100),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFF9FAFB),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  children: const [
                    _TableHeader(label: 'Asset', flex: 3),
                    _TableHeader(label: 'Status', flex: 1),
                    _TableHeader(label: 'Location', flex: 2),
                    _TableHeader(label: 'Assigned', flex: 2),
                    _TableHeader(label: 'Next Maint.', flex: 2),
                    _TableHeader(label: 'Condition', flex: 1),
                    _TableHeader(label: 'Actions', flex: 2),
                  ],
                ),
              ),
              ...assets.map(
                (asset) => InkWell(
                  onTap: () => onOpen(asset.equipment),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: border)),
                    ),
                    child: Row(
                      children: [
                        _TableCell(
                          flex: 3,
                          child: Text(
                            asset.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _TableCell(
                          flex: 1,
                          child: _StatusPill(status: asset.status),
                        ),
                        _TableCell(flex: 2, child: Text(asset.location)),
                        _TableCell(flex: 2, child: Text(asset.assignedTo)),
                        _TableCell(
                          flex: 2,
                          child: Text(asset.nextMaintenanceLabel),
                        ),
                        _TableCell(flex: 1, child: Text(asset.condition)),
                        _TableCell(
                          flex: 2,
                          child: Row(
                            children: [
                              TextButton(
                                onPressed: () => onEdit(asset.equipment),
                                child: const Text('Edit'),
                              ),
                              TextButton(
                                onPressed: () => onDelete(asset.equipment),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _AssetViewModel {
  _AssetViewModel({
    required this.equipment,
    required this.name,
    required this.category,
    required this.type,
    required this.status,
    required this.location,
    required this.assignedTo,
    required this.condition,
    required this.valueAmount,
    required this.serialNumber,
    required this.updatedAt,
    required this.nextMaintenanceDate,
  });

  final Equipment equipment;
  final String name;
  final String category;
  final String type;
  final String status;
  final String location;
  final String assignedTo;
  final String condition;
  final double valueAmount;
  final String serialNumber;
  final DateTime updatedAt;
  final DateTime? nextMaintenanceDate;

  String get nextMaintenanceLabel => nextMaintenanceDate == null
      ? 'Not scheduled'
      : DateFormat('MMM d').format(nextMaintenanceDate!);

  factory _AssetViewModel.fromEquipment(Equipment asset) {
    final metadata = asset.metadata ?? const <String, dynamic>{};
    final statusRaw = _readString(metadata['status'], '').toLowerCase();
    final status = statusRaw.isNotEmpty
        ? statusRaw
        : (!asset.isActive
            ? 'inactive'
            : asset.isMaintenanceDue
                ? 'maintenance'
                : 'active');
    final category = _readString(asset.category, 'Uncategorized');
    final type = _firstNonEmpty(
      [
        _readString(metadata['type'], ''),
        _readString(metadata['assetType'], ''),
        _readString(metadata['equipmentType'], ''),
      ],
      category,
    );
    final location = _firstNonEmpty(
      [
        _readString(asset.currentLocation, ''),
        _readString(metadata['location'], ''),
      ],
      'Unassigned',
    );
    final assignedTo = _firstNonEmpty(
      [
        _readString(asset.assignedTo, ''),
        _readString(asset.contactName, ''),
        _readString(metadata['assignedTo'], ''),
      ],
      'Unassigned',
    );
    final condition = _readString(metadata['condition'], 'Good');
    final valueAmount = _parseValue(
      metadata['value'] ??
          metadata['estimatedValue'] ??
          metadata['assetValue'],
    );
    final serial = _firstNonEmpty(
      [
        _readString(asset.serialNumber, ''),
        _readString(asset.rfidTag, ''),
      ],
      'N/A',
    );
    final updatedAt = asset.updatedAt ?? asset.createdAt ?? DateTime.now();

    return _AssetViewModel(
      equipment: asset,
      name: asset.name,
      category: category,
      type: type,
      status: status,
      location: location,
      assignedTo: assignedTo,
      condition: condition,
      valueAmount: valueAmount,
      serialNumber: serial,
      updatedAt: updatedAt,
      nextMaintenanceDate: asset.nextMaintenanceDate,
    );
  }

  static String _readString(dynamic value, String fallback) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String _firstNonEmpty(List<String> values, String fallback) {
    for (final value in values) {
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  static double _parseValue(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = _statusColors(status, isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusColors {
  const _StatusColors({required this.background, required this.text});

  final Color background;
  final Color text;
}

_StatusColors _statusColors(String status, bool isDark) {
  switch (status.toLowerCase()) {
    case 'active':
      return _StatusColors(
        background:
            isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
        text: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
      );
    case 'maintenance':
      return _StatusColors(
        background:
            isDark ? const Color(0xFF3D2F0E) : const Color(0xFFFEF3C7),
        text: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
      );
    default:
      return _StatusColors(
        background:
            isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        text: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280),
      );
  }
}

class _AssetIconBadge extends StatelessWidget {
  const _AssetIconBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_iconForType(type), color: Colors.white),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          minimumSize: const Size(0, 40),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.selected, required this.onChanged});

  final _AssetsViewMode selected;
  final ValueChanged<_AssetsViewMode> onChanged;

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
            isSelected: selected == _AssetsViewMode.grid,
            onTap: () => onChanged(_AssetsViewMode.grid),
          ),
          _ToggleButton(
            icon: Icons.view_list_outlined,
            isSelected: selected == _AssetsViewMode.list,
            onTap: () => onChanged(_AssetsViewMode.list),
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

class _AssetPickerSheet extends StatelessWidget {
  const _AssetPickerSheet({required this.assets});

  final List<_AssetViewModel> assets;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Select an asset',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: assets.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final asset = assets[index];
                  return ListTile(
                    leading: Icon(_iconForType(asset.type)),
                    title: Text(asset.name),
                    subtitle:
                        Text('${asset.category} • ${asset.location}'),
                    onTap: () => Navigator.pop(context, asset.equipment),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceSheet extends StatelessWidget {
  const _MaintenanceSheet({required this.items});

  final List<_MaintenanceItem> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Maintenance Schedule',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: const Icon(Icons.build_outlined),
                    title: Text(item.assetName),
                    subtitle: Text(
                      '${DateFormat('MMM d').format(item.dueDate)} • ${item.type}',
                    ),
                    trailing: Text(item.priority.toUpperCase()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAssetsCard extends StatelessWidget {
  const _EmptyAssetsCard({required this.onClear, required this.onCreate});

  final VoidCallback onClear;
  final VoidCallback onCreate;

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
              'No assets match your filters.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Clear filters or add a new asset to get started.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Clear filters'),
                  onPressed: onClear,
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add asset'),
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

class _AssetsErrorView extends StatelessWidget {
  const _AssetsErrorView({required this.error});

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

IconData _iconForType(String type) {
  final lower = type.toLowerCase();
  if (lower.contains('vehicle')) return Icons.local_shipping_outlined;
  if (lower.contains('tool')) return Icons.build_outlined;
  if (lower.contains('power')) return Icons.power_outlined;
  if (lower.contains('safety')) return Icons.health_and_safety_outlined;
  if (lower.contains('equipment')) {
    return Icons.precision_manufacturing_outlined;
  }
  return Icons.inventory_2_outlined;
}
