import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../data/assets_provider.dart';
import '../../../dashboard/data/active_role_provider.dart';
import '../widgets/asset_history_sheet.dart';
import 'asset_editor_page.dart';
import 'inspection_editor_page.dart';

class AssetDetailPage extends ConsumerWidget {
  const AssetDetailPage({required this.asset, super.key});

  final Equipment asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeRoleProvider);
    final canManageAssets = _canManageAssets(role);
    final inspectionsAsync = ref.watch(assetInspectionsProvider(asset.id));
    final inspections = inspectionsAsync.asData?.value ?? const <AssetInspection>[];
    final details = _AssetDetailViewModel.fromEquipment(asset);
    final documentation = _DocumentationCounts.fromSources(
      inspections,
      asset.metadata,
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DetailHeader(
            name: asset.name,
            serialNumber: details.serialNumber,
            canManageAssets: canManageAssets,
            onEdit: () => _openEditor(context, ref),
            onDelete: () => _confirmDelete(context, ref),
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 16),
          _DetailsGrid(
            details: details,
            documentation: documentation,
          ),
          const SizedBox(height: 16),
          _QuickActionsSection(
            onHistory: () => _openHistory(context),
            onAddPhoto: () => _openInspectionCapture(
              context,
              ref,
              title: 'Photo Documentation',
              captureType: InspectionCaptureType.photo,
            ),
            onRecordVideo: () => _openInspectionCapture(
              context,
              ref,
              title: 'Video Inspection',
              captureType: InspectionCaptureType.video,
            ),
            onPrintQr: () => _printQr(context),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  bool _canManageAssets(UserRole role) {
    return role == UserRole.manager ||
        role == UserRole.admin ||
        role == UserRole.superAdmin ||
        role == UserRole.techSupport ||
        role == UserRole.supervisor;
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<Equipment?>(
      MaterialPageRoute(builder: (_) => AssetEditorPage(existing: asset)),
    );
    if (result != null) {
      ref.invalidate(equipmentProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset updated successfully.')),
      );
    }
  }

  Future<void> _openInspectionCapture(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required InspectionCaptureType captureType,
  }) async {
    final result = await Navigator.of(context).push<AssetInspection?>(
      MaterialPageRoute(
        builder: (_) => InspectionEditorPage(
          asset: asset,
          titleOverride: title,
          initialCapture: captureType,
        ),
      ),
    );
    if (result != null) {
      ref.invalidate(assetInspectionsProvider(asset.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection saved.')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete asset?'),
        content: const Text('This will permanently remove the asset.'),
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
    if (confirmed != true) return;
    final repo = ref.read(assetsRepositoryProvider);
    try {
      await repo.deleteEquipment(equipment: asset);
      ref.invalidate(equipmentProvider);
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset deleted.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _openHistory(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AssetHistorySheet(asset: asset),
    );
  }

  void _printQr(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Printing QR code for ${asset.name}...')),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.name,
    required this.serialNumber,
    required this.canManageAssets,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  final String name;
  final String serialNumber;
  final bool canManageAssets;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  serialNumber,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (canManageAssets) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
              tooltip: 'Edit Asset',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: 'Delete Asset',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({
    required this.details,
    required this.documentation,
  });

  final _AssetDetailViewModel details;
  final _DocumentationCounts documentation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final sections = [
          _SectionCard(
            title: 'Basic Information',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabelValue(
                  label: 'Category',
                  value: Text(details.category),
                ),
                _LabelValue(
                  label: 'Type',
                  value: Text(details.type),
                ),
                _LabelValue(
                  label: 'Status',
                  value: _StatusPill(status: details.status),
                ),
                _LabelValue(
                  label: 'Condition',
                  value: Text(
                    details.condition,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _conditionColor(details.condition, context),
                    ),
                  ),
                ),
                _LabelValue(
                  label: 'Value',
                  value: Text(
                    details.valueLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            title: 'Location & Assignment',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabelValue(
                  label: 'Location',
                  value: Text(details.location),
                ),
                _LabelValue(
                  label: 'Assigned To',
                  value: Text(details.assignedTo),
                ),
                _LabelValue(
                  label: 'Usage Hours',
                  value: Text(
                    details.usageHoursLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            title: 'Maintenance Schedule',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabelValue(
                  label: 'Last Maintenance',
                  value: Text(details.lastMaintenanceLabel),
                ),
                _LabelValue(
                  label: 'Next Maintenance',
                  value: Text(details.nextMaintenanceLabel),
                ),
              ],
            ),
          ),
          _SectionCard(
            title: 'Documentation',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabelValue(
                  label: 'Photos',
                  value: Text(
                    _pluralize(documentation.photoCount, 'photo'),
                  ),
                ),
                _LabelValue(
                  label: 'Videos',
                  value: Text(
                    _pluralize(documentation.videoCount, 'video'),
                  ),
                ),
                _LabelValue(
                  label: 'Maintenance Records',
                  value: Text(
                    _pluralize(documentation.recordCount, 'record'),
                  ),
                ),
              ],
            ),
          ),
        ];

        if (isWide) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: sections[0]),
                  const SizedBox(width: 12),
                  Expanded(child: sections[1]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: sections[2]),
                  const SizedBox(width: 12),
                  Expanded(child: sections[3]),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            sections[0],
            const SizedBox(height: 12),
            sections[1],
            const SizedBox(height: 12),
            sections[2],
            const SizedBox(height: 12),
            sections[3],
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

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
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 4),
          DefaultTextStyle(
            style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600) ??
                const TextStyle(fontWeight: FontWeight.w600),
            child: value,
          ),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({
    required this.onHistory,
    required this.onAddPhoto,
    required this.onRecordVideo,
    required this.onPrintQr,
  });

  final VoidCallback onHistory;
  final VoidCallback onAddPhoto;
  final VoidCallback onRecordVideo;
  final VoidCallback onPrintQr;

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
          Text(
            'Quick Actions',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 720 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _QuickActionTile(
                    icon: Icons.history,
                    label: 'View History',
                    onTap: onHistory,
                  ),
                  _QuickActionTile(
                    icon: Icons.photo_camera_outlined,
                    label: 'Add Photo',
                    onTap: onAddPhoto,
                  ),
                  _QuickActionTile(
                    icon: Icons.videocam_outlined,
                    label: 'Record Video',
                    onTap: onRecordVideo,
                  ),
                  _QuickActionTile(
                    icon: Icons.qr_code,
                    label: 'Print QR',
                    onTap: onPrintQr,
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

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetDetailViewModel {
  _AssetDetailViewModel({
    required this.serialNumber,
    required this.category,
    required this.type,
    required this.status,
    required this.condition,
    required this.valueLabel,
    required this.location,
    required this.assignedTo,
    required this.usageHoursLabel,
    required this.lastMaintenanceLabel,
    required this.nextMaintenanceLabel,
  });

  final String serialNumber;
  final String category;
  final String type;
  final String status;
  final String condition;
  final String valueLabel;
  final String location;
  final String assignedTo;
  final String usageHoursLabel;
  final String lastMaintenanceLabel;
  final String nextMaintenanceLabel;

  factory _AssetDetailViewModel.fromEquipment(Equipment asset) {
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
    final condition = _readString(metadata['condition'], 'Good');
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
    final lastMaintenance = asset.lastMaintenanceDate ??
        _parseDate(metadata['lastMaintenance'] ?? metadata['last_maintenance']);
    final nextMaintenance = asset.nextMaintenanceDate ??
        _parseDate(metadata['nextMaintenance'] ?? metadata['next_maintenance']);

    return _AssetDetailViewModel(
      serialNumber: serial,
      category: category,
      type: type,
      status: status,
      condition: condition,
      valueLabel: _formatCurrency(valueAmount),
      location: location,
      assignedTo: assignedTo,
      usageHoursLabel: usageHours == null
          ? '--'
          : '${NumberFormat.decimalPattern().format(usageHours)} hrs',
      lastMaintenanceLabel: lastMaintenance == null
          ? 'Not scheduled'
          : DateFormat.yMd().format(lastMaintenance),
      nextMaintenanceLabel: nextMaintenance == null
          ? 'Not scheduled'
          : DateFormat.yMd().format(nextMaintenance),
    );
  }
}

class _DocumentationCounts {
  const _DocumentationCounts({
    required this.photoCount,
    required this.videoCount,
    required this.recordCount,
  });

  final int photoCount;
  final int videoCount;
  final int recordCount;

  factory _DocumentationCounts.fromSources(
    List<AssetInspection> inspections,
    Map<String, dynamic>? metadata,
  ) {
    final attachments = inspections
        .expand((inspection) => inspection.attachments ?? const <MediaAttachment>[]);
    final inspectionPhotos =
        attachments.where((a) => a.type == 'photo').length;
    final inspectionVideos =
        attachments.where((a) => a.type == 'video').length;
    final metadataPhotos = _countList(metadata?['photos']);
    final metadataVideos = _countList(metadata?['videos']);
    final metadataRecords = _countList(
      metadata?['maintenanceHistory'] ?? metadata?['maintenance_history'],
    );
    return _DocumentationCounts(
      photoCount: metadataPhotos > 0 ? metadataPhotos : inspectionPhotos,
      videoCount: metadataVideos > 0 ? metadataVideos : inspectionVideos,
      recordCount: metadataRecords > 0 ? metadataRecords : inspections.length,
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
    final colors = _statusColors(status, isDark);
    final label = status.trim();
    final display = label.isEmpty
        ? label
        : '${label[0].toUpperCase()}${label.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        display,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w600,
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

Color _conditionColor(String condition, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final normalized = condition.toLowerCase();
  if (normalized == 'excellent') {
    return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
  }
  if (normalized == 'good') {
    return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  }
  return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
}

String _pluralize(int count, String label) {
  final suffix = count == 1 ? '' : 's';
  return '$count $label$suffix';
}

int _countList(dynamic value) {
  if (value is List) return value.length;
  return 0;
}

String _readString(dynamic value, String fallback) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String _firstNonEmpty(List<String> values, String fallback) {
  for (final value in values) {
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

double _parseValue(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }
  return 0;
}

int? _parseInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned);
  }
  return null;
}

DateTime? _parseDate(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

String _formatCurrency(double amount) {
  if (amount <= 0) return 'TBD';
  return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(amount);
}
