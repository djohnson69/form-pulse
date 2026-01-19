import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/assets_provider.dart';

class InspectionScheduleSheet extends ConsumerStatefulWidget {
  const InspectionScheduleSheet({super.key, required this.assets});

  final List<Equipment> assets;

  @override
  ConsumerState<InspectionScheduleSheet> createState() =>
      _InspectionScheduleSheetState();
}

class _InspectionScheduleSheetState
    extends ConsumerState<InspectionScheduleSheet> {
  final _inspectorController = TextEditingController();
  final _typeController = TextEditingController();
  String? _selectedAssetId;
  String _frequency = 'daily';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.assets.isNotEmpty) {
      _selectedAssetId = widget.assets.first.id;
      _loadAssetFields(widget.assets.first);
    }
  }

  @override
  void dispose() {
    _inspectorController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Schedule Inspection',
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
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedAssetId,
              decoration: const InputDecoration(
                labelText: 'Select Asset',
                border: OutlineInputBorder(),
              ),
              items: widget.assets
                  .map(
                    (asset) => DropdownMenuItem(
                      value: asset.id,
                      child: Text(asset.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                final asset =
                    widget.assets.firstWhere((item) => item.id == value);
                setState(() {
                  _selectedAssetId = value;
                  _loadAssetFields(asset);
                });
              },
            ),
            const SizedBox(height: 16),
            _SectionLabel(label: 'Inspection Frequency'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FrequencyChip(
                  label: 'Daily',
                  selected: _frequency == 'daily',
                  onTap: () => setState(() => _frequency = 'daily'),
                ),
                _FrequencyChip(
                  label: 'Weekly',
                  selected: _frequency == 'weekly',
                  onTap: () => setState(() => _frequency = 'weekly'),
                ),
                _FrequencyChip(
                  label: 'Monthly',
                  selected: _frequency == 'monthly',
                  onTap: () => setState(() => _frequency = 'monthly'),
                ),
                _FrequencyChip(
                  label: 'Quarterly',
                  selected: _frequency == 'quarterly',
                  onTap: () => setState(() => _frequency = 'quarterly'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _inspectorController,
              decoration: const InputDecoration(
                labelText: 'Assigned Inspector',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _typeController,
              decoration: const InputDecoration(
                labelText: 'Inspection Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _saveSchedule,
                    child: Text(_saving ? 'Saving...' : 'Schedule Inspection'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _loadAssetFields(Equipment asset) {
    final metadata = asset.metadata ?? const <String, dynamic>{};
    _frequency = asset.inspectionCadence ?? _frequency;
    _inspectorController.text =
        (metadata['inspectionInspector'] ?? '').toString();
    _typeController.text = (metadata['inspectionType'] ?? '').toString();
  }

  Future<void> _saveSchedule() async {
    if (_selectedAssetId == null) return;
    final asset =
        widget.assets.firstWhere((item) => item.id == _selectedAssetId);
    final metadata = Map<String, dynamic>.from(asset.metadata ?? {});
    final inspector = _inspectorController.text.trim();
    final inspectionType = _typeController.text.trim();
    if (inspector.isEmpty) {
      metadata.remove('inspectionInspector');
    } else {
      metadata['inspectionInspector'] = inspector;
    }
    if (inspectionType.isEmpty) {
      metadata.remove('inspectionType');
    } else {
      metadata['inspectionType'] = inspectionType;
    }
    metadata['inspectionFrequency'] = _frequency;
    final nextInspectionAt = _computeNextInspection(_frequency);
    final updated = Equipment(
      id: asset.id,
      orgId: asset.orgId,
      name: asset.name,
      description: asset.description,
      category: asset.category,
      manufacturer: asset.manufacturer,
      modelNumber: asset.modelNumber,
      serialNumber: asset.serialNumber,
      purchaseDate: asset.purchaseDate,
      assignedTo: asset.assignedTo,
      currentLocation: asset.currentLocation,
      gpsLocation: asset.gpsLocation,
      contactName: asset.contactName,
      contactEmail: asset.contactEmail,
      contactPhone: asset.contactPhone,
      rfidTag: asset.rfidTag,
      lastMaintenanceDate: asset.lastMaintenanceDate,
      nextMaintenanceDate: asset.nextMaintenanceDate,
      inspectionCadence: _frequency,
      lastInspectionAt: asset.lastInspectionAt,
      nextInspectionAt: nextInspectionAt,
      isActive: asset.isActive,
      companyId: asset.companyId,
      createdAt: asset.createdAt,
      updatedAt: asset.updatedAt,
      metadata: metadata,
    );

    setState(() => _saving = true);
    final repo = ref.read(assetsRepositoryProvider);
    try {
      await repo.updateEquipment(updated);
      ref.invalidate(equipmentProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection scheduled successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Schedule failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  DateTime _computeNextInspection(String cadence) {
    final now = DateTime.now();
    switch (cadence) {
      case 'weekly':
        return now.add(const Duration(days: 7));
      case 'monthly':
        return now.add(const Duration(days: 30));
      case 'quarterly':
        return now.add(const Duration(days: 90));
      case 'daily':
      default:
        return now.add(const Duration(days: 1));
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  const _FrequencyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
