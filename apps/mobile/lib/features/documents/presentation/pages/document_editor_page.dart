import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared/shared.dart';

import '../../../../core/utils/file_bytes_loader.dart';
import '../../../dashboard/presentation/pages/photo_annotator_page.dart';
import '../../../projects/data/projects_provider.dart';
import '../../data/documents_provider.dart';

enum DocumentEditorMode { create, edit, version }

class DocumentEditorPage extends ConsumerStatefulWidget {
  const DocumentEditorPage({
    this.document,
    this.projectId,
    this.mode = DocumentEditorMode.create,
    super.key,
  });

  final Document? document;
  final String? projectId;
  final DocumentEditorMode mode;

  @override
  ConsumerState<DocumentEditorPage> createState() => _DocumentEditorPageState();
}

class _DocumentEditorPageState extends ConsumerState<DocumentEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _versionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _fileBytes;
  String? _filename;
  String? _mimeType;
  int? _fileSize;
  String? _projectId;
  bool _isTemplate = false;
  bool _isPublished = true;
  bool _notifyOrg = false;
  bool _saving = false;
  Map<String, dynamic> _metadata = {};

  bool get _requiresFile => widget.mode != DocumentEditorMode.edit;

  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    _titleController.text = doc?.title ?? '';
    _descriptionController.text = doc?.description ?? '';
    _categoryController.text = doc?.category ?? '';
    _tagsController.text = doc?.tags?.join(', ') ?? '';
    _projectId = widget.projectId ?? doc?.projectId;
    _isTemplate = doc?.isTemplate ?? false;
    _isPublished = doc?.isPublished ?? true;
    _metadata = {...?doc?.metadata};
    _versionController.text = _initialVersion(doc);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);
    final title = switch (widget.mode) {
      DocumentEditorMode.create => 'Upload Document',
      DocumentEditorMode.edit => 'Edit Document',
      DocumentEditorMode.version => 'New Version',
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) return null;
                  if (_filename != null) return null;
                  return 'Title is required';
                },
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
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              projectsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text(
                  'Projects unavailable',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                data: (projects) {
                  final hasSelection =
                      _projectId != null && projects.any((p) => p.id == _projectId);
                  final value = hasSelection ? _projectId : null;
                  return DropdownButtonFormField<String?>(
                    initialValue: value,
                    decoration: const InputDecoration(
                      labelText: 'Project',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No project'),
                      ),
                      ...projects.map(
                        (project) => DropdownMenuItem<String?>(
                          value: project.id,
                          child: Text(project.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _projectId = value),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.mode != DocumentEditorMode.edit) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _versionController,
                  decoration: const InputDecoration(
                    labelText: 'Version label',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Template'),
                subtitle: const Text('Save for reuse across projects'),
                value: _isTemplate,
                onChanged: (value) => setState(() => _isTemplate = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                subtitle: const Text('Visible to the team'),
                value: _isPublished,
                onChanged: (value) => setState(() => _isPublished = value),
              ),
              if (widget.mode != DocumentEditorMode.edit)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notify team'),
                  subtitle: const Text('Send an alert to organization members'),
                  value: _notifyOrg,
                  onChanged: (value) => setState(() => _notifyOrg = value),
                ),
              const SizedBox(height: 16),
              _buildFileSection(),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileSection() {
    if (!_requiresFile) {
      final filename = widget.document?.filename;
      final mime = widget.document?.mimeType;
      return Card(
        child: ListTile(
          leading: const Icon(Icons.insert_drive_file),
          title: Text(filename ?? 'Current file'),
          subtitle: Text(mime ?? 'Use Add version to replace the file.'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('File', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_fileBytes == null)
          const Text('No file selected')
        else
          Card(
            child: ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: Text(_filename ?? 'Selected file'),
              subtitle: Text(
                '${_formatFileSize(_fileSize ?? _fileBytes!.length)} • ${_mimeType ?? 'unknown'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isImage())
                    IconButton(
                      tooltip: 'Annotate',
                      icon: const Icon(Icons.edit),
                      onPressed: _annotateImage,
                    ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete),
                    onPressed: _clearFile,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.document_scanner),
              label: const Text('Scan'),
              onPressed: () => _pickImage(ImageSource.camera, 'camera'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
              onPressed: () => _pickImage(ImageSource.gallery, 'gallery'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
              onPressed: _pickFile,
            ),
          ],
        ),
      ],
    );
  }

  String _initialVersion(Document? doc) {
    if (widget.mode == DocumentEditorMode.version) {
      return _nextVersion(doc?.version ?? 'v1');
    }
    if (widget.mode == DocumentEditorMode.create) {
      return doc?.version ?? 'v1';
    }
    return doc?.version ?? 'v1';
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'png',
          'jpg',
          'jpeg',
          'heic',
          'heif',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'csv',
        ],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes ??
          (file.path != null ? await loadFileBytes(file.path!) : null);
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read file data.')),
        );
        return;
      }
      final mime = _guessMimeType(file.name) ?? 'application/octet-stream';
      if (!mounted) return;
      _setSelectedFile(
        bytes: bytes,
        filename: file.name,
        mimeType: mime,
        fileSize: file.size,
        source: 'file',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Future<void> _pickImage(ImageSource source, String sourceLabel) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mime = _guessMimeType(picked.path) ?? 'image/jpeg';
      if (!mounted) return;
      _setSelectedFile(
        bytes: bytes,
        filename: picked.name,
        mimeType: mime,
        fileSize: bytes.length,
        source: sourceLabel,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $e')),
      );
    }
  }

  Future<void> _annotateImage() async {
    if (_fileBytes == null) return;
    final annotated = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => PhotoAnnotatorPage(
          imageBytes: _fileBytes!,
          title: 'Annotate document',
        ),
      ),
    );
    if (annotated == null) return;
    if (!mounted) return;
    final base = _filename != null
        ? p.basenameWithoutExtension(_filename!)
        : 'document';
    setState(() {
      _fileBytes = annotated;
      _filename = '${base}_annotated.png';
      _mimeType = 'image/png';
      _fileSize = annotated.length;
      _metadata = {
        ..._metadata,
        'annotated': true,
        'annotatedAt': DateTime.now().toIso8601String(),
      };
    });
  }

  void _clearFile() {
    setState(() {
      _fileBytes = null;
      _filename = null;
      _mimeType = null;
      _fileSize = null;
      _metadata = {..._metadata}
        ..remove('source')
        ..remove('annotated')
        ..remove('annotatedAt');
    });
  }

  void _setSelectedFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    int? fileSize,
    String? source,
  }) {
    setState(() {
      _fileBytes = bytes;
      _filename = filename;
      _mimeType = mimeType;
      _fileSize = fileSize ?? bytes.length;
      _metadata = {
        ..._metadata,
        if (source != null) 'source': source,
      };
    });
    if (_titleController.text.trim().isEmpty) {
      _titleController.text = p.basenameWithoutExtension(filename);
    }
  }

  bool _isImage() {
    final mime = _mimeType?.toLowerCase() ?? '';
    final name = _filename?.toLowerCase() ?? '';
    return mime.startsWith('image/') ||
        name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.heic') ||
        name.endsWith('.heif');
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_requiresFile && _fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a file to upload.')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(documentsRepositoryProvider);
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (_filename != null ? p.basenameWithoutExtension(_filename!) : 'Untitled');
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final category = _categoryController.text.trim().isEmpty
        ? null
        : _categoryController.text.trim();
    final tags = _parseTags(_tagsController.text);
    final metadata = _metadata.isEmpty ? null : _metadata;

    try {
      Document doc;
      switch (widget.mode) {
        case DocumentEditorMode.create:
          doc = await repo.createDocument(
            title: title,
            description: description,
            category: category,
            projectId: _projectId,
            tags: tags,
            bytes: _fileBytes!,
            filename: _filename ?? 'document',
            mimeType: _mimeType ?? 'application/octet-stream',
            fileSize: _fileSize ?? _fileBytes!.length,
            version: _versionController.text.trim().isEmpty
                ? 'v1'
                : _versionController.text.trim(),
            isTemplate: _isTemplate,
            isPublished: _isPublished,
            metadata: metadata,
            notifyOrg: _notifyOrg,
          );
          break;
        case DocumentEditorMode.version:
          doc = await repo.addVersion(
            document: widget.document!,
            bytes: _fileBytes!,
            filename: _filename ?? widget.document!.filename,
            mimeType: _mimeType ?? widget.document!.mimeType,
            fileSize: _fileSize ?? _fileBytes!.length,
            version: _versionController.text.trim().isEmpty
                ? widget.document!.version
                : _versionController.text.trim(),
            title: title,
            description: description,
            category: category,
            projectId: _projectId,
            tags: tags,
            isTemplate: _isTemplate,
            isPublished: _isPublished,
            metadata: metadata,
            notifyOrg: _notifyOrg,
          );
          break;
        case DocumentEditorMode.edit:
          doc = await repo.updateDocument(
            documentId: widget.document!.id,
            title: title,
            description: description,
            category: category,
            projectId: _projectId,
            tags: tags,
            isTemplate: _isTemplate,
            isPublished: _isPublished,
            metadata: metadata,
          );
          break;
      }
      if (!mounted) return;
      Navigator.pop(context, doc);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatFileSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var suffixIndex = 0;
    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[suffixIndex]}';
  }

  String _nextVersion(String current) {
    final match = RegExp(r'(\d+)$').firstMatch(current.trim());
    if (match == null) return '${current}_2';
    final next = int.tryParse(match.group(1) ?? '') ?? 1;
    return 'v${next + 1}';
  }

  String? _guessMimeType(String filename) {
    final ext = p.extension(filename).toLowerCase();
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.heic':
      case '.heif':
        return 'image/heic';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.csv':
        return 'text/csv';
      case '.txt':
        return 'text/plain';
      default:
        return null;
    }
  }

  List<String>? _parseTags(String raw) {
    final tags = raw
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    if (tags.isEmpty) return null;
    return tags;
  }
}
