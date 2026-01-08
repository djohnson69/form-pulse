import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart' as shared;

import '../../../../core/ai/ai_assist_sheet.dart';
import '../../data/dashboard_provider.dart';
import '../../data/pending_queue.dart';
import '../../data/user_profile_provider.dart';
import '../../../../core/utils/automation_scheduler.dart';
import '../../../../core/utils/file_bytes_loader.dart';
import '../../../../core/utils/submission_utils.dart';
import '../../../ops/data/ops_provider.dart';
import 'photo_annotator_page.dart';
import 'signature_pad_page.dart';

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
  final AudioRecorder _audioRecorder = AudioRecorder();
  final SpeechToText _speechToText = SpeechToText();
  Map<String, dynamic>? _locationData;
  bool _submitting = false;
  bool _isSubmitted = false;
  bool _isRecordingAudio = false;
  bool _isDictating = false;
  String? _dictationFieldId;
  String? _pendingAudioLabel;
  String? _orgId;
  String _accessLevel = 'org';

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
    _audioRecorder.dispose();
    _speechToText.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return _buildSuccessView(context);
    }

    final theme = Theme.of(context);
    final border = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    final description = widget.form.description.trim();
    final fields = widget.form.fields;
    final basicFields = fields.where(_isBasicField).toList();
    final advancedFields = fields.where(_isAdvancedField).toList();
    final otherFields = fields
        .where((field) => !_isBasicField(field) && !_isAdvancedField(field))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextButton.icon(
                onPressed:
                    _submitting ? null : () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Forms'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 12),
              Container(
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
                    Text(
                      widget.form.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (basicFields.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _sectionTitle(context, 'Basic Information'),
                      const SizedBox(height: 12),
                      ...basicFields.map(_buildField),
                    ],
                    if (otherFields.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Divider(color: border),
                      const SizedBox(height: 12),
                      _sectionTitle(context, 'Additional Details'),
                      const SizedBox(height: 12),
                      ...otherFields.map(_buildField),
                    ],
                    const SizedBox(height: 8),
                    Divider(color: border),
                    const SizedBox(height: 12),
                    _sectionTitle(
                      context,
                      'Inspection Details (Advanced Fields)',
                    ),
                    const SizedBox(height: 12),
                    ...advancedFields.map(_buildField),
                    const SizedBox(height: 12),
                    _buildAttachmentsCard(context),
                    const SizedBox(height: 12),
                    _buildLocationCard(context),
                    const SizedBox(height: 12),
                    _buildAccessLevelCard(context),
                    const SizedBox(height: 16),
                    Divider(color: border),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label:
                              Text(_submitting ? 'Submitting...' : 'Submit Form'),
                        ),
                        OutlinedButton(
                          onPressed: _submitting
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    final title = widget.form.title;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFF064E3B)
                            : const Color(0xFFD1FAE5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 40,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Form Submitted Successfully!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your $title form has been submitted and saved.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Redirecting you back to forms...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  bool _isBasicField(shared.FormField field) {
    switch (field.type) {
      case shared.FormFieldType.text:
      case shared.FormFieldType.textarea:
      case shared.FormFieldType.email:
      case shared.FormFieldType.phone:
      case shared.FormFieldType.number:
      case shared.FormFieldType.date:
      case shared.FormFieldType.time:
      case shared.FormFieldType.datetime:
      case shared.FormFieldType.dropdown:
      case shared.FormFieldType.checkbox:
      case shared.FormFieldType.radio:
      case shared.FormFieldType.toggle:
        return true;
      case shared.FormFieldType.file:
      case shared.FormFieldType.files:
      case shared.FormFieldType.photo:
      case shared.FormFieldType.video:
      case shared.FormFieldType.audio:
      case shared.FormFieldType.voiceNote:
      case shared.FormFieldType.signature:
      case shared.FormFieldType.location:
      case shared.FormFieldType.barcode:
      case shared.FormFieldType.rfid:
      case shared.FormFieldType.repeater:
      case shared.FormFieldType.table:
      case shared.FormFieldType.computed:
      case shared.FormFieldType.sectionHeader:
      case shared.FormFieldType.infoText:
        return false;
    }
  }

  bool _isAdvancedField(shared.FormField field) {
    switch (field.type) {
      case shared.FormFieldType.file:
      case shared.FormFieldType.files:
      case shared.FormFieldType.photo:
      case shared.FormFieldType.video:
      case shared.FormFieldType.audio:
      case shared.FormFieldType.voiceNote:
      case shared.FormFieldType.signature:
      case shared.FormFieldType.location:
      case shared.FormFieldType.barcode:
      case shared.FormFieldType.rfid:
      case shared.FormFieldType.repeater:
      case shared.FormFieldType.table:
      case shared.FormFieldType.computed:
        return true;
      case shared.FormFieldType.text:
      case shared.FormFieldType.textarea:
      case shared.FormFieldType.email:
      case shared.FormFieldType.phone:
      case shared.FormFieldType.number:
      case shared.FormFieldType.date:
      case shared.FormFieldType.time:
      case shared.FormFieldType.datetime:
      case shared.FormFieldType.dropdown:
      case shared.FormFieldType.checkbox:
      case shared.FormFieldType.radio:
      case shared.FormFieldType.toggle:
      case shared.FormFieldType.sectionHeader:
      case shared.FormFieldType.infoText:
        return false;
    }
  }

  Widget _buildField(shared.FormField field) {
    switch (field.type) {
      case shared.FormFieldType.text:
        return _buildTextField(field, enableAi: true);
      case shared.FormFieldType.email:
      case shared.FormFieldType.phone:
      case shared.FormFieldType.number:
        return _buildTextField(field);
      case shared.FormFieldType.textarea:
        return _buildTextField(field, maxLines: 4, enableAi: true);
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
        return _buildSignatureField(field);
      case shared.FormFieldType.video:
        return _buildVideoPrompt(field);
      case shared.FormFieldType.audio:
        return _buildAudioPrompt(field);
      case shared.FormFieldType.voiceNote:
        return _buildVoiceNoteField(field);
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
    bool enableAi = false,
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
          suffixIcon: enableAi
              ? IconButton(
                  tooltip: 'AI assist',
                  icon: const Icon(Icons.auto_awesome),
                  onPressed: () => _openAiAssistForField(field),
                )
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

  Widget _buildAudioPrompt(shared.FormField field) {
    final isRecording = _isRecordingAudio;
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.mic_none,
          color: isRecording ? Colors.red : null,
        ),
        title: Text(field.label),
        subtitle: Text(
          isRecording ? 'Recording... tap to stop' : 'Capture an audio note',
        ),
        trailing: IconButton(
          icon: Icon(isRecording ? Icons.stop_circle : Icons.mic),
          onPressed:
              _submitting ? null : () => _toggleAudioRecording(label: field.label),
        ),
      ),
    );
  }

  Widget _buildVoiceNoteField(shared.FormField field) {
    final controller = _controllerFor(field.id);
    final dictating = _isDictating && _dictationFieldId == field.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.placeholder ?? 'Tap the mic to dictate',
          suffixIcon: IconButton(
            icon: Icon(dictating ? Icons.stop_circle : Icons.mic),
            onPressed: _submitting ? null : () => _toggleDictation(field.id),
          ),
        ),
        validator: (value) {
          if (field.isRequired && (value == null || value.isEmpty)) {
            return 'Required';
          }
          return null;
        },
        onChanged: (value) => setState(() => _values[field.id] = value),
        onSaved: (value) => _values[field.id] = value ?? '',
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
              Column(
                children: _attachments.map((att) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(_attachmentIcon(att.type)),
                      title: Text(att.label),
                      subtitle: Text(att.type),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (att.type == 'photo')
                            IconButton(
                              tooltip: 'Annotate',
                              icon: const Icon(Icons.edit),
                              onPressed: () => _annotatePhoto(att),
                            ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() => _attachments.remove(att));
                            },
                          ),
                        ],
                      ),
                    ),
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
                  icon: Icon(
                    _isRecordingAudio ? Icons.stop_circle : Icons.mic,
                  ),
                  label: Text(_isRecordingAudio ? 'Stop' : 'Audio'),
                  onPressed:
                      _submitting ? null : () => _toggleAudioRecording(),
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

  Widget _buildAccessLevelCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Access level',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Controls who can view this record.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_accessLevel),
              initialValue: _accessLevel,
              decoration: const InputDecoration(
                labelText: 'Visibility',
                border: OutlineInputBorder(),
              ),
              items: submissionAccessLevelLabels.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _accessLevel = value);
              },
            ),
          ],
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

  Widget _buildSignatureField(shared.FormField field) {
    final attachment = _signatureAttachmentFor(field.id);
    final signedAt = attachment?.metadata?['signedAt'] as String?;
    final signerName = attachment?.metadata?['signerName'] as String?;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.border_color),
            title: Text(field.label),
            subtitle: Text(
              attachment == null
                  ? 'Capture signature'
                  : 'Signed${signedAt != null ? ' • $signedAt' : ''}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _submitting ? null : () => _captureSignature(field),
            ),
          ),
          if (signerName != null && signerName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Signer: $signerName'),
              ),
            ),
          if (attachment?.bytes != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Image.memory(
                attachment!.bytes!,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
    );
  }

  _AttachmentItem? _signatureAttachmentFor(String fieldId) {
    for (final att in _attachments) {
      if (att.type == 'signature' &&
          att.metadata?['signatureFieldId'] == fieldId) {
        return att;
      }
    }
    return null;
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

  Future<void> _captureSignature(shared.FormField field) async {
    final result = await Navigator.of(context).push<SignatureResult>(
      MaterialPageRoute(
        builder: (_) => SignaturePadPage(title: field.label),
      ),
    );
    if (result == null) return;
    final signedAt = DateTime.now().toIso8601String();
    final attachment = _AttachmentItem(
      id: 'signature-${DateTime.now().microsecondsSinceEpoch}',
      type: 'signature',
      label: result.name?.isNotEmpty == true
          ? 'Signature • ${result.name}'
          : 'Signature',
      bytes: result.bytes,
      metadata: {
        'signatureFieldId': field.id,
        'signedAt': signedAt,
        if (result.name != null) 'signerName': result.name,
      },
    );

    setState(() {
      final index = _attachments.indexWhere(
        (a) =>
            a.type == 'signature' &&
            a.metadata?['signatureFieldId'] == field.id,
      );
      if (index >= 0) {
        _attachments[index] = attachment;
      } else {
        _attachments.add(attachment);
      }
      _values[field.id] = {
        'signatureId': attachment.id,
        'signedAt': signedAt,
        if (result.name != null) 'signerName': result.name,
      };
    });
  }

  Future<void> _toggleAudioRecording({String? label}) async {
    if (_isRecordingAudio) {
      await _stopAudioRecording();
      return;
    }
    await _startAudioRecording(label: label);
  }

  Future<void> _startAudioRecording({String? label}) async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final safeLabel = (label ?? 'audio')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final fileName =
        '${safeLabel.isEmpty ? 'audio' : safeLabel}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final path = p.join(dir.path, fileName);

    _pendingAudioLabel = label ?? 'Audio note';
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    if (!mounted) return;
    setState(() => _isRecordingAudio = true);
  }

  Future<void> _stopAudioRecording() async {
    final path = await _audioRecorder.stop();
    if (!mounted) return;
    setState(() => _isRecordingAudio = false);

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio recording failed to save')),
      );
      return;
    }

    final label = _pendingAudioLabel ?? 'Audio note';
    _pendingAudioLabel = null;

    setState(() {
      _attachments.add(
        _AttachmentItem(
          id: 'audio-${DateTime.now().microsecondsSinceEpoch}',
          type: 'audio',
          label: label,
          path: path,
          metadata: {'source': label},
        ),
      );
    });
  }

  Future<void> _toggleDictation(String fieldId) async {
    if (_isDictating && _dictationFieldId == fieldId) {
      await _speechToText.stop();
      if (!mounted) return;
      setState(() {
        _isDictating = false;
        _dictationFieldId = null;
      });
      return;
    }

    if (_isDictating) {
      await _speechToText.stop();
    }

    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isDictating = false;
            _dictationFieldId = null;
          });
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isDictating = false;
          _dictationFieldId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dictation error: ${error.errorMsg}')),
        );
      },
    );

    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition unavailable')),
      );
      return;
    }

    setState(() {
      _isDictating = true;
      _dictationFieldId = fieldId;
    });

    _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        if (!mounted) return;
        final text = result.recognizedWords;
        setState(() {
          _controllerFor(fieldId).text = text;
          _values[fieldId] = text;
        });
      },
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

  Future<void> _annotatePhoto(_AttachmentItem item) async {
    final bytes = item.bytes ??
        (item.path != null ? await loadFileBytes(item.path!) : null);
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo data not available')),
      );
      return;
    }
    if (!mounted) return;
    final annotated = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => PhotoAnnotatorPage(
          imageBytes: bytes,
          title: 'Annotate ${item.label}',
        ),
      ),
    );
    if (!mounted) return;
    if (annotated == null) return;

    setState(() {
      final index = _attachments.indexOf(item);
      if (index == -1) return;
      _attachments[index] = _AttachmentItem(
        id: item.id,
        type: item.type,
        label: item.label,
        bytes: annotated,
        path: item.path,
        metadata: {
          ...?item.metadata,
          'annotated': true,
          'annotatedAt': DateTime.now().toIso8601String(),
        },
        url: null,
        hash: null,
      );
    });
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
      case 'audio':
        return Icons.mic_none;
      case 'signature':
        return Icons.border_color;
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

  Future<void> _openAiAssistForField(shared.FormField field) async {
    final controller = _controllerFor(field.id);
    final result = await showModalBottomSheet<AiAssistResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AiAssistSheet(
        title: 'AI Assist',
        initialText: controller.text.trim(),
        initialType: 'summary',
        allowImage: false,
        allowAudio: false,
      ),
    );
    if (result == null) return;
    final output = result.outputText.trim();
    if (output.isEmpty) return;
    setState(() {
      controller.text = output;
      _values[field.id] = output;
    });
    await _recordAiUsage(result, field);
  }

  Future<void> _recordAiUsage(
    AiAssistResult result,
    shared.FormField field,
  ) async {
    try {
      await ref.read(opsRepositoryProvider).createAiJob(
            type: result.type,
            inputText: result.inputText.isEmpty ? null : result.inputText,
            outputText: result.outputText,
            metadata: {
              'source': 'form_fill',
              'formId': widget.form.id,
              'formTitle': widget.form.title,
              'fieldId': field.id,
              'fieldLabel': field.label,
              'fieldType': field.type.name,
              if (result.targetLanguage != null &&
                  result.targetLanguage!.isNotEmpty)
                'targetLanguage': result.targetLanguage,
              if (result.checklistCount != null)
                'checklistCount': result.checklistCount,
            },
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI log failed: $e')),
      );
    }
  }

  Map<String, dynamic> _buildSubmissionMetadata() {
    final types = <String>{};
    final hasText = _values.values.any((value) {
      if (value == null) return false;
      final text = value.toString().trim();
      return text.isNotEmpty && text != 'null';
    });
    if (hasText) {
      types.add('text');
    }
    for (final attachment in _attachments) {
      switch (attachment.type) {
        case 'photo':
          types.add('photo');
          break;
        case 'video':
          types.add('video');
          break;
        case 'audio':
          types.add('audio');
          break;
        case 'signature':
          types.add('signature');
          break;
        case 'file':
          types.add('document');
          break;
        default:
          types.add(attachment.type);
          break;
      }
    }
    if (_locationData != null) {
      types.add('geo');
    }
    if (types.isEmpty) {
      types.add('text');
    }
    final provider = _resolveAuthProvider();
    return {
      'visibility': _accessLevel,
      'inputTypes': types.toList(),
      'submissionSource': 'mobile',
      if (provider != null && provider.isNotEmpty) 'provider': provider,
    };
  }

  String? _resolveAuthProvider() {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final appMeta = user.appMetadata;
    final provider = appMeta['provider'];
    if (provider is String && provider.trim().isNotEmpty) {
      return provider.trim();
    }
    final providers = appMeta['providers'];
    if (providers is List && providers.isNotEmpty) {
      final value = providers.first.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null) return;
    if (!formState.validate()) return;
    formState.save();

    for (final field in widget.form.fields) {
      if (field.type == shared.FormFieldType.signature && field.isRequired) {
        if (_signatureAttachmentFor(field.id) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Signature required for ${field.label}')),
          );
          return;
        }
      }
    }

    setState(() => _submitting = true);

    final repo = ref.read(dashboardRepositoryProvider);
    final uploaded = await _uploadAttachments(_attachments);
    final attachmentJson = uploaded.map((a) {
      final json = a.toJson();
      if (_locationData != null && json['location'] == null) {
        json['location'] = _locationData;
      }
      return json;
    }).toList();
    final currentUser = _supabase.auth.currentUser;
    final submittedBy = currentUser?.email ?? currentUser?.id ?? 'anonymous';
    final submissionMetadata = _buildSubmissionMetadata();

    try {
      await repo.createSubmission(
        formId: widget.form.id,
        data: _values,
        submittedBy: submittedBy,
        attachments: attachmentJson,
        location: _locationData,
        metadata: submissionMetadata,
      );
      await AutomationScheduler.runIfDue(
        ops: ref.read(opsRepositoryProvider),
      );
      if (!mounted) return;
      ref.invalidate(dashboardDataProvider);
      setState(() => _isSubmitted = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
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
          metadata: submissionMetadata,
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
      if (item.url != null) {
        results.add(item);
        continue;
      }
      var bytes = item.bytes;
      if (bytes == null && item.path != null) {
        bytes = await loadFileBytes(item.path!);
      }
      if (bytes == null) {
        results.add(item);
        continue;
      }
      try {
        final prefix = _orgId != null ? 'org-$_orgId' : 'public';
        final path =
            '$prefix/submissions/${DateTime.now().microsecondsSinceEpoch}_${item.label}';
        await _supabase.storage
            .from(_supabaseBucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
        final publicUrl =
            _supabase.storage.from(_supabaseBucket).getPublicUrl(path);
        if (!mounted) return results;
        final nextMetadata = {
          ...?item.metadata,
          'storagePath': path,
          'bucket': _supabaseBucket,
        };
        results.add(
          item.copyWith(
            url: publicUrl,
            hash: _hashBytes(bytes),
            metadata: nextMetadata,
          ),
        );
      } catch (e) {
        // Keep original item on failure to avoid data loss.
        results.add(item);
        if (!mounted) return results;
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
  final String type; // photo, file, video, audio, signature
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
          : type == 'signature'
          ? 'image/png'
          : type == 'video'
          ? 'video/mp4'
          : type == 'audio'
          ? 'audio/m4a'
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
    Map<String, dynamic>? metadata,
  }) {
    return _AttachmentItem(
      id: id,
      type: type,
      label: label,
      bytes: bytes,
      path: path,
      metadata: metadata ?? this.metadata,
      url: url ?? this.url,
      hash: hash ?? this.hash,
    );
  }
}
