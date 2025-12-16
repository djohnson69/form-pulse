import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart' as shared;

import '../../data/dashboard_provider.dart';
import '../../data/pending_queue.dart';
import '../../data/user_profile_provider.dart';

const _supabaseBucket =
    String.fromEnvironment('SUPABASE_BUCKET', defaultValue: 'formbridge-attachments');

/// Dynamic form fill experience with camera, QR scan, and document upload.
class FormFillPage extends ConsumerStatefulWidget {
  const FormFillPage({
    required this.form,
    this.prefillData,
    this.preferredField,
    super.key,
  });

  final shared.FormDefinition form;
  final Map<String, dynamic>? prefillData;
  final String? preferredField;

  @override
  ConsumerState<FormFillPage> createState() => _FormFillPageState();
}

class _FormFillPageState extends ConsumerState<FormFillPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _values = {};
  final List<_AttachmentItem> _attachments = [];
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, dynamic>? _locationData;
  bool _submitting = false;
  String? _orgId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = await ref.read(userProfileProvider.future);
      if (!mounted) return;
      setState(() => _orgId = profile.orgId);
    });
    if (widget.prefillData != null) {
      widget.prefillData!.forEach((key, value) {
        _values[key] = value;
        _controllerFor(key).text = value?.toString() ?? '';
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.form.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Submit',
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.form.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ...widget.form.fields.map(_buildField),
              const SizedBox(height: 12),
              _buildAttachmentsCard(context),
              const SizedBox(height: 12),
              _buildLocationCard(context),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_submitting ? 'Submitting...' : 'Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(shared.FormField field) {
    switch (field.type) {
      case shared.FormFieldType.text:
      case shared.FormFieldType.email:
      case shared.FormFieldType.phone:
      case shared.FormFieldType.number:
        return _buildTextField(field);
      case shared.FormFieldType.textarea:
        return _buildTextField(field, maxLines: 4);
      case shared.FormFieldType.dropdown:
        return _buildDropdown(field);
      case shared.FormFieldType.checkbox:
        return _buildCheckboxGroup(field);
      case shared.FormFieldType.radio:
        return _buildRadioGroup(field);
      case shared.FormFieldType.toggle:
        return _buildToggle(field);
      case shared.FormFieldType.photo:
        return _buildPhotoPrompt(field);
      case shared.FormFieldType.barcode:
      case shared.FormFieldType.rfid:
        return _buildBarcodeField(field);
      case shared.FormFieldType.file:
      case shared.FormFieldType.files:
        return _buildDocumentPrompt(field);
      case shared.FormFieldType.date:
      case shared.FormFieldType.time:
      case shared.FormFieldType.datetime:
        return _buildDateTimeField(field);
      case shared.FormFieldType.location:
        return _buildLocationPrompt(field);
      case shared.FormFieldType.repeater:
        return _buildRepeater(field);
      case shared.FormFieldType.table:
        return _buildTable(field);
      case shared.FormFieldType.computed:
        return _buildComputed(field);
      case shared.FormFieldType.signature:
        return _buildTextField(
          field,
          hint: 'Type your name as a digital signature',
        );
      case shared.FormFieldType.video:
        return _buildVideoPrompt(field);
      case shared.FormFieldType.sectionHeader:
      case shared.FormFieldType.infoText:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            field.label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        );
    }
  }

  Widget _buildTextField(
    shared.FormField field, {
    int maxLines = 1,
    String? hint,
  }) {
    final controller = _controllerFor(field.id);
    final preferred = widget.preferredField == field.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: _keyboardFor(field.type),
        decoration: InputDecoration(
          labelText: field.label,
          hintText: hint ?? field.placeholder,
          prefixIcon: _iconFor(field.type) != null
              ? Icon(_iconFor(field.type))
              : null,
        ),
        autofocus: preferred,
        validator: (value) {
          if (field.isRequired && (value == null || value.isEmpty)) {
            return 'Required';
          }
          if (field.type == shared.FormFieldType.email &&
              value != null &&
              value.isNotEmpty &&
              !value.contains('@')) {
            return 'Enter a valid email';
          }
          return null;
        },
        onChanged: (value) {
          setState(() {
            _values[field.id] = value;
          });
        },
        onSaved: (value) => _values[field.id] = value ?? '',
      ),
    );
  }

  Widget _buildDropdown(shared.FormField field) {
    final options = field.options ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _values[field.id] as String?,
        items: options.map((opt) {
          return DropdownMenuItem(value: opt, child: Text(opt));
        }).toList(),
        decoration: InputDecoration(labelText: field.label),
        validator: (value) {
          if (field.isRequired && (value == null || value.isEmpty)) {
            return 'Required';
          }
          return null;
        },
        onChanged: (val) => setState(() => _values[field.id] = val),
      ),
    );
  }

  Widget _buildCheckboxGroup(shared.FormField field) {
    final options = field.options ?? [];
    final selected = Set<String>.from(_values[field.id] as List? ?? []);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FormField<List<String>>(
        initialValue: selected.toList(),
        validator: (value) {
          if (field.isRequired && (value == null || value.isEmpty)) {
            return 'Pick at least one option';
          }
          return null;
        },
        builder: (state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(field.label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((option) {
                  final isSelected = selected.contains(option);
                  return FilterChip(
                    label: Text(option),
                    selected: isSelected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          selected.add(option);
                        } else {
                          selected.remove(option);
                        }
                        _values[field.id] = selected.toList();
                        state.didChange(selected.toList());
                      });
                    },
                  );
                }).toList(),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    state.errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRadioGroup(shared.FormField field) {
    final options = field.options ?? [];
    final current = _values[field.id] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FormField<String>(
        initialValue: current,
        validator: (value) {
          if (field.isRequired && (value == null || value.isEmpty)) {
            return 'Select an option';
          }
          return null;
        },
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label, style: Theme.of(context).textTheme.titleSmall),
            ...options.map((opt) {
              final isSelected = state.value == opt;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(opt),
                onTap: () {
                  state.didChange(opt);
                  setState(() => _values[field.id] = opt);
                },
                dense: true,
              );
            }),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  state.errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(shared.FormField field) {
    final current = _values[field.id] as bool? ?? false;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(field.label),
      value: current,
      onChanged: (value) => setState(() => _values[field.id] = value),
    );
  }

  Widget _buildBarcodeField(shared.FormField field) {
    final controller = _controllerFor(field.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: field.label,
          prefixIcon: const Icon(Icons.qr_code_2),
          suffixIcon: IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _scanBarcode(field.id, controller),
          ),
        ),
        validator: (value) {
          if (field.isRequired && (value == null || value.isEmpty)) {
            return 'Required';
          }
          return null;
        },
        onChanged: (value) {
          setState(() {
            _values[field.id] = value;
          });
        },
      ),
    );
  }

  Widget _buildPhotoPrompt(shared.FormField field) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_camera),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    field.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  tooltip: 'Capture photo',
                  onPressed: () => _addPhoto(fromCamera: true),
                ),
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  tooltip: 'Pick from gallery',
                  onPressed: () => _addPhoto(fromCamera: false),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Attach site photos, evidence, or signatures.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPrompt(shared.FormField field) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.videocam_outlined),
        title: Text(field.label),
        subtitle: const Text('Record a short clip for context'),
        trailing: IconButton(
          icon: const Icon(Icons.play_circle_outline),
          onPressed: () => _addVideo(),
        ),
      ),
    );
  }

  Widget _buildDocumentPrompt(shared.FormField field) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.upload_file),
        title: Text(field.label),
        subtitle: const Text('Upload scans, PDFs, or manuals'),
        trailing: IconButton(
          icon: const Icon(Icons.attach_file),
          onPressed: _addDocument,
        ),
      ),
    );
  }

  Widget _buildDateTimeField(shared.FormField field) {
    final controller = _controllerFor(field.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: field.label,
          suffixIcon: const Icon(Icons.event),
        ),
        validator: (value) {
          if (field.isRequired && (value == null || value.isEmpty)) {
            return 'Required';
          }
          return null;
        },
        onTap: () async {
          final pickerContext = context;
          FocusScope.of(pickerContext).requestFocus(FocusNode());
          DateTime? selectedDate;
          TimeOfDay? selectedTime;

          if (field.type == shared.FormFieldType.date ||
              field.type == shared.FormFieldType.datetime) {
            selectedDate = await showDatePicker(
              context: pickerContext,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (!pickerContext.mounted) return;
          }

          if (field.type == shared.FormFieldType.time ||
              field.type == shared.FormFieldType.datetime) {
            selectedTime = await showTimePicker(
              context: pickerContext,
              initialTime: TimeOfDay.now(),
            );
            if (!pickerContext.mounted) return;
          }

          if (selectedDate == null && field.type != shared.FormFieldType.time) {
            return;
          }

          final now = DateTime.now();
          final date = selectedDate ?? DateTime(now.year, now.month, now.day);
          final timeOfDay = selectedTime ?? TimeOfDay.now();
          final dt = DateTime(
            date.year,
            date.month,
            date.day,
            timeOfDay.hour,
            timeOfDay.minute,
          );

          final formatted = field.type == shared.FormFieldType.time
              ? MaterialLocalizations.of(pickerContext).formatTimeOfDay(timeOfDay)
              : dt.toIso8601String();
          controller.text = formatted;
          _values[field.id] = formatted;
        },
      ),
    );
  }

  Widget _buildLocationPrompt(shared.FormField field) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.my_location),
        title: Text(field.label),
        subtitle: Text(
          _locationData == null
              ? 'Attach GPS position'
              : 'Attached • ${_locationData?['latitude']}, ${_locationData?['longitude']}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_location_alt_outlined),
          onPressed: () => _captureLocation(field.id),
        ),
      ),
    );
  }

  Widget _buildAttachmentsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_special),
                const SizedBox(width: 8),
                Text(
                  'Attachments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_attachments.isEmpty)
              const Text('No attachments yet. Add photos, scans, or videos.')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _attachments.map((att) {
                  return Chip(
                    label: Text(att.label),
                    avatar: Icon(_attachmentIcon(att.type)),
                    deleteIcon: const Icon(Icons.close),
                    onDeleted: () {
                      setState(() => _attachments.remove(att));
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                  onPressed: () => _addPhoto(fromCamera: true),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Gallery'),
                  onPressed: () => _addPhoto(fromCamera: false),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload'),
                  onPressed: _addDocument,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.public),
        title: const Text('GPS & Context'),
        subtitle: Text(
          _locationData == null
              ? 'Attach current coordinates for audit trail'
              : 'Attached • ${_locationData?['latitude']}, ${_locationData?['longitude']}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_location_alt),
          onPressed: _captureLocation,
        ),
      ),
    );
  }

  Widget _buildRepeater(shared.FormField field) {
    final items = List<Map<String, dynamic>>.from(
      (_values[field.id] as List?) ?? [],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  field.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add row',
                  onPressed: () {
                    setState(() {
                      items.add({});
                      _values[field.id] = items;
                    });
                  },
                ),
              ],
            ),
            if (items.isEmpty)
              const Text('No rows yet. Tap + to add.')
            else
              ...items.asMap().entries.map((entry) {
                final idx = entry.key;
                final data = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Row ${idx + 1}'),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() {
                                items.removeAt(idx);
                                _values[field.id] = items;
                              });
                            },
                          ),
                        ],
                      ),
                      ...?field.children?.map(
                        (child) => _buildInlineField(
                          parentId: field.id,
                          rowIndex: idx,
                          child: child,
                          initial: data[child.id],
                          onChanged: (val) {
                            data[child.id] = val;
                            _values[field.id] = items;
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(shared.FormField field) {
    final rows = List<Map<String, dynamic>>.from(
      (_values[field.id] as List?) ?? [],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  field.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add row',
                  onPressed: () {
                    setState(() {
                      rows.add({});
                      _values[field.id] = rows;
                    });
                  },
                ),
              ],
            ),
            if (rows.isEmpty)
              const Text('No rows yet. Tap + to add.')
            else
              Column(
                children: rows.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final data = entry.value;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Text('Row ${idx + 1}'),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() {
                                rows.removeAt(idx);
                                _values[field.id] = rows;
                              });
                            },
                          ),
                        ],
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              field.children
                                  ?.map(
                                    (child) => SizedBox(
                                      width: 180,
                                      child: _buildInlineField(
                                        parentId: field.id,
                                        rowIndex: idx,
                                        child: child,
                                        initial: data[child.id],
                                        onChanged: (val) {
                                          data[child.id] = val;
                                          _values[field.id] = rows;
                                        },
                                      ),
                                    ),
                                  )
                                  .toList() ??
                              [],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildComputed(shared.FormField field) {
    final value = _computeCalculatedValue(field);
    _values[field.id] = value;
    final controller = _controllerFor('computed-${field.id}')
      ..text = value?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.helpText ?? field.placeholder,
        ),
        controller: controller,
      ),
    );
  }

  Widget _buildInlineField({
    required String parentId,
    required int rowIndex,
    required shared.FormField child,
    required void Function(dynamic) onChanged,
    dynamic initial,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 8),
      child: TextFormField(
        key: ValueKey('$parentId-$rowIndex-${child.id}'),
        initialValue: initial?.toString() ?? '',
        decoration: InputDecoration(labelText: child.label),
        onChanged: (val) {
          setState(() {
            onChanged(val);
          });
        },
      ),
    );
  }

  Future<void> _addPhoto({required bool fromCamera}) async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _attachments.add(
          _AttachmentItem(
            id: 'photo-${DateTime.now().microsecondsSinceEpoch}',
            type: 'photo',
            label: file.name,
            bytes: bytes,
            path: file.path,
            metadata: {'source': fromCamera ? 'camera' : 'gallery'},
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add photo: $e')));
    }
  }

  Future<void> _addVideo() async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickVideo(source: ImageSource.camera);
      if (file == null) return;
      setState(() {
        _attachments.add(
          _AttachmentItem(
            id: 'video-${DateTime.now().microsecondsSinceEpoch}',
            type: 'video',
            label: file.name,
            path: file.path,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to record video: $e')));
    }
  }

  Future<void> _addDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      setState(() {
        _attachments.add(
          _AttachmentItem(
            id: 'file-${DateTime.now().microsecondsSinceEpoch}',
            type: 'file',
            label: file.name,
            bytes: file.bytes,
            path: file.path,
            metadata: {'size': file.size, 'extension': file.extension},
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _captureLocation([String? fieldId]) async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _locationData = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': DateTime.now().toIso8601String(),
        };
        if (fieldId != null) {
          _values[fieldId] = _locationData;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
    }
  }

  Future<void> _scanBarcode(
    String fieldId,
    TextEditingController controller,
  ) async {
    try {
      final result = await BarcodeScanner.scan();
      if (result.rawContent.isEmpty) return;
      setState(() {
        controller.text = result.rawContent;
        _values[fieldId] = result.rawContent;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    }
  }

  TextEditingController _controllerFor(String id) {
    return _controllers.putIfAbsent(id, () => TextEditingController());
  }

  IconData? _iconFor(shared.FormFieldType type) {
    switch (type) {
      case shared.FormFieldType.email:
        return Icons.email_outlined;
      case shared.FormFieldType.phone:
        return Icons.phone_android;
      case shared.FormFieldType.number:
        return Icons.numbers;
      default:
        return null;
    }
  }

  TextInputType? _keyboardFor(shared.FormFieldType type) {
    switch (type) {
      case shared.FormFieldType.email:
        return TextInputType.emailAddress;
      case shared.FormFieldType.phone:
        return TextInputType.phone;
      case shared.FormFieldType.number:
        return TextInputType.number;
      default:
        return null;
    }
  }

  IconData _attachmentIcon(String type) {
    switch (type) {
      case 'photo':
        return Icons.photo;
      case 'video':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }

  num? _computeCalculatedValue(shared.FormField field) {
    final expr = field.calculations?['expression'] as String?;
    if (expr == null) return null;
    // Very lightweight evaluator for expressions like "onHand - par".
    final parts = expr.split(RegExp(r'\s+'));
    if (parts.length != 3) return null;
    final left = _lookupNumeric(parts[0]);
    final op = parts[1];
    final right = _lookupNumeric(parts[2]);
    if (left == null || right == null) return null;
    switch (op) {
      case '+':
        return left + right;
      case '-':
        return left - right;
      case '*':
        return left * right;
      case '/':
        return right == 0 ? null : left / right;
    }
    return null;
  }

  num? _lookupNumeric(String key) {
    final value = _values[key];
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      return parsed;
    }
    return null;
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null) return;
    if (!formState.validate()) return;
    formState.save();

    setState(() => _submitting = true);

    final repo = ref.read(dashboardRepositoryProvider);
    final uploaded = await _uploadAttachments(_attachments);
    final attachmentJson = uploaded.map((a) => a.toJson()).toList();
    final currentUser = _supabase.auth.currentUser;
    final submittedBy = currentUser?.email ?? currentUser?.id ?? 'anonymous';

    try {
      await repo.createSubmission(
        formId: widget.form.id,
        data: _values,
        submittedBy: submittedBy,
        attachments: attachmentJson,
        location: _locationData,
      );
      if (!mounted) return;
      ref.invalidate(dashboardDataProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Submission recorded')));
      Navigator.pop(context);
    } catch (e) {
      // Persist offline queue on failure.
      await PendingSubmissionQueue(
        repo,
        _supabase,
        bucketName: _supabaseBucket,
        orgId: _orgId,
      ).add(
        PendingSubmission(
          formId: widget.form.id,
          data: _values,
          submittedBy: submittedBy,
          attachments: _attachments.map((a) => a.toQueueJson()).toList(),
          location: _locationData,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<List<_AttachmentItem>> _uploadAttachments(
    List<_AttachmentItem> items,
  ) async {
    final results = <_AttachmentItem>[];
    for (final item in items) {
      if (item.url != null || item.bytes == null) {
        results.add(item);
        continue;
      }
      try {
        final prefix = _orgId != null ? 'org-$_orgId' : 'public';
        final path =
            '$prefix/submissions/${DateTime.now().microsecondsSinceEpoch}_${item.label}';
      await _supabase.storage
          .from(_supabaseBucket)
          .uploadBinary(path, item.bytes!, fileOptions: const FileOptions(upsert: true));
      final publicUrl = _supabase.storage.from(_supabaseBucket).getPublicUrl(path);
      if (!mounted) return results;
      results.add(item.copyWith(url: publicUrl, hash: _hashBytes(item.bytes!)));
    } catch (e) {
      // Keep original item on failure to avoid data loss.
      results.add(item);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed for ${item.label}: $e')),
        );
      }
    }
    return results;
  }

  String _hashBytes(Uint8List bytes) =>
      sha256.convert(bytes).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

class _AttachmentItem {
  _AttachmentItem({
    required this.id,
    required this.type,
    required this.label,
    this.bytes,
    this.path,
    this.metadata,
    this.url,
    this.hash,
  });

  final String id;
  final String type; // photo, file, video
  final String label;
  final Uint8List? bytes;
  final String? path;
  final Map<String, dynamic>? metadata;
  final String? url;
  final String? hash;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'url': url ?? path ?? label,
      'filename': label,
      'mimeType': type == 'photo'
          ? 'image/jpeg'
          : type == 'video'
          ? 'video/mp4'
          : 'application/octet-stream',
      'capturedAt': DateTime.now().toIso8601String(),
      'metadata': {
        ...?metadata,
        if (hash != null) 'hash': hash,
      },
    };
  }

  Map<String, dynamic> toQueueJson() {
    return {
      'id': id,
      'type': type,
      'filename': label,
      'path': path,
      'url': url,
      'hash': hash,
      'metadata': metadata,
      if (bytes != null) 'bytes': base64Encode(bytes!),
    };
  }

  _AttachmentItem copyWith({
    String? url,
    String? hash,
  }) {
    return _AttachmentItem(
      id: id,
      type: type,
      label: label,
      bytes: bytes,
      path: path,
      metadata: metadata,
      url: url ?? this.url,
      hash: hash ?? this.hash,
    );
  }
}
