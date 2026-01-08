import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/assets_provider.dart';
import 'asset_editor_page.dart';
import 'inspection_editor_page.dart';
import 'incident_editor_page.dart';

class AssetDetailPage extends ConsumerWidget {
  const AssetDetailPage({required this.asset, super.key});

  final Equipment asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionsAsync = ref.watch(assetInspectionsProvider(asset.id));
    final incidentsAsync = ref.watch(incidentReportsProvider(asset.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(asset.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _openEditor(context, ref),
          ),
          IconButton(
            tooltip: 'Print QR',
            icon: const Icon(Icons.qr_code),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Printing QR code for ${asset.name}...'),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AssetSummary(asset: asset),
          const SizedBox(height: 16),
          _SectionHeader(
            title: 'Inspections',
            onAdd: () => _openInspectionEditor(context, ref),
          ),
          inspectionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => _InlineError(error: e.toString()),
            data: (inspections) {
              if (inspections.isEmpty) {
                return const _EmptySection(
                  text: 'No inspections yet. Add one to track condition.',
                );
              }
              return Column(
                children: inspections
                    .map((inspection) => _InspectionCard(inspection: inspection))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          _SectionHeader(
            title: 'Incident reports',
            onAdd: () => _openIncidentEditor(context, ref),
          ),
          incidentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => _InlineError(error: e.toString()),
            data: (incidents) {
              if (incidents.isEmpty) {
                return const _EmptySection(
                  text: 'No incident reports yet. Log incidents here.',
                );
              }
              return Column(
                children: incidents
                    .map((incident) => _IncidentCard(incident: incident))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<Equipment?>(
      MaterialPageRoute(builder: (_) => AssetEditorPage(existing: asset)),
    );
    if (result != null) {
      ref.invalidate(equipmentProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset updated successfully.')),
      );
    }
  }

  Future<void> _openInspectionEditor(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await Navigator.of(context).push<AssetInspection?>(
      MaterialPageRoute(
        builder: (_) => InspectionEditorPage(asset: asset),
      ),
    );
    if (result != null) {
      ref.invalidate(assetInspectionsProvider(asset.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection scheduled successfully.')),
      );
    }
  }

  Future<void> _openIncidentEditor(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await Navigator.of(context).push<IncidentReport?>(
      MaterialPageRoute(
        builder: (_) => IncidentEditorPage(asset: asset),
      ),
    );
    if (result != null) {
      ref.invalidate(incidentReportsProvider(asset.id));
    }
  }
}

class _AssetSummary extends StatelessWidget {
  const _AssetSummary({required this.asset});

  final Equipment asset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(asset.name, style: Theme.of(context).textTheme.titleLarge),
            if ((asset.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(asset.description!),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((asset.category ?? '').isNotEmpty)
                  _SummaryChip(label: 'Category', value: asset.category!),
                if ((asset.serialNumber ?? '').isNotEmpty)
                  _SummaryChip(label: 'Serial', value: asset.serialNumber!),
                if ((asset.rfidTag ?? '').isNotEmpty)
                  _SummaryChip(label: 'RFID', value: asset.rfidTag!),
                if ((asset.currentLocation ?? '').isNotEmpty)
                  _SummaryChip(label: 'Location', value: asset.currentLocation!),
                if ((asset.contactName ?? '').isNotEmpty)
                  _SummaryChip(label: 'Contact', value: asset.contactName!),
                if ((asset.contactEmail ?? '').isNotEmpty)
                  _SummaryChip(label: 'Email', value: asset.contactEmail!),
                if ((asset.contactPhone ?? '').isNotEmpty)
                  _SummaryChip(label: 'Phone', value: asset.contactPhone!),
                if ((asset.inspectionCadence ?? '').isNotEmpty)
                  _SummaryChip(
                    label: 'Inspection',
                    value: asset.inspectionCadence!,
                  ),
                if (asset.nextInspectionAt != null)
                  _SummaryChip(
                    label: 'Next inspection',
                    value: _formatDate(asset.nextInspectionAt!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label • $value'));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ],
    );
  }
}

class _InspectionCard extends StatelessWidget {
  const _InspectionCard({required this.inspection});

  final AssetInspection inspection;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          inspection.status == 'fail' ? Icons.report : Icons.check_circle,
          color: inspection.status == 'fail'
              ? Theme.of(context).colorScheme.error
              : Colors.green,
        ),
        title: Text('Status: ${inspection.status.toUpperCase()}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((inspection.notes ?? '').isNotEmpty) Text(inspection.notes!),
            Text(_formatDate(inspection.inspectedAt)),
          ],
        ),
        trailing: _AttachmentCount(count: inspection.attachments?.length ?? 0),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident});

  final IncidentReport incident;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          Icons.report_gmailerrorred,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(incident.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((incident.category ?? '').isNotEmpty)
              Text('Category: ${incident.category}'),
            if ((incident.description ?? '').isNotEmpty)
              Text(
                incident.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            Text(_formatDate(incident.occurredAt)),
          ],
        ),
        trailing: _AttachmentCount(count: incident.attachments?.length ?? 0),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}

class _AttachmentCount extends StatelessWidget {
  const _AttachmentCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Chip(label: Text('$count file${count == 1 ? '' : 's'}'));
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(error),
    );
  }
}
