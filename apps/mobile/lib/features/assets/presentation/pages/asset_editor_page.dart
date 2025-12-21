import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/assets_provider.dart';

class AssetEditorPage extends ConsumerStatefulWidget {
  const AssetEditorPage({this.existing, super.key});

  final Equipment? existing;

  @override
  ConsumerState<AssetEditorPage> createState() => _AssetEditorPageState();
}

class _AssetEditorPageState extends ConsumerState<AssetEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _serialController = TextEditingController();
  final _rfidController = TextEditingController();
  final _locationController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _modelController = TextEditingController();
  final _assignedToController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _purchaseDate;
  DateTime? _nextMaintenanceDate;
  String? _inspectionCadence;
  DateTime? _lastInspectionAt;
  DateTime? _nextInspectionAt;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _categoryController.text = existing.category ?? '';
      _serialController.text = existing.serialNumber ?? '';
      _rfidController.text = existing.rfidTag ?? '';
      _locationController.text = existing.currentLocation ?? '';
      _manufacturerController.text = existing.manufacturer ?? '';
      _modelController.text = existing.modelNumber ?? '';
      _assignedToController.text = existing.assignedTo ?? '';
      _contactNameController.text = existing.contactName ?? '';
      _contactEmailController.text = existing.contactEmail ?? '';
      _contactPhoneController.text = existing.contactPhone ?? '';
      _descriptionController.text = existing.description ?? '';
      _purchaseDate = existing.purchaseDate;
      _nextMaintenanceDate = existing.nextMaintenanceDate;
      _inspectionCadence = existing.inspectionCadence;
      _lastInspectionAt = existing.lastInspectionAt;
      _nextInspectionAt = existing.nextInspectionAt;
      _isActive = existing.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _serialController.dispose();
    _rfidController.dispose();
    _locationController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _assignedToController.dispose();
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Asset' : 'New Asset')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Asset name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Asset name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serialController,
                decoration: const InputDecoration(
                  labelText: 'Serial number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rfidController,
                decoration: const InputDecoration(
                  labelText: 'RFID tag',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Current location',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _assignedToController,
                decoration: const InputDecoration(
                  labelText: 'Assigned to',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactNameController,
                decoration: const InputDecoration(
                  labelText: 'Contact name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactEmailController,
                decoration: const InputDecoration(
                  labelText: 'Contact email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Contact phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _manufacturerController,
                decoration: const InputDecoration(
                  labelText: 'Manufacturer',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _purchaseDate == null
                      ? 'Purchase date not set'
                      : 'Purchased ${_formatDate(_purchaseDate!)}',
                ),
                trailing: TextButton(
                  onPressed: () => _pickDate((date) {
                    setState(() => _purchaseDate = date);
                  }),
                  child: const Text('Select'),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey(_inspectionCadence),
                initialValue: _inspectionCadence,
                decoration: const InputDecoration(
                  labelText: 'Inspection cadence',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('No schedule')),
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                ],
                onChanged: (value) {
                  setState(() {
                    _inspectionCadence = value;
                    _nextInspectionAt =
                        _computeNextInspection(value, _lastInspectionAt);
                  });
                },
              ),
              if (_nextInspectionAt != null) const SizedBox(height: 8),
              if (_nextInspectionAt != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fact_check),
                  title: Text('Next inspection ${_formatDate(_nextInspectionAt!)}'),
                  subtitle: _lastInspectionAt == null
                      ? const Text('No inspections recorded yet')
                      : Text('Last inspection ${_formatDate(_lastInspectionAt!)}'),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.build),
                title: Text(
                  _nextMaintenanceDate == null
                      ? 'Next maintenance not set'
                      : 'Maintenance due ${_formatDate(_nextMaintenanceDate!)}',
                ),
                trailing: TextButton(
                  onPressed: () => _pickDate((date) {
                    setState(() => _nextMaintenanceDate = date);
                  }),
                  child: const Text('Select'),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active asset'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save asset'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_inspectionCadence != null && _nextInspectionAt == null) {
        _nextInspectionAt =
            _computeNextInspection(_inspectionCadence, _lastInspectionAt);
      }
      final repo = ref.read(assetsRepositoryProvider);
      final existing = widget.existing;
      final asset = Equipment(
        id: existing?.id ?? '',
        name: _nameController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        serialNumber: _serialController.text.trim().isEmpty
            ? null
            : _serialController.text.trim(),
        rfidTag: _rfidController.text.trim().isEmpty
            ? null
            : _rfidController.text.trim(),
        currentLocation: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        assignedTo: _assignedToController.text.trim().isEmpty
            ? null
            : _assignedToController.text.trim(),
        contactName: _contactNameController.text.trim().isEmpty
            ? null
            : _contactNameController.text.trim(),
        contactEmail: _contactEmailController.text.trim().isEmpty
            ? null
            : _contactEmailController.text.trim(),
        contactPhone: _contactPhoneController.text.trim().isEmpty
            ? null
            : _contactPhoneController.text.trim(),
        manufacturer: _manufacturerController.text.trim().isEmpty
            ? null
            : _manufacturerController.text.trim(),
        modelNumber: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        purchaseDate: _purchaseDate,
        nextMaintenanceDate: _nextMaintenanceDate,
        inspectionCadence: _inspectionCadence,
        lastInspectionAt: _lastInspectionAt,
        nextInspectionAt: _nextInspectionAt,
        isActive: _isActive,
        createdAt: existing?.createdAt ?? DateTime.now(),
        metadata: existing?.metadata,
      );
      final saved = existing == null
          ? await repo.createEquipment(asset)
          : await repo.updateEquipment(asset);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(ValueChanged<DateTime> onSelected) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  DateTime? _computeNextInspection(String? cadence, DateTime? base) {
    if (cadence == null || cadence.isEmpty) return null;
    final origin = base ?? DateTime.now();
    switch (cadence) {
      case 'daily':
        return origin.add(const Duration(days: 1));
      case 'weekly':
        return origin.add(const Duration(days: 7));
      case 'quarterly':
        return origin.add(const Duration(days: 90));
      default:
        return null;
    }
  }
}
