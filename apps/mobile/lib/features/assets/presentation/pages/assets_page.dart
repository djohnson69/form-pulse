import 'dart:convert';

import 'package:flutter/foundation.dart';
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
import '../widgets/asset_history_sheet.dart';
import '../widgets/inspection_schedule_sheet.dart';

enum _AssetsViewMode { grid, list }

const _categoryFilterOptions = <String>[
  'Heavy Machinery',
  'Transportation',
  'Power Tools',
  'Safety Equipment',
];

const _locationFilterOptions = <String>[
  'Warehouse A',
  'Site B',
  'Site C',
  'Workshop',
  'Storage Yard',
  'Maintenance Bay',
];

const _categorySpecs = <_CategorySpec>[
  _CategorySpec(
    name: 'Heavy Machinery',
    slug: 'heavy-machinery',
    emoji: '🏗️',
  ),
  _CategorySpec(
    name: 'Transportation',
    slug: 'transportation',
    emoji: '🚚',
  ),
  _CategorySpec(
    name: 'Power Tools',
    slug: 'power-tools',
    emoji: '⚙️',
  ),
];

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
  final _AssetsViewMode _viewMode = _AssetsViewMode.grid;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      body: equipmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _AssetsErrorView(error: e.toString()),
        data: (assets) {
          final models =
              assets.map((asset) => _AssetViewModel.fromEquipment(asset)).toList();
          final scopedModels = _applyRoleFilter(models, role);
          final categories = _buildCategorySummaries(scopedModels);
          final locations = _buildLocations();
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
              padding: EdgeInsets.all(isWide ? 24 : 16),
              children: [
                _buildHeader(
                  context,
                  role: role,
                  canManageAssets: canManageAssets,
                  roleIndicator: roleIndicator,
                  exportAssets: filtered,
                ),
                const SizedBox(height: 24),
                _AssetStatsGrid(stats: stats, totalAssetsNote: totalNote),
                const SizedBox(height: 24),
                _CategorySection(
                  categories: categories,
                  selected: _categoryFilter,
                  onSelected: (value) =>
                      setState(() => _categoryFilter = value),
                ),
                const SizedBox(height: 24),
                _MaintenanceScheduleCard(
                  schedule: maintenancePreview,
                  onViewAll: () => _showMaintenanceSheet(
                    context,
                    maintenanceSchedule,
                  ),
                ),
                const SizedBox(height: 24),
                _InspectionToolsCard(
                  onScan: () => _openQrScanner(context),
                  onInspection: () => _openInspectionTool(
                    context,
                    models,
                    titleOverride: 'Video Inspection',
                    captureType: InspectionCaptureType.video,
                    useFirstAsset: true,
                  ),
                  onPhoto: () => _openInspectionTool(
                    context,
                    models,
                    titleOverride: 'Photo Documentation',
                    captureType: InspectionCaptureType.photo,
                    useFirstAsset: true,
                  ),
                  onSchedule: () => _openScheduleTool(context, models),
                ),
                const SizedBox(height: 24),
                _buildAdvancedFilters(
                  context,
                  _categoryFilterOptions,
                  locations,
                ),
                const SizedBox(height: 24),
                _buildFilters(
                  context,
                  filteredCount: filtered.length,
                  totalCount: scopedModels.length,
                ),
                const SizedBox(height: 24),
                if (filtered.isEmpty)
                  const _EmptyAssetsCard()
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
        final isWide = constraints.maxWidth >= 768;
        final showLabel = constraints.maxWidth >= 640;
        final subtitle = _roleSubtitle(role);
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final indicatorBackground =
            isDark ? const Color(0xFF1E3A8A).withOpacity(0.3) : const Color(0xFFEFF6FF);
        final indicatorBorder =
            isDark ? const Color(0xFF3B82F6).withOpacity(0.3) : const Color(0xFFBFDBFE);
        final indicatorText =
            isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
          fontSize: 16,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
        );
        final exportButtonStyle = OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
          foregroundColor: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 16 : 12,
            vertical: 10,
          ),
          side: BorderSide(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        );
        final addButtonStyle = ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: const Color(0xFF2563EB).withOpacity(0.2),
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 16 : 12,
            vertical: 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        );
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asset Management',
              style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: isWide ? 30 : 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: subtitleStyle,
            ),
            if (roleIndicator != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: indicatorBackground,
                  borderRadius: BorderRadius.circular(8),
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: indicatorText,
                          fontWeight: FontWeight.w500,
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
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (showLabel)
              OutlinedButton.icon(
                style: exportButtonStyle,
                onPressed: () => _exportAssets(context, exportAssets),
                icon: const Icon(Icons.download_outlined, size: 20),
                label: const Text('Export'),
              )
            else
              OutlinedButton(
                style: exportButtonStyle,
                onPressed: () => _exportAssets(context, exportAssets),
                child: const Icon(Icons.download_outlined, size: 20),
              ),
            if (canManageAssets)
              if (showLabel)
                ElevatedButton.icon(
                  style: addButtonStyle,
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Asset'),
                )
              else
                ElevatedButton(
                  style: addButtonStyle,
                  onPressed: () => _openEditor(context),
                  child: const Icon(Icons.add, size: 20),
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
            const SizedBox(height: 16),
            controls,
          ],
        );
      },
    );
  }

  bool _canManageAssets(UserRole role) {
    return role.isAdmin ||
        role == UserRole.manager ||
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
    if (user == null) return const <_AssetViewModel>[];
    final userId = user.id.toLowerCase();
    final email = user.email?.toLowerCase();
    final filtered = models.where((model) {
      final assigned = model.equipment.assignedTo?.toLowerCase();
      if (assigned != null && assigned == userId) return true;
      final contactEmail = model.equipment.contactEmail?.toLowerCase();
      if (email != null && contactEmail == email) return true;
      return false;
    }).toList();
    return filtered;
  }

  Widget _buildAdvancedFilters(
    BuildContext context,
    List<String> categoryOptions,
    List<String> locations,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final activeCount = [
      if (_categoryFilter != 'all') true,
      if (_locationFilter != 'all') true,
      if (_contactFilter.isNotEmpty) true,
    ].length;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : const Color(0xFF111827),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Text('Advanced Search & Filters', style: titleStyle),
              if (activeCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$activeCount active',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final columns =
                  maxWidth >= 1024 ? 4 : (maxWidth >= 768 ? 2 : 1);
              const spacing = 16.0;
              final itemWidth = columns == 1
                  ? maxWidth
                  : (maxWidth - spacing * (columns - 1)) / columns;
              final fieldBorder = OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFD1D5DB),
                ),
              );
              final fieldDecoration = InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF111827) : Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: fieldBorder,
                enabledBorder: fieldBorder,
                focusedBorder: fieldBorder.copyWith(
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1.5,
                  ),
                ),
              );
              final categoryField = _FilterField(
                label: 'Category',
                child: DropdownButtonFormField<String>(
                  value: _categoryFilter,
                  isExpanded: true,
                  decoration: fieldDecoration,
                  dropdownColor:
                      isDark ? const Color(0xFF111827) : Colors.white,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF111827),
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
                    ...categoryOptions.map(
                      (category) => DropdownMenuItem(
                        value: _slugify(category),
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
                  decoration: fieldDecoration,
                  dropdownColor:
                      isDark ? const Color(0xFF111827) : Colors.white,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF111827),
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
                        value: _slugify(location),
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
                  decoration: fieldDecoration.copyWith(
                    prefixIcon: Icon(
                      Icons.person_outline,
                      size: 16,
                      color: isDark
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF9CA3AF),
                    ),
                    hintText: 'Search by name...',
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF111827),
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
                  height: 40,
                  child: OutlinedButton(
                    onPressed: _clearFilters,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF374151)
                            : const Color(0xFFD1D5DB),
                      ),
                      foregroundColor: isDark
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF374151),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
              );

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  categoryField,
                  locationField,
                  contactField,
                  actionField,
                ].map((field) {
                  return SizedBox(width: itemWidth, child: field);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(
    BuildContext context, {
    required int filteredCount,
    required int totalCount,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 768;
              final fieldBorder = OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFD1D5DB),
                ),
              );
              final fieldDecoration = InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF111827) : Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: fieldBorder,
                enabledBorder: fieldBorder,
                focusedBorder: fieldBorder.copyWith(
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1.5,
                  ),
                ),
              );
              final children = [
                Expanded(
                  flex: isWide ? 2 : 0,
                  child: TextField(
                    controller: _searchController,
                    decoration: fieldDecoration.copyWith(
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: isDark
                            ? const Color(0xFF6B7280)
                            : const Color(0xFF9CA3AF),
                      ),
                      hintText: 'Search assets by name or serial number...',
                      hintStyle: TextStyle(
                        fontSize: 16,
                        color: isDark
                            ? const Color(0xFF6B7280)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.trim().toLowerCase());
                    },
                  ),
                ),
                SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: fieldDecoration,
                    dropdownColor:
                        isDark ? const Color(0xFF111827) : Colors.white,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF111827),
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
          if (filteredCount < totalCount)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Showing $filteredCount of $totalCount assets',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
        ],
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
        final crossAxisCount = width >= 1024 ? 3 : (width >= 768 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 24,
          crossAxisSpacing: 24,
          childAspectRatio: crossAxisCount > 1 ? 0.82 : 0.95,
          children: assets
              .map(
                (asset) => _AssetGridCard(
                  model: asset,
                  onOpen: () => _openDetail(context, asset.equipment),
                  onHistory: () => _openHistory(context, asset.equipment),
                  onQr: () => _openDetail(context, asset.equipment),
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
          asset.serialNumber.toLowerCase().contains(_searchQuery);
      final matchesContact = _contactFilter.isEmpty ||
          asset.assignedTo.toLowerCase().contains(_contactFilter);
      final matchesStatus =
          _statusFilter == 'all' || asset.status == _statusFilter;
      final matchesCategory =
          _categoryFilter == 'all' ||
          _slugify(asset.category) == _categoryFilter;
      final matchesLocation =
          _locationFilter == 'all' ||
          _slugify(asset.location) == _locationFilter;
      return matchesSearch &&
          matchesContact &&
          matchesStatus &&
          matchesCategory &&
          matchesLocation;
    }).toList();
  }

  List<_CategorySummary> _buildCategorySummaries(
    List<_AssetViewModel> assets,
  ) {
    return _categorySpecs.map((spec) {
      final count = assets
          .where((asset) => _slugify(asset.category) == spec.slug)
          .length;
      return _CategorySummary(
        name: spec.name,
        slug: spec.slug,
        count: count,
        emoji: spec.emoji,
      );
    }).toList();
  }

  List<String> _buildLocations() {
    return _locationFilterOptions;
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

  Future<void> _openHistory(BuildContext context, Equipment asset) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AssetHistorySheet(asset: asset),
    );
  }

  Future<void> _openInspection(
    BuildContext context,
    Equipment asset, {
    InspectionCaptureType? captureType,
    String? titleOverride,
  }) async {
    final result = await Navigator.of(context).push<AssetInspection?>(
      MaterialPageRoute(
        builder: (_) => InspectionEditorPage(
          asset: asset,
          titleOverride: titleOverride,
          initialCapture: captureType,
        ),
      ),
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
    List<_AssetViewModel> assets, {
    InspectionCaptureType? captureType,
    String? titleOverride,
    bool useFirstAsset = false,
  }) async {
    if (assets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assets available.')),
      );
      return;
    }
    final selection = useFirstAsset ? assets.first.equipment : null;
    final picked =
        selection ?? await _pickAsset(context, assets);
    if (picked == null || !mounted) return;
    await _openInspection(
      context,
      picked,
      captureType: captureType,
      titleOverride: titleOverride,
    );
  }

  Future<void> _openScheduleTool(
    BuildContext context,
    List<_AssetViewModel> assets,
  ) async {
    if (assets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assets available.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => InspectionScheduleSheet(
        assets: assets.map((asset) => asset.equipment).toList(),
      ),
    );
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
    final thousands = (totalValue / 1000).round();
    return '\$${thousands}K';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 8),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedNote =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final greenNote =
        isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    final yellowNote =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 768 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: crossAxisCount > 2 ? 2.3 : 1.5,
          children: [
            _AssetStatCard(
              label: 'Total Assets',
              value: formatter.format(stats.totalAssets),
              note: totalAssetsNote,
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFF3B82F6),
              noteColor: mutedNote,
            ),
            _AssetStatCard(
              label: 'Active Assets',
              value: formatter.format(stats.activeAssets),
              note: 'Currently in use',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF22C55E),
              noteColor: greenNote,
            ),
            _AssetStatCard(
              label: 'Maintenance',
              value: formatter.format(stats.maintenanceAssets),
              note: 'Requires attention',
              icon: Icons.warning_amber_outlined,
              color: const Color(0xFFF59E0B),
              noteColor: yellowNote,
            ),
            _AssetStatCard(
              label: 'Total Value',
              value: stats.totalValueLabel,
              note: 'Asset portfolio',
              icon: Icons.trending_up,
              color: const Color(0xFF8B5CF6),
              noteColor: mutedNote,
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
    required this.noteColor,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
  final Color noteColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF6B7280),
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: noteColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySpec {
  const _CategorySpec({
    required this.name,
    required this.slug,
    required this.emoji,
  });

  final String name;
  final String slug;
  final String emoji;
}

class _CategorySummary {
  _CategorySummary({
    required this.name,
    required this.slug,
    required this.count,
    required this.emoji,
  });

  final String name;
  final String slug;
  final int count;
  final String emoji;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedBackground = isDark
        ? const Color(0xFF1E3A8A).withOpacity(0.3)
        : const Color(0xFFEFF6FF);
    final selectedBorder =
        isDark ? const Color(0xFF2563EB) : const Color(0xFF93C5FD);
    final defaultBorder =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asset Categories',
          style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
              ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 768 ? 3 : 1;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.8,
              children: categories.map((category) {
                final isSelected = selected == category.slug;
                return InkWell(
                  onTap: () => onSelected(isSelected ? 'all' : category.slug),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? selectedBackground
                              : (isDark ? const Color(0xFF1F2937) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? selectedBorder : defaultBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          category.emoji,
                          style: const TextStyle(fontSize: 30),
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
                                    ?.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${category.count} assets',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontSize: 14,
                                      color: isDark
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF6B7280),
                                    ),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 20,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upcoming Maintenance',
                  style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? Colors.white : const Color(0xFF111827),
                      ),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  foregroundColor:
                      isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (schedule.isEmpty)
            Column(
              children: [
                const SizedBox(height: 16),
                Icon(
                  Icons.calendar_today,
                  size: 48,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'No upcoming maintenance for your assets',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount =
                    width >= 1024 ? 4 : (width >= 768 ? 2 : 1);
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.badge,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.priority.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    color: colors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.access_time,
                size: 16,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.assetName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Due: ${DateFormat.yMd().format(item.dueDate)}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.type,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
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
  return _PriorityColors(
    background: isDark ? const Color(0xFF3D2F0E) : const Color(0xFFFEF3C7),
    border: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
    text: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
    badge: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
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
    final border = isDark
        ? const Color(0xFF7C3AED).withOpacity(0.3)
        : const Color(0xFFDDD6FE);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF4C1D95).withOpacity(0.2),
                  const Color(0xFF1F2937),
                ]
              : const [Color(0xFFF5F3FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check,
                size: 20,
                color: Color(0xFF7C3AED),
              ),
              const SizedBox(width: 8),
              Text(
                'Asset Inspection & Tracking Tools',
                style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.white : const Color(0xFF111827),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount =
                    width >= 1024 ? 4 : (width >= 768 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
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
                    subtitle: 'Record video inspections',
                    color: const Color(0xFF2563EB),
                    onTap: onInspection,
                  ),
                  _ToolTile(
                    icon: Icons.photo_camera_outlined,
                    title: 'Photo Documentation',
                    subtitle: 'Capture asset conditions',
                    color: const Color(0xFF16A34A),
                    onTap: onPhoto,
                  ),
                  _ToolTile(
                    icon: Icons.calendar_month_outlined,
                    title: 'Schedule Inspections',
                    subtitle: 'Daily/Weekly/Monthly',
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
    final borderColor =
        isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);
    final tileBackground =
        isDark ? const Color(0xFF1F2937).withOpacity(0.5) : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: _DashedBorder(
          color: borderColor,
          radius: 12,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: tileBackground,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends StatelessWidget {
  const _DashedBorder({
    required this.color,
    required this.radius,
    required this.child,
  });

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final length = dashWidth;
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _AssetGridCard extends StatefulWidget {
  const _AssetGridCard({
    required this.model,
    required this.onOpen,
    required this.onHistory,
    required this.onQr,
  });

  final _AssetViewModel model;
  final VoidCallback onOpen;
  final VoidCallback onHistory;
  final VoidCallback onQr;

  @override
  State<_AssetGridCard> createState() => _AssetGridCardState();
}

class _AssetGridCardState extends State<_AssetGridCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final model = widget.model;
    final statusBarColor = _statusBarColor(model.status, isDark);
    final valueLabel = _formatCurrency(model.valueAmount);
    final usageLabel = model.usageHours == null
        ? '--'
        : NumberFormat.decimalPattern().format(model.usageHours);
    final conditionColor = _conditionColor(model.condition, isDark);
    final supportsHover = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final showShadow = supportsHover && _hovering;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: statusBarColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
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
                              model.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              model.category,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 14,
                                color: isDark
                                    ? const Color(0xFF6B7280)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusPill(status: model.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MetaRow(
                    icon: Icons.place_outlined,
                    label: 'Location',
                    value: model.location,
                  ),
                  _MetaRow(
                    icon: Icons.person_outline,
                    label: 'Assigned To',
                    value: model.assignedTo,
                  ),
                  _MetaRow(
                    icon: Icons.qr_code_2,
                    label: 'Serial #',
                    value: model.serialNumber,
                    valueStyle: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  _MetaRow(
                    label: 'Value',
                    value: valueLabel,
                    valueStyle: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    isLast: true,
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: border),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Condition',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                      Text(
                        model.condition,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: conditionColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Usage Hours',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                      Text(
                        '$usageLabel hrs',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF374151).withOpacity(0.5)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Maintenance',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          model.nextMaintenanceLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onPressed: widget.onOpen,
                          child: const Text('View Details'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _IconActionButton(
                        icon: Icons.history,
                        onPressed: widget.onHistory,
                      ),
                      const SizedBox(width: 8),
                      _IconActionButton(
                        icon: Icons.qr_code,
                        onPressed: widget.onQr,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                      const BorderRadius.vertical(top: Radius.circular(12)),
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
    required this.usageHours,
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
  final int? usageHours;
  final double valueAmount;
  final String serialNumber;
  final DateTime updatedAt;
  final DateTime? nextMaintenanceDate;

  String get nextMaintenanceLabel => nextMaintenanceDate == null
      ? 'Not scheduled'
      : DateFormat.yMd().format(nextMaintenanceDate!);

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
    final usageHours = _parseInt(
      metadata['usageHours'] ??
          metadata['usage_hours'] ??
          metadata['hoursUsed'] ??
          metadata['hours'],
    );
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
      usageHours: usageHours,
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

  static int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    if (raw is String) {
      final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(cleaned);
    }
    return null;
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
    final label = status.trim();
    final display = label.isEmpty
        ? label
        : '${label[0].toUpperCase()}${label.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        display,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 12,
          color: colors.text,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatusColors {
  const _StatusColors({
    required this.background,
    required this.text,
    required this.border,
  });

  final Color background;
  final Color text;
  final Color border;
}

_StatusColors _statusColors(String status, bool isDark) {
  switch (status.toLowerCase()) {
    case 'active':
      return _StatusColors(
        background: isDark
            ? const Color(0xFF22C55E).withOpacity(0.2)
            : const Color(0xFFDCFCE7),
        text: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
        border: isDark
            ? const Color(0xFF22C55E).withOpacity(0.3)
            : const Color(0xFFBBF7D0),
      );
    case 'maintenance':
      return _StatusColors(
        background: isDark
            ? const Color(0xFFF59E0B).withOpacity(0.2)
            : const Color(0xFFFEF3C7),
        text: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
        border: isDark
            ? const Color(0xFFF59E0B).withOpacity(0.3)
            : const Color(0xFFFDE68A),
      );
    default:
      return _StatusColors(
        background:
            isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        text: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280),
        border:
            isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
      );
  }
}

Color _statusBarColor(String status, bool isDark) {
  switch (status.toLowerCase()) {
    case 'active':
      return const Color(0xFF22C55E);
    case 'maintenance':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF6B7280);
  }
}

String _formatCurrency(double amount) {
  if (amount <= 0) return 'TBD';
  return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(amount);
}

Color _conditionColor(String condition, bool isDark) {
  final normalized = condition.toLowerCase();
  if (normalized == 'excellent') {
    return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
  }
  if (normalized == 'good') {
    return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  }
  return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.icon,
    this.valueStyle,
    this.isLast = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final TextStyle? valueStyle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 14,
      color: isDark ? Colors.grey[400] : Colors.grey[600],
    );
    final valueStyleResolved = valueStyle ??
        theme.textTheme.bodySmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF111827),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: labelStyle?.color),
                  const SizedBox(width: 6),
                ],
                Flexible(child: Text(label, style: labelStyle)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: valueStyleResolved,
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
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 40),
        foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600],
        side: BorderSide(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Icon(icon, size: 16),
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF6B7280),
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
  const _EmptyAssetsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No assets found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search or filters',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

String _slugify(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
}
