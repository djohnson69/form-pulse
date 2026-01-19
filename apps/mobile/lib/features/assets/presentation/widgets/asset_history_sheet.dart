import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../data/assets_provider.dart';

class AssetHistorySheet extends ConsumerWidget {
  const AssetHistorySheet({super.key, required this.asset});

  final Equipment asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionsAsync = ref.watch(assetInspectionsProvider(asset.id));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Maintenance History',
                    style: theme.textTheme.titleMedium?.copyWith(
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
            const SizedBox(height: 12),
            Flexible(
              child: inspectionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => _HistoryError(error: e.toString()),
                data: (inspections) {
                  if (inspections.isEmpty) {
                    return _EmptyHistory(border: border);
                  }
                  final records = _recordsFromInspections(inspections);
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _HistoryCard(
                        record: records[index],
                        border: border,
                      );
                    },
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

class _MaintenanceRecord {
  const _MaintenanceRecord({
    required this.type,
    required this.date,
    required this.technician,
    required this.notes,
    required this.cost,
  });

  final String type;
  final DateTime date;
  final String technician;
  final String notes;
  final String cost;
}

List<_MaintenanceRecord> _recordsFromInspections(
  List<AssetInspection> inspections,
) {
  return inspections.map((inspection) {
    final metadata = inspection.metadata ?? const <String, dynamic>{};
    final type = _readString(
      metadata['type'] ?? metadata['maintenanceType'],
      'Inspection',
    );
    final technician = _readString(
      inspection.createdByName ?? metadata['technician'],
      'Unknown',
    );
    final notes = _readString(
      inspection.notes ?? metadata['notes'],
      'No notes provided.',
    );
    final cost = _readString(metadata['cost'], 'N/A');
    return _MaintenanceRecord(
      type: type,
      date: inspection.inspectedAt,
      technician: technician,
      notes: notes,
      cost: cost,
    );
  }).toList();
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record, required this.border});

  final _MaintenanceRecord record;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final badgeBackground =
        isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
    final badgeText = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    final secondaryText = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.type,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  record.cost,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: badgeText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat.yMMMMd().format(record.date),
            style: secondaryText,
          ),
          const SizedBox(height: 8),
          Text('Technician: ${record.technician}', style: secondaryText),
          const SizedBox(height: 4),
          Text(record.notes, style: secondaryText),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.border});

  final Color border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No maintenance history available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Text('Error: $error');
  }
}

String _readString(dynamic value, String fallback) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}
