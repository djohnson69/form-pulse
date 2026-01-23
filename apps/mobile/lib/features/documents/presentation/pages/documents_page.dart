import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/storage_utils.dart';
import '../../data/documents_repository.dart';
import '../../data/documents_provider.dart';
import 'document_detail_page.dart';
import 'document_editor_page.dart';
import '../../../dashboard/presentation/widgets/drawing_canvas.dart';

enum _DocumentsViewMode { grid, list }

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({this.projectId, this.projectName, super.key});

  final String? projectId;
  final String? projectName;

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFolder = 'all';
  _DocumentsViewMode _viewMode = _DocumentsViewMode.list;
  RealtimeChannel? _documentsChannel;
  final ImagePicker _picker = ImagePicker();
  static const _bucketName =
      String.fromEnvironment('SUPABASE_BUCKET', defaultValue: 'formbridge-attachments');

  @override
  void initState() {
    super.initState();
    _subscribeToDocumentChanges();
  }

  @override
  void dispose() {
    _documentsChannel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  void _subscribeToDocumentChanges() {
    final client = Supabase.instance.client;
    final channelName = 'documents-${widget.projectId ?? 'all'}';
    _documentsChannel = client.channel(channelName)
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'documents',
        filter: widget.projectId == null
            ? null
            : PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'project_id',
                value: widget.projectId,
              ),
        callback: (_) {
          if (!mounted) return;
          ref.invalidate(documentsProvider(widget.projectId));
        },
      )
      ..subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider(widget.projectId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _DocumentsErrorView(error: e.toString()),
        data: (docs) {
          final isWide = MediaQuery.of(context).size.width >= 768;
          final models = docs
              .map((doc) => _DocumentViewModel.fromDocument(doc))
              .toList();
          final folders = _buildFolderSummaries(models);
          final filtered = _applyFilters(models);
          final stats = _DocumentStats.fromModels(models);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(documentsProvider(widget.projectId));
              await ref.read(documentsProvider(widget.projectId).future);
            },
            child: ListView(
              padding: EdgeInsets.all(isWide ? 24 : 16),
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildCollaborationTools(context, models),
                const SizedBox(height: 24),
                _DocumentStatsGrid(stats: stats),
                const SizedBox(height: 24),
                _buildFolderSection(context, folders),
                const SizedBox(height: 24),
                _buildFilters(context, folders),
                const SizedBox(height: 24),
                _buildDocumentsBody(context, filtered),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Management',
              style: TextStyle(
                fontSize: isWide ? 30 : 24,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage and access all project documents and files',
              style: TextStyle(
                fontSize: 16,
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ],
        );

        final showFullLabel = constraints.maxWidth >= 640;
        final controls = Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ViewToggle(
              selected: _viewMode,
              onChanged: (mode) => setState(() => _viewMode = mode),
            ),
            FilledButton.icon(
              onPressed: () => _openEditor(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.upload_file, size: 20),
              label: Text(showFullLabel ? 'Upload Document' : 'Upload'),
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

  Widget _buildCollaborationTools(
    BuildContext context,
    List<_DocumentViewModel> docs,
  ) {
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
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Collaboration Tools:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? const Color(0xFFD1D5DB)
                  : const Color(0xFF374151),
            ),
          ),
          _ToolButton(
            icon: Icons.document_scanner,
            label: 'Scan Document',
            onPressed: () => _openScanner(context),
          ),
          _ToolButton(
            icon: Icons.edit_outlined,
            label: 'Annotate',
            onPressed: () async {
              final doc = _defaultDocument(docs);
              if (doc == null) {
                _showEmptyDocumentMessage(context);
                return;
              }
              await _openAnnotateDocument(context, doc);
            },
          ),
          _ToolButton(
            icon: Icons.device_hub_outlined,
            label: 'Version History',
            onPressed: () async {
              final doc = _defaultDocument(docs);
              if (doc == null) {
                _showEmptyDocumentMessage(context);
                return;
              }
              await _openVersionHistory(context, doc.document);
            },
          ),
          _ToolButton(
            icon: Icons.draw_outlined,
            label: 'Collect Signatures',
            onPressed: () async {
              final doc = _defaultDocument(docs);
              if (doc == null) {
                _showEmptyDocumentMessage(context);
                return;
              }
              await _openSignatureCollection(context, doc.document);
            },
          ),
          _ToolButton(
            icon: Icons.fact_check_outlined,
            label: 'Templates',
            onPressed: () => _openTemplates(context, docs),
          ),
          _ToolButton(
            icon: Icons.group_outlined,
            label: 'Collaborate',
            onPressed: () async {
              final doc = _defaultDocument(docs);
              if (doc == null) {
                _showEmptyDocumentMessage(context);
                return;
              }
              await _openCollaborativeEditor(context, doc.document);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFolderSection(
    BuildContext context,
    List<_FolderSummary> folders,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_open_outlined, size: 16),
            const SizedBox(width: 8),
            Text(
              'Quick Access Folders',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF374151),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 1024
                ? 7
                : width >= 768
                    ? 4
                    : 2;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: folders
                  .map(
                    (folder) => _FolderCard(
                      folder: folder,
                      isSelected: _selectedFolder == folder.name,
                      onTap: () {
                        setState(() => _selectedFolder = folder.name);
                      },
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilters(
    BuildContext context,
    List<_FolderSummary> folders,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
      ),
    );
    InputDecoration inputDecoration({IconData? prefixIcon, String? hintText}) {
      return InputDecoration(
        prefixIcon: prefixIcon == null
            ? null
            : Icon(
                prefixIcon,
                size: 20,
                color: isDark
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF9CA3AF),
              ),
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF111827) : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      );
    }
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;
          final children = [
            Expanded(
              flex: isWide ? 2 : 0,
              child: TextField(
                controller: _searchController,
                decoration: inputDecoration(
                  prefixIcon: Icons.search,
                  hintText: 'Search documents...',
                ),
                style: TextStyle(
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
                value: _selectedFolder,
                isExpanded: true,
                decoration: inputDecoration(),
                dropdownColor:
                    isDark ? const Color(0xFF111827) : Colors.white,
                iconEnabledColor:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All Folders'),
                  ),
                  ...folders.map(
                    (folder) => DropdownMenuItem(
                      value: folder.name,
                      child: Text(folder.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedFolder = value ?? 'all');
                },
              ),
            ),
            SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_list, size: 16),
              label: const Text('Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                side: BorderSide(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

  Widget _buildDocumentsBody(
    BuildContext context,
    List<_DocumentViewModel> docs,
  ) {
    if (_viewMode == _DocumentsViewMode.list) {
      return _DocumentsListTable(
        docs: docs,
        onOpen: (doc) => _openDetail(doc),
        onDownload: (doc) => _openDocumentUrl(doc),
        onShare: (doc) => _shareDocument(doc),
        onDelete: (doc) => _confirmDelete(context, doc),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1024 ? 4 : (width >= 768 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: crossAxisCount > 1 ? 0.95 : 1.1,
          children: docs
              .map(
                (doc) => _DocumentGridCard(
                  model: doc,
                  onOpen: () => _openDetail(doc.document),
                  onDownload: () => _openDocumentUrl(doc.document),
                  onShare: () => _shareDocument(doc.document),
                ),
              )
              .toList(),
        );
      },
    );
  }

  _DocumentViewModel? _defaultDocument(List<_DocumentViewModel> docs) {
    if (docs.isEmpty) return null;
    final sorted = List<_DocumentViewModel>.from(docs)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.first;
  }

  void _showEmptyDocumentMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No documents available yet')),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    Document? document,
    DocumentEditorMode mode = DocumentEditorMode.create,
    Uint8List? initialBytes,
    String? initialFilename,
    String? initialMimeType,
  }) async {
    final result = await Navigator.of(context).push<Document?>(
      MaterialPageRoute(
        builder: (_) => DocumentEditorPage(
          document: document,
          projectId: widget.projectId,
          mode: mode,
          initialBytes: initialBytes,
          initialFilename: initialFilename,
          initialMimeType: initialMimeType,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      ref.invalidate(documentsProvider(widget.projectId));
    }
  }

  Future<void> _openDetail(
    Document document, {
    bool openSignatureOnLoad = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentDetailPage(
          document: document,
          projectId: widget.projectId,
          projectName: widget.projectName,
          openSignatureOnLoad: openSignatureOnLoad,
        ),
      ),
    );
    if (!mounted) return;
    ref.invalidate(documentsProvider(widget.projectId));
  }

  Future<void> _openTemplates(
    BuildContext context,
    List<_DocumentViewModel> docs,
  ) async {
    final templates = _templatesFromDocuments(docs);
    if (templates.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No templates available yet')),
      );
      return;
    }
    final selection = await showDialog<_DocumentTemplate>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.95;
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Center(
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1280,
                  maxHeight: height,
                ),
                child: _TemplateLibrarySheet(templates: templates),
              ),
            ),
          ),
        );
      },
    );
    if (selection == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Using template: ${selection.name}')),
    );
  }

  List<_DocumentTemplate> _templatesFromDocuments(
    List<_DocumentViewModel> docs,
  ) {
    return docs
        .where((doc) => doc.isTemplate)
        .map((doc) {
          final meta = doc.document.metadata ?? const <String, dynamic>{};
          final tags = <String>[];
          final rawTags = meta['tags'];
          if (rawTags is List) {
            for (final tag in rawTags) {
              final value = tag?.toString();
              if (value != null && value.trim().isNotEmpty) {
                tags.add(value.trim());
              }
            }
          }
          if (tags.isEmpty) {
            tags.addAll({doc.type, doc.folder}.where((e) => e.isNotEmpty));
          }
          return _DocumentTemplate(
            id: doc.document.id,
            name: doc.displayName,
            category: doc.folder.isEmpty ? 'general' : doc.folder,
            description:
                (doc.description?.isNotEmpty == true ? doc.description! : doc.filename),
            downloads: doc.views,
            rating: 0,
            lastUsed: doc.updatedAt,
            isFavorite: doc.starred,
            tags: tags,
          );
        })
        .toList();
  }

  Future<void> _openCollaborativeEditor(
    BuildContext context,
    Document document,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.95;
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Center(
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1280,
                  maxHeight: height,
                ),
                child: _CollaborativeEditorSheet(document: document),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openScanner(BuildContext context) async {
    final result = await showDialog<_ScannedDocument>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.9;
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Center(
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1024,
                  maxHeight: height,
                ),
                child: _DocumentScannerSheet(picker: _picker),
              ),
            ),
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    await _openEditor(
      context,
      initialBytes: result.bytes,
      initialFilename: result.filename,
      initialMimeType: result.mimeType,
    );
  }

  Future<void> _openAnnotateDocument(
    BuildContext context,
    _DocumentViewModel doc,
  ) async {
    final bytes = await _downloadDocumentBytes(doc.document);
    if (bytes == null || !context.mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load document for annotation')),
        );
      }
      return;
    }
    final annotated = await showDialog<Uint8List?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Center(
          child: Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: Colors.transparent,
            child: _DocumentAnnotationSheet(
              documentName: doc.displayName,
              filename: doc.filename,
              mimeType: doc.mimeType,
              bytes: bytes,
            ),
          ),
        ),
      ),
    );
    if (annotated == null || !context.mounted) return;
    final repo = ref.read(documentsRepositoryProvider);
    try {
      final versionLabel =
          'annotated-${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
      await repo.addVersion(
        document: doc.document,
        bytes: annotated,
        filename: doc.filename,
        mimeType: doc.mimeType,
        fileSize: annotated.length,
        version: versionLabel,
        title: doc.title,
        description: doc.description,
        category: doc.folder,
        projectId: widget.projectId,
      );
      ref.invalidate(documentsProvider(widget.projectId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annotated version saved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Annotation save failed: $e')),
      );
    }
  }

  Future<void> _openSignatureCollection(
    BuildContext context,
    Document document,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.95;
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Center(
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 896,
                  maxHeight: height,
                ),
                child: _SignatureCollectionSheet(document: document),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openVersionHistory(
    BuildContext context,
    Document document,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.9;
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Center(
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1024,
                  maxHeight: height,
                ),
                child: _DocumentVersionControlSheet(
                  document: document,
                  onClose: () => Navigator.pop(context),
                  onDownload: (version) => _openUrl(
                    version.fileUrl,
                    mimeType: version.mimeType,
                    filename: version.filename,
                    metadata: version.metadata,
                  ),
                  onRestore: (version) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Restored version ${version.version}.'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List?> _downloadDocumentBytes(Document doc) async {
    final metadata = doc.metadata ?? const {};
    final path = metadata['storagePath']?.toString() ??
        metadata['path']?.toString();
    final bucket = metadata['bucket']?.toString() ?? _bucketName;
    if (path == null || path.isEmpty) return null;
    try {
      final bytes = await Supabase.instance.client.storage
          .from(bucket)
          .download(path);
      return bytes;
    } catch (e, st) {
      developer.log('DocumentsPage download document failed',
          error: e, stackTrace: st, name: 'DocumentsPage._downloadDocument');
      return null;
    }
  }

  Future<void> _confirmDelete(BuildContext context, Document doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text(
          'This will permanently remove the document and its file.',
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
    if (confirmed != true || !context.mounted) return;
    await _deleteDocument(doc);
  }

  Future<void> _deleteDocument(Document doc) async {
    final repo = ref.read(documentsRepositoryProvider);
    try {
      await repo.deleteDocument(document: doc);
      if (!mounted) return;
      ref.invalidate(documentsProvider(widget.projectId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _shareDocument(Document doc) async {
    final name = doc.filename.isNotEmpty ? doc.filename : doc.title;
    final message = StringBuffer()
      ..writeln(name)
      ..writeln(doc.fileUrl);
    await Share.share(message.toString());
  }

  Future<void> _openDocumentUrl(Document doc) async {
    await _openUrl(
      doc.fileUrl,
      mimeType: doc.mimeType,
      filename: doc.filename,
      metadata: doc.metadata,
    );
  }

  Future<void> _openUrl(
    String url, {
    required String mimeType,
    required String filename,
    Map<String, dynamic>? metadata,
  }) async {
    final signedUrl = await createSignedStorageUrl(
      client: Supabase.instance.client,
      url: url,
      defaultBucket: _bucketName,
      metadata: metadata,
      expiresInSeconds: kSignedUrlExpirySeconds,
    );
    final effectiveUrl = signedUrl ?? url;
    final isImage = mimeType.startsWith('image/') ||
        filename.toLowerCase().endsWith('.png') ||
        filename.toLowerCase().endsWith('.jpg') ||
        filename.toLowerCase().endsWith('.jpeg') ||
        filename.toLowerCase().endsWith('.heic') ||
        filename.toLowerCase().endsWith('.heif');
    if (isImage) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: Image.network(effectiveUrl, fit: BoxFit.cover),
        ),
      );
      return;
    }
    final uri = Uri.parse(effectiveUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<_DocumentViewModel> _applyFilters(List<_DocumentViewModel> docs) {
    return docs.where((doc) {
      final matchesSearch = _searchQuery.isEmpty ||
          doc.displayName.toLowerCase().contains(_searchQuery);
      final matchesFolder =
          _selectedFolder == 'all' || doc.folder == _selectedFolder;
      return matchesSearch && matchesFolder;
    }).toList();
  }

  List<_FolderSummary> _buildFolderSummaries(List<_DocumentViewModel> docs) {
    final counts = <String, int>{};
    final displayNames = <String, String>{};
    for (final doc in docs) {
      final folder = doc.folder.trim();
      if (folder.isEmpty) continue;
      final key = folder.toLowerCase();
      counts.update(key, (value) => value + 1, ifAbsent: () => 1);
      displayNames.putIfAbsent(key, () => folder);
    }
    const preferredOrder = [
      'Manuals',
      'Blueprints',
      'Reports',
      'Photos',
      'Contracts',
      'Training',
      'Certificates',
    ];
    final preferredKeys = {
      for (final name in preferredOrder) name.toLowerCase(): name,
    };
    final summaries = <_FolderSummary>[
      for (final name in preferredOrder)
        _FolderSummary.fromName(
          name,
          counts[name.toLowerCase()] ?? 0,
        ),
    ];
    final extras = counts.entries
        .where((entry) => !preferredKeys.containsKey(entry.key))
        .map(
          (entry) => _FolderSummary.fromName(
            displayNames[entry.key] ?? entry.key,
            entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    summaries.addAll(extras);
    return summaries;
  }
}

class _DocumentStats {
  const _DocumentStats({
    required this.totalDocuments,
    required this.storageBytes,
    required this.sharedFiles,
    required this.recentUploads,
  });

  final int totalDocuments;
  final int storageBytes;
  final int sharedFiles;
  final int recentUploads;

  String get storageLabel => _formatBytes(storageBytes);

  factory _DocumentStats.fromModels(List<_DocumentViewModel> docs) {
    final totalBytes = docs.fold<int>(0, (sum, doc) => sum + doc.fileSize);
    final shared = docs.where((doc) => doc.isShared).length;
    final now = DateTime.now();
    final recent = docs
        .where((doc) => now.difference(doc.updatedAt).inHours <= 24)
        .length;
    return _DocumentStats(
      totalDocuments: docs.length,
      storageBytes: totalBytes,
      sharedFiles: shared,
      recentUploads: recent,
    );
  }

  static String _formatBytes(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var suffixIndex = 0;
    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }
    return '${size.toStringAsFixed(0)} ${suffixes[suffixIndex]}';
  }
}

class _DocumentStatsGrid extends StatelessWidget {
  const _DocumentStatsGrid({required this.stats});

  final _DocumentStats stats;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            _DocumentStatCard(
              label: 'Total Documents',
              value: formatter.format(stats.totalDocuments),
              note: 'Across all folders',
              icon: Icons.insert_drive_file_outlined,
              color: const Color(0xFF3B82F6),
            ),
            _DocumentStatCard(
              label: 'Storage Used',
              value: stats.storageLabel,
              note: 'of 10 GB available',
              icon: Icons.trending_up,
              color: const Color(0xFF22C55E),
            ),
            _DocumentStatCard(
              label: 'Shared Files',
              value: formatter.format(stats.sharedFiles),
              note: 'Active shares',
              icon: Icons.share_outlined,
              color: const Color(0xFF8B5CF6),
              noteColor:
                  isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED),
            ),
            _DocumentStatCard(
              label: 'Recent Activity',
              value: formatter.format(stats.recentUploads),
              note: 'Uploads today',
              icon: Icons.schedule,
              color: const Color(0xFFF97316),
            ),
          ],
        );
      },
    );
  }
}

class _DocumentStatCard extends StatelessWidget {
  const _DocumentStatCard({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
    this.noteColor,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
  final Color? noteColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final resolvedNoteColor = noteColor ?? const Color(0xFF6B7280);
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
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
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
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 12,
              color: resolvedNoteColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentViewModel {
  _DocumentViewModel({
    required this.document,
    required this.title,
    required this.filename,
    required this.type,
    required this.folder,
    required this.uploadedBy,
    required this.updatedAt,
    required this.mimeType,
    required this.description,
    required this.starred,
    required this.views,
    required this.isShared,
    required this.isTemplate,
    required this.fileSize,
  });

  final Document document;
  final String title;
  final String filename;
  final String type;
  final String folder;
  final String uploadedBy;
  final DateTime updatedAt;
  final String mimeType;
  final String? description;
  final bool starred;
  final int views;
  final bool isShared;
  final bool isTemplate;
  final int fileSize;

  String get sizeLabel => document.formattedFileSize;
  String get dateLabel => DateFormat.yMd().format(updatedAt);
  String get displayName =>
      filename.isNotEmpty ? filename : (title.isNotEmpty ? title : 'Document');

  factory _DocumentViewModel.fromDocument(Document doc) {
    final metadata = doc.metadata ?? const <String, dynamic>{};
    final folder = _resolveFolder(doc, metadata);
    final uploadedBy =
        _readString(metadata['uploadedByName'], doc.uploadedBy) ??
        doc.uploadedBy;
    final viewCount = _readInt(metadata['views']) ??
        _readInt(metadata['viewCount']) ??
        0;
    final sharedRaw =
        metadata['sharedWith'] ?? metadata['sharedUsers'] ?? metadata['shared'];
    final isShared = sharedRaw is List
        ? sharedRaw.isNotEmpty
        : sharedRaw == true || _readInt(sharedRaw) != null;
    final starred =
        metadata['starred'] == true || metadata['favorite'] == true;
    final updatedAt = doc.updatedAt ?? doc.uploadedAt;
    return _DocumentViewModel(
      document: doc,
      title: doc.title,
      filename: doc.filename,
      type: _resolveType(doc),
      folder: folder,
      uploadedBy: uploadedBy.isNotEmpty ? uploadedBy : 'Team',
      updatedAt: updatedAt,
      mimeType: doc.mimeType,
      description: doc.description,
      starred: starred,
      views: viewCount,
      isShared: isShared,
      isTemplate: doc.isTemplate,
      fileSize: doc.fileSize,
    );
  }

  static String _resolveFolder(
    Document doc,
    Map<String, dynamic> metadata,
  ) {
    final raw =
        metadata['folder'] ?? metadata['category'] ?? doc.category ?? '';
    final cleaned = raw.toString().trim();
    if (cleaned.isNotEmpty) return cleaned;
    final lower = doc.filename.toLowerCase();
    if (doc.mimeType.startsWith('image/') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return 'Photos';
    }
    if (lower.endsWith('.pdf')) return 'Manuals';
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || lower.endsWith('.csv')) {
      return 'Reports';
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return 'Contracts';
    }
    return 'General';
  }

  static String _resolveType(Document doc) {
    final lower = doc.filename.toLowerCase();
    if (doc.mimeType.startsWith('image/') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return 'Image';
    }
    if (lower.endsWith('.pdf')) return 'PDF';
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return 'Excel';
    if (lower.endsWith('.csv')) return 'CSV';
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return 'Word';
    if (lower.endsWith('.dwg')) return 'CAD';
    if (lower.endsWith('.zip')) return 'Archive';
    return 'File';
  }

  static String? _readString(dynamic value, String? fallback) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class _FolderSummary {
  _FolderSummary({
    required this.name,
    required this.count,
    required this.emoji,
    required this.color,
  });

  final String name;
  final int count;
  final String emoji;
  final Color color;

  factory _FolderSummary.fromName(String name, int count) {
    final lower = name.toLowerCase();
    if (lower.contains('manual')) {
      return _FolderSummary(
        name: name,
        count: count,
        emoji: '\u{1F4D8}',
        color: const Color(0xFF3B82F6),
      );
    }
    if (lower.contains('blueprint') || lower.contains('cad')) {
      return _FolderSummary(
        name: name,
        count: count,
        emoji: '\u{1F4D0}',
        color: const Color(0xFF8B5CF6),
      );
    }
    if (lower.contains('report')) {
      return _FolderSummary(
        name: name,
        count: count,
        emoji: '\u{1F4CA}',
        color: const Color(0xFF10B981),
      );
    }
    if (lower.contains('photo') || lower.contains('image')) {
      return _FolderSummary(
        name: name,
        count: count,
        emoji: '\u{1F4F7}',
        color: const Color(0xFFF97316),
      );
    }
    if (lower.contains('contract')) {
      return _FolderSummary(
        name: name,
        count: count,
        emoji: '\u{1F4C4}',
        color: const Color(0xFFEF4444),
      );
    }
    if (lower.contains('training')) {
      return _FolderSummary(
        name: name,
        count: count,
        emoji: '\u{1F393}',
        color: const Color(0xFFF59E0B),
      );
    }
    if (lower.contains('certificate')) {
      return _FolderSummary(
        name: name,
        count: count,
        emoji: '\u{1F3C6}',
        color: const Color(0xFFEC4899),
      );
    }
    return _FolderSummary(
      name: name,
      count: count,
      emoji: '\u{1F4C1}',
      color: const Color(0xFF64748B),
    );
  }
}

enum _TemplateSort { popular, recent, name }

class _TemplateCategory {
  const _TemplateCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.count,
  });

  final String id;
  final String name;
  final String emoji;
  final int count;
}

class _DocumentTemplate {
  const _DocumentTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.downloads,
    required this.rating,
    required this.isFavorite,
    required this.tags,
    this.lastUsed,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final int downloads;
  final double rating;
  final DateTime? lastUsed;
  final bool isFavorite;
  final List<String> tags;
}

class _TemplateLibrarySheet extends StatefulWidget {
  const _TemplateLibrarySheet({required this.templates});

  final List<_DocumentTemplate> templates;

  @override
  State<_TemplateLibrarySheet> createState() => _TemplateLibrarySheetState();
}

class _TemplateLibrarySheetState extends State<_TemplateLibrarySheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';
  _TemplateSort _sortBy = _TemplateSort.popular;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_TemplateCategory> _buildCategories() {
    final counts = <String, int>{};
    for (final template in widget.templates) {
      counts.update(
        template.category.toLowerCase(),
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return [
      _TemplateCategory(
        id: 'all',
        name: 'All Templates',
        emoji: '\u{1F4C4}',
        count: widget.templates.length,
      ),
      _TemplateCategory(
        id: 'safety',
        name: 'Safety Forms',
        emoji: '\u{1F9BA}',
        count: counts['safety'] ?? 0,
      ),
      _TemplateCategory(
        id: 'inspection',
        name: 'Inspection Reports',
        emoji: '\u{1F50D}',
        count: counts['inspection'] ?? 0,
      ),
      _TemplateCategory(
        id: 'contracts',
        name: 'Contracts',
        emoji: '\u{1F4DD}',
        count: counts['contracts'] ?? 0,
      ),
      _TemplateCategory(
        id: 'checklists',
        name: 'Checklists',
        emoji: '\u{2705}',
        count: counts['checklists'] ?? 0,
      ),
      _TemplateCategory(
        id: 'incident',
        name: 'Incident Reports',
        emoji: '\u{26A0}',
        count: counts['incident'] ?? 0,
      ),
    ];
  }

  List<_DocumentTemplate> _filteredTemplates() {
    final query = _searchQuery.trim().toLowerCase();
    final items = widget.templates.where((template) {
      final matchesSearch = query.isEmpty ||
          template.name.toLowerCase().contains(query) ||
          template.description.toLowerCase().contains(query) ||
          template.tags.any((tag) => tag.toLowerCase().contains(query));
      final matchesCategory =
          _selectedCategory == 'all' || template.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
    items.sort((a, b) {
      switch (_sortBy) {
        case _TemplateSort.popular:
          return b.downloads.compareTo(a.downloads);
        case _TemplateSort.recent:
          return (b.lastUsed?.millisecondsSinceEpoch ?? 0)
              .compareTo(a.lastUsed?.millisecondsSinceEpoch ?? 0);
        case _TemplateSort.name:
          return a.name.compareTo(b.name);
      }
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final filtered = _filteredTemplates();
    final categories = _buildCategories();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Material(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          elevation: 24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TemplateLibraryHeader(
                  onClose: () => Navigator.of(context).pop(),
                ),
                Divider(height: 1, color: border),
                _TemplateLibrarySearchBar(
                  controller: _searchController,
                  onSearchChanged: (value) => setState(
                    () => _searchQuery = value.trim(),
                  ),
                  sortBy: _sortBy,
                  onSortChanged: (value) => setState(
                    () => _sortBy = value ?? _TemplateSort.popular,
                  ),
                  borderColor: border,
                ),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 256,
                        child: _TemplateCategoryList(
                          categories: categories,
                          selectedCategory: _selectedCategory,
                          onSelected: (value) => setState(
                            () => _selectedCategory = value,
                          ),
                          borderColor: border,
                          isDark: isDark,
                          axis: Axis.vertical,
                        ),
                      ),
                      Expanded(
                        child: _TemplateGrid(
                          templates: filtered,
                          onSelect: (template) {
                            Navigator.pop(context, template);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                _TemplateLibraryFooter(
                  count: filtered.length,
                  onClose: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
class _TemplateLibraryHeader extends StatelessWidget {
  const _TemplateLibraryHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Template Library',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose from professionally designed document templates',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(8),
            hoverColor:
                isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.close,
                size: 24,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateLibrarySearchBar extends StatelessWidget {
  const _TemplateLibrarySearchBar({
    required this.controller,
    required this.sortBy,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.borderColor,
  });

  final TextEditingController controller;
  final _TemplateSort sortBy;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_TemplateSort?> onSortChanged;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final barBackground =
        isDark ? const Color(0xFF2D3748) : const Color(0xFFF9FAFB);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
      ),
    );
    final searchField = TextField(
      controller: controller,
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search templates by name, description, or tags...',
        prefixIcon: Icon(
          Icons.search,
          size: 20,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
        ),
        hintStyle: TextStyle(
          fontSize: 16,
          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF111827) : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
      style: TextStyle(
        fontSize: 16,
        color: isDark ? Colors.white : const Color(0xFF111827),
      ),
    );

    final sortDropdown = DropdownButtonFormField<_TemplateSort>(
      value: sortBy,
      decoration: InputDecoration(
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF111827) : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      dropdownColor: isDark ? const Color(0xFF111827) : Colors.white,
      iconEnabledColor:
          isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      style: TextStyle(
        fontSize: 16,
        color: isDark ? Colors.white : const Color(0xFF111827),
      ),
      items: const [
        DropdownMenuItem(
          value: _TemplateSort.popular,
          child: Text('Most Popular'),
        ),
        DropdownMenuItem(
          value: _TemplateSort.recent,
          child: Text('Recently Used'),
        ),
        DropdownMenuItem(
          value: _TemplateSort.name,
          child: Text('Alphabetical'),
        ),
      ],
      onChanged: onSortChanged,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: barBackground,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 768;
          if (isCompact) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 12),
                sortDropdown,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              SizedBox(width: 220, child: sortDropdown),
            ],
          );
        },
      ),
    );
  }
}

class _TemplateCategoryList extends StatelessWidget {
  const _TemplateCategoryList({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
    required this.borderColor,
    required this.isDark,
    required this.axis,
  });

  final List<_TemplateCategory> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;
  final Color borderColor;
  final bool isDark;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        isDark ? const Color(0xFF2D3748) : const Color(0xFFF9FAFB);
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: axis == Axis.vertical
            ? Border(right: BorderSide(color: borderColor))
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: ListView.separated(
        scrollDirection: axis,
        itemCount: categories.length,
        separatorBuilder: (_, __) =>
            axis == Axis.vertical ? const SizedBox(height: 4) : const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.id == selectedCategory;
          const selectedBackground = Color(0xFF2563EB);
          final color = isSelected ? selectedBackground : Colors.transparent;
          final textColor = isSelected
              ? Colors.white
              : (isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151));
          final countColor = isSelected
              ? const Color(0xFFDBEAFE)
              : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280));
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onSelected(category.id),
            hoverColor: isSelected
                ? Colors.transparent
                : (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
            child: Container(
              width: axis == Axis.horizontal ? 200 : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    category.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 14,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${category.count} templates',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            color: countColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TemplateGrid extends StatelessWidget {
  const _TemplateGrid({
    required this.templates,
    required this.onSelect,
  });

  final List<_DocumentTemplate> templates;
  final ValueChanged<_DocumentTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color:
                  isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              'No templates found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search or filter',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1024
            ? 3
            : width >= 768
                ? 2
                : 1;
        final aspectRatio = width >= 1024
            ? 0.9
            : width >= 768
                ? 1.05
                : 1.2;
        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: aspectRatio,
          ),
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final template = templates[index];
            return _TemplateCard(
              template: template,
              onSelect: () => onSelect(template),
            );
          },
        );
      },
    );
  }
}

class _TemplateCard extends StatefulWidget {
  const _TemplateCard({
    required this.template,
    required this.onSelect,
  });

  final _DocumentTemplate template;
  final VoidCallback onSelect;

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _isHovered = false;

  String _lastUsedLabel(DateTime? lastUsed) {
    if (lastUsed == null) return '';
    final days = math.max(0, DateTime.now().difference(lastUsed).inDays);
    return '${days}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final cardBackground =
        isDark ? const Color(0xFF2D3748) : Colors.white;
    final previewBackground =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final previewIconColor =
        isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF);
    final secondaryText =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final tagBackground =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final tagText =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);
    final lastUsedLabel = _lastUsedLabel(widget.template.lastUsed);
    final supportsHover = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final showOverlay = _isHovered;
    final showHoverShadow = supportsHover && _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: showHoverShadow
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
            Stack(
              children: [
                Container(
                  height: 128,
                  decoration: BoxDecoration(
                    color: previewBackground,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.description_outlined,
                      size: 64,
                      color: previewIconColor,
                    ),
                  ),
                ),
                if (widget.template.isFavorite)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.star,
                      size: 20,
                      color: Color(0xFFEAB308),
                    ),
                  ),
                AnimatedOpacity(
                  opacity: showOverlay ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: IgnorePointer(
                    ignoring: !showOverlay,
                    child: Container(
                      height: 128,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: AnimatedScale(
                          scale: showOverlay ? 1 : 0.9,
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          child: FilledButton(
                            onPressed: widget.onSelect,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF111827),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Use Template'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.template.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.template.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: widget.template.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tagBackground,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 12,
                              color: tagText,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.download_outlined,
                          size: 12,
                          color: secondaryText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.template.downloads.toString(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.star_border,
                          size: 12,
                          color: secondaryText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.template.rating.toStringAsFixed(1),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                        if (lastUsedLabel.isNotEmpty) ...[
                          const Spacer(),
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lastUsedLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateLibraryFooter extends StatelessWidget {
  const _TemplateLibraryFooter({
    required this.count,
    required this.onClose,
  });

  final int count;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3748) : const Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Text(
            '$count template${count == 1 ? '' : 's'} available',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14,
              color:
                  isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onClose,
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.hovered)) {
                  return isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB);
                }
                return Colors.transparent;
              }),
              foregroundColor: MaterialStateProperty.all(
                isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
              ),
              padding: MaterialStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              minimumSize: MaterialStateProperty.all(Size.zero),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _Collaborator {
  const _Collaborator({
    required this.id,
    required this.name,
    required this.color,
    required this.isActive,
    required this.lastSeen,
  });

  final String id;
  final String name;
  final Color color;
  final bool isActive;
  final DateTime lastSeen;
}

class _CollaborativeChange {
  const _CollaborativeChange({
    required this.id,
    required this.userName,
    required this.timestamp,
    required this.type,
    required this.content,
  });

  final String id;
  final String userName;
  final DateTime timestamp;
  final String type;
  final String content;
}

class _CollaborativeEditorSheet extends StatefulWidget {
  const _CollaborativeEditorSheet({required this.document});

  final Document document;

  @override
  State<_CollaborativeEditorSheet> createState() =>
      _CollaborativeEditorSheetState();
}

class _CollaborativeEditorSheetState extends State<_CollaborativeEditorSheet> {
  final TextEditingController _contentController = TextEditingController();
  final List<_CollaborativeChange> _changes = [];
  late final List<_Collaborator> _collaborators;
  Timer? _autoSaveTimer;
  DateTime _lastSaved = DateTime.now();
  bool _showChanges = false;
  bool _showComments = false;
  bool _isSaving = false;
  final bool _isOnline = true;
  bool _hasUnsavedChanges = false;
  static const String _defaultContent = '''
# Safety Manual 2025

## Chapter 1: Introduction

This manual outlines the safety protocols and procedures for all field operations. All employees must familiarize themselves with these guidelines and adhere to them strictly.

## Chapter 2: Personal Protective Equipment (PPE)

### 2.1 Required Equipment
- Hard hats must be worn at all times in designated areas
- Safety glasses are mandatory when operating machinery
- High-visibility vests required in all outdoor work zones

### 2.2 Equipment Inspection
All PPE must be inspected before each use for signs of damage or wear.
''';

  @override
  void initState() {
    super.initState();
    _collaborators = [
      _Collaborator(
        id: '1',
        name: 'Ava Woods',
        color: const Color(0xFF2563EB),
        isActive: true,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      _Collaborator(
        id: '2',
        name: 'Noah Patel',
        color: const Color(0xFF16A34A),
        isActive: true,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      _Collaborator(
        id: '3',
        name: 'Maya Chen',
        color: const Color(0xFFF97316),
        isActive: false,
        lastSeen: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      _Collaborator(
        id: '4',
        name: 'Liam Ortiz',
        color: const Color(0xFF9333EA),
        isActive: false,
        lastSeen: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
    _contentController.text = _defaultContent;
    _autoSaveTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _autoSave());
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _contentController.dispose();
    super.dispose();
  }

  void _toggleChanges() {
    setState(() => _showChanges = !_showChanges);
  }

  void _toggleComments() {
    setState(() => _showComments = !_showComments);
  }

  void _handleContentChanged(String value) {
    setState(() {
      _hasUnsavedChanges = true;
      _changes.add(
        _CollaborativeChange(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userName: 'You',
          timestamp: DateTime.now(),
          type: 'insert',
          content: value.length <= 10 ? value : value.substring(value.length - 10),
        ),
      );
    });
  }

  void _autoSave() {
    if (!_hasUnsavedChanges || _isSaving) return;
    setState(() => _isSaving = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
        _lastSaved = DateTime.now();
      });
    });
  }

  Future<void> _manualSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _hasUnsavedChanges = false;
      _lastSaved = DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document saved successfully!')),
    );
    Navigator.pop(context);
  }

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final activeCollaborators =
        _collaborators.where((collab) => collab.isActive).toList();
    final wordCount = _wordCount(_contentController.text);
    final charCount = _contentController.text.length;
    final showSidebar = _showChanges || _showComments;
    final modalBackground =
        isDark ? const Color(0xFF1F2937) : Colors.white;

    return Material(
      color: modalBackground,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 24,
      child: Column(
        children: [
          _CollaborativeHeader(
            documentName: widget.document.title,
            isOnline: _isOnline,
            isSaving: _isSaving,
            lastSaved: _lastSaved,
            collaborators: activeCollaborators,
            totalCollaborators: activeCollaborators.length,
            showChanges: _showChanges,
            showComments: _showComments,
            changeCount: _changes.length,
            onToggleChanges: _toggleChanges,
            onToggleComments: _toggleComments,
            onSave: _manualSave,
            onClose: () => Navigator.pop(context),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final editor = _CollaborativeEditorBody(
                  controller: _contentController,
                  borderColor: border,
                  isDark: isDark,
                  activeCollaborators: activeCollaborators,
                  onChanged: _handleContentChanged,
                );
                final sidebar = showSidebar
                    ? _CollaborativeSidebar(
                        showChanges: _showChanges,
                        showComments: _showComments,
                        changes: _changes,
                        collaborators: _collaborators,
                        isDark: isDark,
                        timeAgo: _formatTimeAgo,
                      )
                    : null;
                if (sidebar == null) {
                  return editor;
                }
                return Row(
                  children: [
                    Expanded(child: editor),
                    VerticalDivider(width: 1, color: border),
                    SizedBox(width: 320, child: sidebar),
                  ],
                );
              },
            ),
          ),
          _CollaborativeFooter(
            activeCount: activeCollaborators.length,
            viewerCount: _collaborators.length,
            wordCount: wordCount,
            charCount: charCount,
          ),
        ],
      ),
    );
  }
}

class _CollaborativeHeader extends StatelessWidget {
  const _CollaborativeHeader({
    required this.documentName,
    required this.isOnline,
    required this.isSaving,
    required this.lastSaved,
    required this.collaborators,
    required this.totalCollaborators,
    required this.showChanges,
    required this.showComments,
    required this.changeCount,
    required this.onToggleChanges,
    required this.onToggleComments,
    required this.onSave,
    required this.onClose,
  });

  final String documentName;
  final bool isOnline;
  final bool isSaving;
  final DateTime lastSaved;
  final List<_Collaborator> collaborators;
  final int totalCollaborators;
  final bool showChanges;
  final bool showComments;
  final int changeCount;
  final VoidCallback onToggleChanges;
  final VoidCallback onToggleComments;
  final VoidCallback onSave;
  final VoidCallback onClose;

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = isOnline ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final statusIcon = isOnline ? Icons.wifi : Icons.wifi_off;
    final inactiveBackground =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final inactiveHover =
        isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);
    final inactiveForeground =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final savedColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final closeHover =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    const activeBackground = Color(0xFF2563EB);
    const activeHover = Color(0xFF1D4ED8);

    Widget buildToggleButton({
      required bool isActive,
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
    }) {
      return TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (isActive) return activeBackground;
            if (states.contains(MaterialState.hovered)) return inactiveHover;
            return inactiveBackground;
          }),
          foregroundColor: MaterialStateProperty.all(
            isActive ? Colors.white : inactiveForeground,
          ),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          textStyle: MaterialStateProperty.all(
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    final statusSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          documentName,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'Connected' : 'Offline',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule,
                    size: 12, color: savedColor),
                const SizedBox(width: 4),
                Text(
                  isSaving ? 'Saving...' : 'Saved ${_formatTimeAgo(lastSaved)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: savedColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final actionButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        buildToggleButton(
          isActive: showChanges,
          icon: Icons.schedule,
          label: 'Changes ($changeCount)',
          onPressed: onToggleChanges,
        ),
        buildToggleButton(
          isActive: showComments,
          icon: Icons.comment_outlined,
          label: 'Comments',
          onPressed: onToggleComments,
        ),
        FilledButton.icon(
          onPressed: isSaving ? null : onSave,
          icon: const Icon(Icons.save_outlined, size: 16),
          label: Text(isSaving ? 'Saving...' : 'Save'),
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.disabled)) {
                return activeBackground.withValues(alpha: 0.6);
              }
              if (states.contains(MaterialState.hovered)) return activeHover;
              return activeBackground;
            }),
            foregroundColor: MaterialStateProperty.all(Colors.white),
            padding: MaterialStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            textStyle: MaterialStateProperty.all(
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
        InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(8),
          hoverColor: closeHover,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.close,
              size: 20,
              color:
                  isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: statusSection),
                if (collaborators.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _CollaboratorStack(
                    collaborators: collaborators,
                    totalCount: totalCollaborators,
                  ),
                ],
              ],
            ),
          ),
          actionButtons,
        ],
      ),
    );
  }
}

class _CollaboratorStack extends StatelessWidget {
  const _CollaboratorStack({
    required this.collaborators,
    required this.totalCount,
  });

  final List<_Collaborator> collaborators;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final visible = collaborators.take(5).toList();
    const overlap = 24.0;
    final width = visible.isEmpty ? 0.0 : (visible.length - 1) * overlap + 32;
    return Row(
      children: [
        SizedBox(
          width: width,
          height: 32,
          child: Stack(
            children: [
              for (var i = 0; i < visible.length; i++)
                Positioned(
                  left: i * overlap,
                  child: _CollaboratorAvatar(collaborator: visible[i]),
                ),
            ],
          ),
        ),
        if (totalCount > visible.length)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '+${totalCount - visible.length} more',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF4B5563),
                  ),
            ),
          ),
      ],
    );
  }
}

class _CollaboratorAvatar extends StatelessWidget {
  const _CollaboratorAvatar({required this.collaborator});

  final _Collaborator collaborator;

  @override
  Widget build(BuildContext context) {
    final isActive = collaborator.isActive;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: collaborator.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            collaborator.name.substring(0, 1),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (isActive)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF1F2937) : Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CollaborativeEditorBody extends StatelessWidget {
  const _CollaborativeEditorBody({
    required this.controller,
    required this.borderColor,
    required this.isDark,
    required this.activeCollaborators,
    required this.onChanged,
  });

  final TextEditingController controller;
  final Color borderColor;
  final bool isDark;
  final List<_Collaborator> activeCollaborators;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 896, minHeight: 600),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D3748) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.2 : 0.08,
                        ),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration.collapsed(
                        hintText: 'Start typing your document...',
                      ),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.8,
                        fontFamily: 'Georgia',
                        fontSize: 16,
                        color:
                            isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (activeCollaborators.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 896),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '\u{1F465} ${activeCollaborators.map((c) => c.name).join(', ')} ${activeCollaborators.length == 1 ? 'is' : 'are'} currently editing',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CollaborativeSidebar extends StatelessWidget {
  const _CollaborativeSidebar({
    required this.showChanges,
    required this.showComments,
    required this.changes,
    required this.collaborators,
    required this.isDark,
    required this.timeAgo,
  });

  final bool showChanges;
  final bool showComments;
  final List<_CollaborativeChange> changes;
  final List<_Collaborator> collaborators;
  final bool isDark;
  final String Function(DateTime) timeAgo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: isDark ? const Color(0xFF2D3748) : const Color(0xFFF9FAFB),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            showChanges ? 'Recent Changes' : 'Comments',
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          if (showChanges)
            ..._buildChangeCards(theme)
          else if (showComments)
            _buildCommentsPlaceholder(theme),
          if (showChanges && showComments) const SizedBox(height: 16),
          if (showChanges && showComments) _buildCommentsPlaceholder(theme),
        ],
      ),
    );
  }

  List<Widget> _buildChangeCards(ThemeData theme) {
    if (changes.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'No changes yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),
      ];
    }
    final visibleChanges = changes.length > 10
        ? changes.sublist(changes.length - 10)
        : changes;
    return visibleChanges.reversed.map((change) {
          final collaborator = collaborators
              .firstWhere((c) => c.name == change.userName, orElse: () {
            return _Collaborator(
              id: 'local',
              name: 'You',
              color: const Color(0xFF2563EB),
              isActive: true,
              lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
            );
          });
          final action = change.type == 'insert'
              ? 'Added'
              : change.type == 'delete'
                  ? 'Removed'
                  : 'Formatted';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: collaborator.color,
                  child: Text(
                    collaborator.name.substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        change.userName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        timeAgo(change.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$action content',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        })
        .toList();
  }

  Widget _buildCommentsPlaceholder(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final muted =
        isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.comment_outlined,
            size: 48,
            color: muted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No comments yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select text to add a comment',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollaborativeFooter extends StatelessWidget {
  const _CollaborativeFooter({
    required this.activeCount,
    required this.viewerCount,
    required this.wordCount,
    required this.charCount,
  });

  final int activeCount;
  final int viewerCount;
  final int wordCount;
  final int charCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final footerBackground =
        isDark ? const Color(0xFF2D3748) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    const noteColor = Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: footerBackground,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Icon(Icons.people_outline, size: 12, color: mutedColor),
          const SizedBox(width: 4),
          Text(
            '$activeCount active',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: mutedColor,
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.visibility_outlined, size: 12, color: mutedColor),
          const SizedBox(width: 4),
          Text(
            '$viewerCount viewers',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: mutedColor,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$wordCount words \u{2022} $charCount characters',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: mutedColor,
            ),
          ),
          const Spacer(),
          Text(
            'All changes are automatically saved',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: noteColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsListTable extends StatelessWidget {
  const _DocumentsListTable({
    required this.docs,
    required this.onOpen,
    required this.onDownload,
    required this.onShare,
    required this.onDelete,
  });

  final List<_DocumentViewModel> docs;
  final ValueChanged<Document> onOpen;
  final ValueChanged<Document> onDownload;
  final ValueChanged<Document> onShare;
  final ValueChanged<Document> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final downloadColor =
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final shareColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final deleteColor =
        isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
    return Container(
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth =
              constraints.maxWidth < 1000 ? 1000.0 : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF111827).withValues(alpha: 0.5)
                          : const Color(0xFFF9FAFB),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                      border: Border(bottom: BorderSide(color: border)),
                    ),
                    child: Row(
                      children: const [
                        _TableHeader(label: 'Name', flex: 4),
                        _TableHeader(label: 'Type', flex: 2),
                        _TableHeader(label: 'Size', flex: 2),
                        _TableHeader(label: 'Folder', flex: 2),
                        _TableHeader(label: 'Uploaded By', flex: 2),
                        _TableHeader(label: 'Date', flex: 2),
                        _TableHeader(label: 'Views', flex: 1),
                        _TableHeader(label: 'Actions', flex: 2),
                      ],
                    ),
                  ),
                  ...docs.map(
                    (doc) => _DocumentTableRow(
                      doc: doc,
                      border: border,
                      isDark: isDark,
                      onOpen: onOpen,
                      onDownload: onDownload,
                      onShare: onShare,
                      onDelete: onDelete,
                      downloadColor: downloadColor,
                      shareColor: shareColor,
                      deleteColor: deleteColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DocumentGridCard extends StatefulWidget {
  const _DocumentGridCard({
    required this.model,
    required this.onOpen,
    required this.onDownload,
    required this.onShare,
  });

  final _DocumentViewModel model;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  @override
  State<_DocumentGridCard> createState() => _DocumentGridCardState();
}

class _DocumentGridCardState extends State<_DocumentGridCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final downloadColor =
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final shareColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final supportsHover = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final showHoverShadow = supportsHover && _isHovering;
    final showMenuButton = _isHovering;
    final secondaryText =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final secondaryStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 12,
      color: secondaryText,
    );
    final downloadHover = isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
        : const Color(0xFFEFF6FF);
    final shareHover =
        isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: showHoverShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onOpen,
            borderRadius: BorderRadius.circular(12),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DocumentIconBadge(type: widget.model.type),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.model.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color:
                                    isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  widget.model.sizeLabel,
                                  style: secondaryStyle,
                                ),
                                const SizedBox(width: 6),
                                _FolderPill(
                                  label: widget.model.type,
                                  compact: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.model.starred)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.star,
                                size: 16,
                                color: Color(0xFFFBBF24),
                              ),
                            ),
                          AnimatedOpacity(
                            opacity: showMenuButton ? 1 : 0,
                            duration: const Duration(milliseconds: 150),
                            child: IgnorePointer(
                              ignoring: !showMenuButton,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {},
                                  borderRadius: BorderRadius.circular(6),
                                  hoverColor: isDark
                                      ? const Color(0xFF374151)
                                      : const Color(0xFFF3F4F6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.more_vert,
                                      size: 16,
                                      color: isDark
                                          ? const Color(0xFF6B7280)
                                          : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: border),
                  const SizedBox(height: 12),
                  Text(
                    'Uploaded by ${widget.model.uploadedBy}',
                    style: secondaryStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.model.dateLabel,
                    style: secondaryStyle,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.visibility_outlined,
                              size: 12, color: secondaryText),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.model.views} views',
                            style: secondaryStyle,
                          ),
                        ],
                      ),
                      const Spacer(),
                      _InlineIconButton(
                        icon: Icons.download_outlined,
                        color: downloadColor,
                        hoverColor: downloadHover,
                        padding: const EdgeInsets.all(6),
                        onPressed: widget.onDownload,
                      ),
                      _InlineIconButton(
                        icon: Icons.share_outlined,
                        color: shareColor,
                        hoverColor: shareHover,
                        padding: const EdgeInsets.all(6),
                        onPressed: widget.onShare,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentIconBadge extends StatelessWidget {
  const _DocumentIconBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(type);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

IconData _iconForType(String type) {
  switch (type.toLowerCase()) {
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'image':
      return Icons.image_outlined;
    case 'excel':
    case 'csv':
      return Icons.table_chart_outlined;
    case 'word':
      return Icons.description_outlined;
    case 'cad':
      return Icons.architecture_outlined;
    case 'archive':
      return Icons.archive_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

class _FolderCard extends StatefulWidget {
  const _FolderCard({
    required this.folder,
    required this.isSelected,
    required this.onTap,
  });

  final _FolderSummary folder;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<_FolderCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const selectedBorder = Color(0xFF3B82F6);
    final background = widget.isSelected
        ? (isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.2)
            : const Color(0xFFEFF6FF))
        : (isDark ? const Color(0xFF1F2937) : Colors.white);
    final border = widget.isSelected
        ? selectedBorder
        : (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB));
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.folder.emoji,
                          style: const TextStyle(fontSize: 30),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.folder.name,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.folder.count} files',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _FolderPill extends StatelessWidget {
  const _FolderPill({
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final foreground =
        isDark ? Colors.white : const Color(0xFF111827);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        side: BorderSide(color: background),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: theme.textTheme.bodySmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.selected, required this.onChanged});

  final _DocumentsViewMode selected;
  final ValueChanged<_DocumentsViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            icon: Icons.grid_view_outlined,
            isSelected: selected == _DocumentsViewMode.grid,
            onTap: () => onChanged(_DocumentsViewMode.grid),
          ),
          _ToggleButton(
            icon: Icons.view_list_outlined,
            isSelected: selected == _DocumentsViewMode.list,
            onTap: () => onChanged(_DocumentsViewMode.list),
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF374151) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 16,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.6,
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

class _InlineIconButton extends StatelessWidget {
  const _InlineIconButton({
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.onPressed,
    this.padding = const EdgeInsets.all(4),
  });

  final IconData icon;
  final Color color;
  final Color hoverColor;
  final VoidCallback onPressed;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      hoverColor: hoverColor,
      child: Padding(
        padding: padding,
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _ScannedDocument {
  const _ScannedDocument({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

class _ScannedPage {
  const _ScannedPage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

class _DocumentScannerSheet extends StatefulWidget {
  const _DocumentScannerSheet({required this.picker});

  final ImagePicker picker;

  @override
  State<_DocumentScannerSheet> createState() => _DocumentScannerSheetState();
}

class _DocumentScannerSheetState extends State<_DocumentScannerSheet> {
  final List<_ScannedPage> _pages = [];
  _ScannedPage? _preview;
  bool _isProcessing = false;
  bool _saving = false;
  CameraController? _cameraController;
  bool _cameraActive = false;
  bool _cameraStarting = false;
  String? _cameraError;

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  String _fallbackFilename(String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'scan-$timestamp.$extension';
  }

  String _mimeTypeForFilename(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  Future<void> _startCamera() async {
    if (_cameraStarting || _cameraActive) return;
    setState(() {
      _cameraStarting = true;
      _cameraError = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera available');
      }
      final camera = cameras.firstWhere(
        (desc) => desc.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final previous = _cameraController;
      _cameraController = controller;
      await previous?.dispose();
      setState(() {
        _cameraActive = true;
        _cameraStarting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraActive = false;
        _cameraStarting = false;
        _cameraError = 'Unable to access camera. Please check permissions.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cameraError!)),
      );
    }
  }

  Future<void> _stopCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    await controller?.dispose();
    if (!mounted) return;
    setState(() {
      _cameraActive = false;
      _cameraStarting = false;
    });
  }

  Uint8List _enhanceScan(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    const contrast = 1.2;
    const brightness = 10.0;
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final a = pixel.a;
        final nr = _clampColor(((r - 128) * contrast + 128) + brightness);
        final ng = _clampColor(((g - 128) * contrast + 128) + brightness);
        final nb = _clampColor(((b - 128) * contrast + 128) + brightness);
        decoded.setPixelRgba(x, y, nr, ng, nb, a);
      }
    }
    return Uint8List.fromList(img.encodePng(decoded));
  }

  int _clampColor(num value) {
    if (value < 0) return 0;
    if (value > 255) return 255;
    return value.round();
  }

  Future<void> _captureImage() async {
    if (_isProcessing) return;
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final capture = await _cameraController!.takePicture();
      final bytes = await capture.readAsBytes();
      final processed = _enhanceScan(bytes);
      final filename = _fallbackFilename('png');
      if (!mounted) return;
      setState(() {
        _preview = _ScannedPage(
          bytes: processed,
          filename: filename,
          mimeType: 'image/png',
        );
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }

  Future<void> _uploadImages() async {
    try {
      final uploads = await widget.picker.pickMultiImage(imageQuality: 85);
      if (uploads.isEmpty) return;
      final newPages = <_ScannedPage>[];
      for (final file in uploads) {
        final bytes = await file.readAsBytes();
        final filename =
            file.name.isNotEmpty ? file.name : _fallbackFilename('jpg');
        newPages.add(
          _ScannedPage(
            bytes: bytes,
            filename: filename,
            mimeType: _mimeTypeForFilename(filename),
          ),
        );
      }
      if (!mounted) return;
      setState(() => _pages.addAll(newPages));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  void _addPreview() {
    final preview = _preview;
    if (preview == null) return;
    setState(() {
      _pages.add(preview);
      _preview = null;
    });
  }

  void _removePage(int index) {
    setState(() => _pages.removeAt(index));
  }

  Future<_ScannedDocument?> _buildDocument() async {
    if (_pages.isEmpty) return null;
    if (_pages.length == 1) {
      final page = _pages.first;
      return _ScannedDocument(
        bytes: page.bytes,
        filename: page.filename,
        mimeType: page.mimeType,
      );
    }
    final pdf = pw.Document();
    for (final page in _pages) {
      final image = pw.MemoryImage(page.bytes);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    final filename = _fallbackFilename('pdf');
    final bytes = await pdf.save();
    return _ScannedDocument(
      bytes: bytes,
      filename: filename,
      mimeType: 'application/pdf',
    );
  }

  Future<void> _finishScanning() async {
    if (_saving) return;
    if (_preview != null) {
      _addPreview();
    }
    if (_pages.isEmpty) return;
    setState(() => _saving = true);
    final result = await _buildDocument();
    if (!mounted) return;
    await _stopCamera();
    setState(() => _saving = false);
    if (result != null) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final previewBorder =
        isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    final modalBackground =
        isDark ? const Color(0xFF1F2937) : Colors.white;
    final footerBackground =
        isDark ? const Color(0xFF2D3748) : const Color(0xFFF9FAFB);
    final cameraController = _cameraController;
    final cameraReady =
        cameraController != null && cameraController.value.isInitialized;
    final header = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: modalBackground,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Document Scanner',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_pages.length} page${_pages.length == 1 ? '' : 's'} scanned',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () async {
              await _stopCamera();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            borderRadius: BorderRadius.circular(8),
            hoverColor:
                isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.close,
                size: 24,
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      ),
    );

    final buttonTextStyle = theme.textTheme.bodyMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ) ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w500);

    ButtonStyle filledButtonStyle({
      required Color baseColor,
      required Color hoverColor,
      required Color foregroundColor,
      required EdgeInsets padding,
      double radius = 12,
    }) {
      return ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return baseColor.withValues(alpha: 0.6);
          }
          if (states.contains(MaterialState.hovered)) {
            return hoverColor;
          }
          return baseColor;
        }),
        foregroundColor: MaterialStateProperty.all(foregroundColor),
        padding: MaterialStateProperty.all(padding),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
        elevation: MaterialStateProperty.all(0),
        shadowColor: MaterialStateProperty.all(Colors.transparent),
        textStyle: MaterialStateProperty.all(buttonTextStyle),
      );
    }

    final startCameraStyle = filledButtonStyle(
      baseColor: const Color(0xFF2563EB),
      hoverColor: const Color(0xFF1D4ED8),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    );
    final uploadImagesStyle = filledButtonStyle(
      baseColor: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      hoverColor: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
      foregroundColor: isDark ? Colors.white : const Color(0xFF111827),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    );
    final cancelCameraStyle = filledButtonStyle(
      baseColor: const Color(0xFFDC2626),
      hoverColor: const Color(0xFFB91C1C),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 999,
    ).copyWith(
      elevation: MaterialStateProperty.all(6),
      shadowColor:
          MaterialStateProperty.all(Colors.black.withValues(alpha: 0.2)),
    );
    final retakeStyle = filledButtonStyle(
      baseColor: const Color(0xFFDC2626),
      hoverColor: const Color(0xFFB91C1C),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
    final addPageStyle = filledButtonStyle(
      baseColor: const Color(0xFF16A34A),
      hoverColor: const Color(0xFF15803D),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
    final footerSaveStyle = filledButtonStyle(
      baseColor: const Color(0xFF2563EB),
      hoverColor: const Color(0xFF1D4ED8),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      radius: 8,
    );
    final footerCancelStyle = ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.hovered)) {
          return isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
        }
        return Colors.transparent;
      }),
      foregroundColor: MaterialStateProperty.all(
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      ),
      padding: MaterialStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textStyle: MaterialStateProperty.all(buttonTextStyle),
    );

    final preview = Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: previewBorder, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _preview == null
            ? AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _cameraActive
                          ? (cameraReady
                              ? Builder(
                                  builder: (context) {
                                    final previewSize =
                                        cameraController.value.previewSize;
                                    if (previewSize == null) {
                                      return CameraPreview(cameraController);
                                    }
                                    return FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: previewSize.height,
                                        height: previewSize.width,
                                        child: CameraPreview(cameraController),
                                      ),
                                    );
                                  },
                                )
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ))
                          : Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.photo_camera_outlined,
                                    size: 80,
                                    color: isDark
                                        ? const Color(0xFF4B5563)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Ready to scan documents',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: _cameraStarting
                                            ? null
                                            : _startCamera,
                                        style: startCameraStyle,
                                        icon: const Icon(
                                          Icons.photo_camera_outlined,
                                          size: 20,
                                        ),
                                        label: const Text('Start Camera'),
                                      ),
                                      FilledButton.icon(
                                        onPressed: _uploadImages,
                                        style: uploadImagesStyle,
                                        icon: const Icon(
                                          Icons.upload_file,
                                          size: 20,
                                        ),
                                        label: const Text('Upload Images'),
                                      ),
                                    ],
                                  ),
                                  if (_cameraError != null) ...[
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Text(
                                        _cameraError!,
                                        textAlign: TextAlign.center,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          fontSize: 12,
                                          color: const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                    ),
                    if (_cameraActive && cameraReady)
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: _DashedBorder(
                            color: const Color(0xFF3B82F6)
                                .withValues(alpha: 0.5),
                            radius: 8,
                            strokeWidth: 4,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    if (_cameraActive && cameraReady)
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Position document within frame',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_cameraActive && cameraReady)
                      Positioned(
                        bottom: 24,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _isProcessing ? null : _captureImage,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _isProcessing
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Color(0xFF2563EB),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.photo_camera_outlined,
                                          size: 32,
                                          color: Color(0xFF111827),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: _stopCamera,
                              style: cancelCameraStyle,
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              )
            : Stack(
                children: [
                  Image.memory(
                    _preview!.bytes,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                  ),
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => setState(() => _preview = null),
                          style: retakeStyle,
                          icon: const Icon(Icons.rotate_right, size: 20),
                          label: const Text('Retake'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _addPreview,
                          style: addPageStyle,
                          icon: const Icon(Icons.check, size: 20),
                          label: const Text('Add Page'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );

    final tipsTextColor =
        isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    final tips = Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u{1F4F8} Scanning Tips:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: tipsTextColor,
            ),
          ),
          const SizedBox(height: 8),
          _TipLine(
            text: 'Ensure good lighting for best results',
            color: tipsTextColor,
          ),
          _TipLine(
            text: 'Place document on a flat, contrasting surface',
            color: tipsTextColor,
          ),
          _TipLine(
            text: 'Keep camera parallel to the document',
            color: tipsTextColor,
          ),
          _TipLine(
            text: 'Images are automatically enhanced for clarity',
            color: tipsTextColor,
          ),
        ],
      ),
    );

    final pagesList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scanned Pages (${_pages.length})',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark
                ? const Color(0xFFD1D5DB)
                : const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: _pages.isEmpty
              ? Padding(
                  padding:
                      const EdgeInsets.only(top: 32, bottom: 32, right: 8),
                  child: Text(
                    'No pages scanned yet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                )
              : ListView.separated(
                  primary: false,
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(right: 8),
                  itemCount: _pages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return _ScannedPageTile(
                      page: page,
                      index: index,
                      border: previewBorder,
                      onRemove: () => _removePage(index),
                    );
                  },
                ),
        ),
      ],
    );

    final footer = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: footerBackground,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () async {
              await _stopCamera();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: footerCancelStyle,
            child: const Text('Cancel'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _pages.isEmpty || _saving ? null : _finishScanning,
            style: footerSaveStyle,
            child: Text(
              _saving
                  ? 'Saving...'
                  : 'Save ${_pages.length} Page${_pages.length == 1 ? '' : 's'}',
            ),
          ),
        ],
      ),
    );

    return Material(
      color: modalBackground,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 24,
      child: Column(
        children: [
          header,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1024;
                  final content = isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  preview,
                                  tips,
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(child: pagesList),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            preview,
                            tips,
                            const SizedBox(height: 24),
                            pagesList,
                          ],
                        );
                  return SingleChildScrollView(child: content);
                },
              ),
            ),
          ),
          footer,
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u2022',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: color,
                ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannedPageTile extends StatefulWidget {
  const _ScannedPageTile({
    required this.page,
    required this.index,
    required this.border,
    required this.onRemove,
  });

  final _ScannedPage page;
  final int index;
  final Color border;
  final VoidCallback onRemove;

  @override
  State<_ScannedPageTile> createState() => _ScannedPageTileState();
}

class _ScannedPageTileState extends State<_ScannedPageTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final supportsHover = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final showRemove = !supportsHover || _isHovering;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                widget.page.bytes,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Page ${widget.index + 1}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: AnimatedOpacity(
              opacity: showRemove ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: IgnorePointer(
                ignoring: !showRemove,
                child: IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close, size: 16),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith(
                      (states) => states.contains(MaterialState.hovered)
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFFDC2626),
                    ),
                    foregroundColor: MaterialStateProperty.all(Colors.white),
                    padding:
                        MaterialStateProperty.all(const EdgeInsets.all(6)),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AnnotationTool {
  draw,
  highlight,
  text,
  rectangle,
  circle,
  arrow,
  eraser,
}

class _Annotation {
  const _Annotation({
    required this.tool,
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.text,
    this.textSize,
  });

  final _AnnotationTool tool;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final String? text;
  final double? textSize;

  _Annotation copyWith({
    List<Offset>? points,
    String? text,
    double? textSize,
  }) {
    return _Annotation(
      tool: tool,
      points: points ?? this.points,
      color: color,
      strokeWidth: strokeWidth,
      text: text ?? this.text,
      textSize: textSize ?? this.textSize,
    );
  }

  _Annotation clone() {
    return copyWith(points: List<Offset>.from(points));
  }
}

class _DocumentAnnotationSheet extends StatefulWidget {
  const _DocumentAnnotationSheet({
    required this.documentName,
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });

  final String documentName;
  final String filename;
  final String mimeType;
  final Uint8List bytes;

  @override
  State<_DocumentAnnotationSheet> createState() =>
      _DocumentAnnotationSheetState();
}

class _DocumentAnnotationSheetState extends State<_DocumentAnnotationSheet> {
  static const _defaultColors = [
    Color(0xFFFF0000),
    Color(0xFF0066FF),
    Color(0xFF00CC00),
    Color(0xFFFFFF00),
    Color(0xFFFF9900),
    Color(0xFF9900FF),
    Color(0xFF000000),
  ];

  final TextEditingController _textController = TextEditingController();
  final List<_Annotation> _annotations = [];
  final List<List<_Annotation>> _history = [];
  _Annotation? _activeAnnotation;
  _Annotation? _previewAnnotation;
  Offset? _shapeStart;
  Offset? _textPosition;
  int _historyIndex = -1;
  _AnnotationTool _tool = _AnnotationTool.draw;
  Color _currentColor = _defaultColors.first;
  double _lineWidth = 3;
  ui.Image? _image;
  bool _loadingImage = false;
  Size _canvasSize = Size.zero;
  Rect _imageRect = Rect.zero;

  bool get _isImage {
    final lower = widget.filename.toLowerCase();
    return widget.mimeType.startsWith('image/') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  @override
  void initState() {
    super.initState();
    _pushHistory();
    _loadImage();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    if (!_isImage) return;
    setState(() => _loadingImage = true);
    try {
      final image = await _decodeImage(widget.bytes);
      if (!mounted) return;
      setState(() {
        _image = image;
        _loadingImage = false;
      });
    } catch (e, st) {
      developer.log('DocumentsPage load image failed',
          error: e, stackTrace: st, name: 'DocumentsPage._loadImage');
      if (!mounted) return;
      setState(() => _loadingImage = false);
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  Rect _calculateImageRect(Size canvasSize, ui.Image? image) {
    if (image == null) {
      return Offset.zero & canvasSize;
    }
    final imageRatio = image.width / image.height;
    final canvasRatio = canvasSize.width / canvasSize.height;
    double width;
    double height;
    if (canvasRatio > imageRatio) {
      height = canvasSize.height;
      width = height * imageRatio;
    } else {
      width = canvasSize.width;
      height = width / imageRatio;
    }
    final dx = (canvasSize.width - width) / 2;
    final dy = (canvasSize.height - height) / 2;
    return Rect.fromLTWH(dx, dy, width, height);
  }

  Rect _activeRect() {
    if (_canvasSize.isEmpty) return Rect.zero;
    return _imageRect.isEmpty ? Offset.zero & _canvasSize : _imageRect;
  }

  void _pushHistory() {
    final snapshot = _annotations.map((a) => a.clone()).toList();
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(snapshot);
    _historyIndex = _history.length - 1;
  }

  void _undo() {
    if (_historyIndex <= 0) return;
    setState(() {
      _historyIndex -= 1;
      _annotations
        ..clear()
        ..addAll(_history[_historyIndex].map((a) => a.clone()));
      _activeAnnotation = null;
      _previewAnnotation = null;
      _shapeStart = null;
    });
  }

  void _redo() {
    if (_historyIndex >= _history.length - 1) return;
    setState(() {
      _historyIndex += 1;
      _annotations
        ..clear()
        ..addAll(_history[_historyIndex].map((a) => a.clone()));
      _activeAnnotation = null;
      _previewAnnotation = null;
      _shapeStart = null;
    });
  }

  void _setTool(_AnnotationTool tool) {
    setState(() {
      _tool = tool;
      _textPosition = null;
      _textController.clear();
    });
  }

  void _handleTapDown(TapDownDetails details) {
    if (_tool != _AnnotationTool.text) return;
    final rect = _activeRect();
    if (!rect.contains(details.localPosition)) return;
    setState(() {
      _textPosition = details.localPosition;
      _textController.clear();
    });
  }

  void _startStroke(Offset point) {
    _activeAnnotation = _Annotation(
      tool: _tool,
      points: [point],
      color: _currentColor,
      strokeWidth: _lineWidth,
    );
  }

  void _updateStroke(Offset point) {
    final active = _activeAnnotation;
    if (active == null) return;
    setState(() {
      _activeAnnotation = active.copyWith(
        points: [...active.points, point],
      );
    });
  }

  void _endStroke() {
    final active = _activeAnnotation;
    if (active == null) return;
    setState(() {
      _annotations.add(active);
      _activeAnnotation = null;
    });
    _pushHistory();
  }

  void _startShape(Offset point) {
    _shapeStart = point;
    _previewAnnotation = _Annotation(
      tool: _tool,
      points: [point, point],
      color: _currentColor,
      strokeWidth: _lineWidth,
    );
  }

  void _updateShape(Offset point) {
    final start = _shapeStart;
    if (start == null) return;
    setState(() {
      _previewAnnotation = _Annotation(
        tool: _tool,
        points: [start, point],
        color: _currentColor,
        strokeWidth: _lineWidth,
      );
    });
  }

  void _endShape() {
    final preview = _previewAnnotation;
    if (preview == null) return;
    setState(() {
      _annotations.add(preview);
      _previewAnnotation = null;
      _shapeStart = null;
    });
    _pushHistory();
  }

  void _handlePanStart(DragStartDetails details) {
    if (_tool == _AnnotationTool.text) return;
    final rect = _activeRect();
    if (!rect.contains(details.localPosition)) return;
    if (_tool == _AnnotationTool.rectangle ||
        _tool == _AnnotationTool.circle ||
        _tool == _AnnotationTool.arrow) {
      _startShape(details.localPosition);
      setState(() {});
      return;
    }
    _startStroke(details.localPosition);
    setState(() {});
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_tool == _AnnotationTool.text) return;
    final rect = _activeRect();
    if (!rect.contains(details.localPosition)) return;
    if (_tool == _AnnotationTool.rectangle ||
        _tool == _AnnotationTool.circle ||
        _tool == _AnnotationTool.arrow) {
      _updateShape(details.localPosition);
      return;
    }
    _updateStroke(details.localPosition);
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_tool == _AnnotationTool.text) return;
    if (_tool == _AnnotationTool.rectangle ||
        _tool == _AnnotationTool.circle ||
        _tool == _AnnotationTool.arrow) {
      _endShape();
      return;
    }
    _endStroke();
  }

  void _commitText() {
    final text = _textController.text.trim();
    final position = _textPosition;
    if (text.isEmpty || position == null) {
      setState(() => _textPosition = null);
      return;
    }
    final annotation = _Annotation(
      tool: _AnnotationTool.text,
      points: [position],
      color: _currentColor,
      strokeWidth: _lineWidth,
      text: text,
      textSize: _lineWidth * 6,
    );
    setState(() {
      _annotations.add(annotation);
      _textPosition = null;
    });
    _pushHistory();
  }

  Future<Uint8List> _exportAnnotated() async {
    _finalizePending();
    final image = _image;
    final backgroundColor =
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1F2937)
            : Colors.white;
    final placeholderColor =
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF9CA3AF)
            : const Color(0xFF6B7280);
    final outputSize = image != null
        ? Size(image.width.toDouble(), image.height.toDouble())
        : (_canvasSize.isEmpty ? const Size(800, 1100) : _canvasSize);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & outputSize, Paint()..color = backgroundColor);
    if (image != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      canvas.drawImageRect(image, src, Offset.zero & outputSize, Paint());
    } else {
      final textPainter = TextPainter(
        text: TextSpan(
          text: widget.documentName,
          style: TextStyle(
            color: placeholderColor,
            fontSize: 24,
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: outputSize.width - 40);
      textPainter.paint(
        canvas,
        Offset((outputSize.width - textPainter.width) / 2, 50),
      );
      final subtitle = TextPainter(
        text: TextSpan(
          text: 'Document preview - Annotation ready',
          style: TextStyle(
            color: placeholderColor,
            fontSize: 16,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: outputSize.width - 40);
      subtitle.paint(
        canvas,
        Offset((outputSize.width - subtitle.width) / 2, 100),
      );
    }
    final rect = _imageRect.isEmpty
        ? Offset.zero & _canvasSize
        : _imageRect;
    final scaleX =
        outputSize.width / (rect.width == 0 ? outputSize.width : rect.width);
    final scaleY =
        outputSize.height / (rect.height == 0 ? outputSize.height : rect.height);
    final origin = rect.topLeft;
    _paintAnnotations(
      canvas,
      _annotations,
      backgroundColor,
      origin,
      scaleX,
      scaleY,
    );
    final picture = recorder.endRecording();
    final imageOut = await picture.toImage(
      outputSize.width.round(),
      outputSize.height.round(),
    );
    final data =
        await imageOut.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _downloadAnnotated() async {
    final bytes = await _exportAnnotated();
    final name = widget.documentName
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\\-]'), '');
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: 'annotated-$name.png',
          mimeType: 'image/png',
        ),
      ],
    );
  }

  Future<void> _saveAnnotated() async {
    final bytes = await _exportAnnotated();
    if (!mounted) return;
    Navigator.pop(context, bytes);
  }

  void _finalizePending() {
    if (_textPosition != null) {
      _commitText();
    }
    if (_activeAnnotation != null) {
      _annotations.add(_activeAnnotation!);
      _activeAnnotation = null;
      _pushHistory();
    }
    if (_previewAnnotation != null) {
      _annotations.add(_previewAnnotation!);
      _previewAnnotation = null;
      _shapeStart = null;
      _pushHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final chromeColor =
        isDark ? const Color(0xFF2D3748) : const Color(0xFFF9FAFB);
    final separatorColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    final surfaceColor =
        isDark ? const Color(0xFF1F2937) : Colors.white;
    final titleColor =
        isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final pageColor =
        isDark ? const Color(0xFF1F2937) : Colors.white;
    const canvasBorder = Color(0xFF374151);
    final size = MediaQuery.of(context).size;
    final double dialogWidth =
        math.min(size.width * 0.95, 1280).toDouble();
    final dialogHeight = size.height * 0.95;

    final cancelHover =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final cancelForeground =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final buttonTextStyle = theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ) ??
        const TextStyle(fontWeight: FontWeight.w500);
    final cancelStyle = ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith(
        (states) => states.contains(MaterialState.hovered)
            ? cancelHover
            : Colors.transparent,
      ),
      foregroundColor: MaterialStateProperty.all(cancelForeground),
      padding: MaterialStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textStyle: MaterialStateProperty.all(buttonTextStyle),
    );
    ButtonStyle filledStyle({
      required Color baseColor,
      required Color hoverColor,
      required Color foregroundColor,
      required EdgeInsets padding,
      double radius = 8,
    }) {
      return ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return baseColor.withValues(alpha: 0.6);
          }
          if (states.contains(MaterialState.hovered)) {
            return hoverColor;
          }
          return baseColor;
        }),
        foregroundColor: MaterialStateProperty.all(foregroundColor),
        padding: MaterialStateProperty.all(padding),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
        textStyle: MaterialStateProperty.all(buttonTextStyle),
        elevation: MaterialStateProperty.all(0),
        shadowColor: MaterialStateProperty.all(Colors.transparent),
      );
    }
    final downloadStyle = filledStyle(
      baseColor: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      hoverColor: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
      foregroundColor: isDark ? Colors.white : const Color(0xFF111827),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
    final saveStyle = filledStyle(
      baseColor: const Color(0xFF2563EB),
      hoverColor: const Color(0xFF1D4ED8),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );
    final addTextStyle = filledStyle(
      baseColor: const Color(0xFF2563EB),
      hoverColor: const Color(0xFF1D4ED8),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
    final cancelTextStyle = filledStyle(
      baseColor: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      hoverColor: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
      foregroundColor: isDark ? Colors.white : const Color(0xFF111827),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );

    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 24,
      child: SizedBox(
        height: dialogHeight,
        width: dialogWidth,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Annotate Document',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.documentName,
                          style: TextStyle(
                            fontSize: 14,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: isDark
                        ? const Color(0xFF374151)
                        : const Color(0xFFF3F4F6),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.close,
                        size: 24,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: chromeColor,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _AnnotationToolButton(
                      icon: Icons.edit_outlined,
                      label: 'Draw',
                      isSelected: _tool == _AnnotationTool.draw,
                      onTap: () => _setTool(_AnnotationTool.draw),
                    ),
                    _AnnotationToolButton(
                      icon: Icons.highlight_outlined,
                      label: 'Highlight',
                      isSelected: _tool == _AnnotationTool.highlight,
                      onTap: () => _setTool(_AnnotationTool.highlight),
                    ),
                    _AnnotationToolButton(
                      icon: Icons.text_fields_outlined,
                      label: 'Text',
                      isSelected: _tool == _AnnotationTool.text,
                      onTap: () => _setTool(_AnnotationTool.text),
                    ),
                    _AnnotationToolButton(
                      icon: Icons.crop_square_outlined,
                      label: 'Rectangle',
                      isSelected: _tool == _AnnotationTool.rectangle,
                      onTap: () => _setTool(_AnnotationTool.rectangle),
                    ),
                    _AnnotationToolButton(
                      icon: Icons.circle_outlined,
                      label: 'Circle',
                      isSelected: _tool == _AnnotationTool.circle,
                      onTap: () => _setTool(_AnnotationTool.circle),
                    ),
                    _AnnotationToolButton(
                      icon: Icons.arrow_right_alt_outlined,
                      label: 'Arrow',
                      isSelected: _tool == _AnnotationTool.arrow,
                      onTap: () => _setTool(_AnnotationTool.arrow),
                    ),
                    _AnnotationToolButton(
                      icon: Icons.cleaning_services_outlined,
                      label: 'Eraser',
                      isSelected: _tool == _AnnotationTool.eraser,
                      onTap: () => _setTool(_AnnotationTool.eraser),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 32,
                      color: separatorColor,
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: _defaultColors
                          .map(
                            (color) => _ColorDot(
                              color: color,
                              isSelected: _currentColor == color,
                              onTap: () => setState(() => _currentColor = color),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 32,
                      color: separatorColor,
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Text(
                          'Size:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 96,
                          child: Slider(
                            value: _lineWidth,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: _lineWidth.toStringAsFixed(0),
                            onChanged: (value) =>
                                setState(() => _lineWidth = value),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _lineWidth.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    _AnnotationActionButton(
                      icon: Icons.undo,
                      label: 'Undo',
                      enabled: _historyIndex > 0,
                      onTap: _undo,
                    ),
                    _AnnotationActionButton(
                      icon: Icons.redo,
                      label: 'Redo',
                      enabled: _historyIndex < _history.length - 1,
                      onTap: _redo,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFF111827),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 896),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double canvasWidth = constraints.maxWidth;
                              final baseSize = _image != null
                                  ? Size(
                                      _image!.width.toDouble(),
                                      _image!.height.toDouble(),
                                    )
                                  : const Size(800, 1100);
                              final double canvasHeight = canvasWidth == 0
                                  ? 0.0
                                  : baseSize.height *
                                      (canvasWidth / baseSize.width);
                              _canvasSize = Size(canvasWidth, canvasHeight);
                              _imageRect =
                                  _calculateImageRect(_canvasSize, _image);
                              final rect = _activeRect();

                              return SizedBox(
                                width: canvasWidth,
                                height: canvasHeight,
                                child: IgnorePointer(
                                  ignoring: _textPosition != null,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.precise,
                                    child: GestureDetector(
                                      onTapDown: _handleTapDown,
                                      onPanStart: _handlePanStart,
                                      onPanUpdate: _handlePanUpdate,
                                      onPanEnd: _handlePanEnd,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF111827),
                                          border: Border.all(
                                            color: canvasBorder,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 40,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: CustomPaint(
                                          painter: _AnnotationPainter(
                                            image: _image,
                                            imageRect: rect,
                                            annotations: _annotations,
                                            active: _activeAnnotation,
                                            preview: _previewAnnotation,
                                            backgroundColor:
                                                const Color(0xFF111827),
                                            pageColor: pageColor,
                                            documentName: widget.documentName,
                                            placeholderTextColor: subtitleColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_loadingImage)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: chromeColor,
                border: Border(top: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: cancelStyle,
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _downloadAnnotated,
                    icon: const Icon(Icons.download_outlined, size: 20),
                    label: const Text('Download'),
                    style: downloadStyle,
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _saveAnnotated,
                    icon: const Icon(Icons.save_outlined, size: 20),
                    label: const Text('Save Annotations'),
                    style: saveStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_textPosition != null)
          Center(
            child: Material(
              elevation: 24,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: surfaceColor,
                  border: Border.all(color: border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter text:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFFD1D5DB)
                            : const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Type your annotation...',
                              isDense: true,
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF111827)
                                  : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              hintStyle: TextStyle(
                                color: isDark
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF6B7280),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF374151)
                                      : const Color(0xFFD1D5DB),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF3B82F6),
                                  width: 2,
                                ),
                              ),
                            ),
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                            onSubmitted: (_) => _commitText(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _commitText,
                          style: addTextStyle,
                          child: const Text('Add'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => setState(() {
                            _textPosition = null;
                            _textController.clear();
                          }),
                          style: cancelTextStyle,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  void _paintAnnotations(
    Canvas canvas,
    List<_Annotation> annotations,
    Color eraserColor,
    Offset origin,
    double scaleX,
    double scaleY,
  ) {
    for (final annotation in annotations) {
      _drawAnnotation(
        canvas,
        annotation,
        eraserColor,
        origin,
        scaleX,
        scaleY,
      );
    }
  }

  void _drawAnnotation(
    Canvas canvas,
    _Annotation annotation,
    Color eraserColor,
    Offset origin,
    double scaleX,
    double scaleY,
  ) {
    final points = annotation.points
        .map(
          (p) => Offset(
            (p.dx - origin.dx) * scaleX,
            (p.dy - origin.dy) * scaleY,
          ),
        )
        .toList();
    final baseStroke =
        annotation.strokeWidth * ((scaleX + scaleY) / 2);
    final paint = Paint()
      ..color = annotation.color
      ..strokeWidth = baseStroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (annotation.tool) {
      case _AnnotationTool.draw:
        _drawStroke(canvas, points, paint);
        break;
      case _AnnotationTool.highlight:
        paint
          ..color = annotation.color.withValues(alpha: 0.3)
          ..strokeWidth = baseStroke * 4;
        _drawStroke(canvas, points, paint);
        break;
      case _AnnotationTool.eraser:
        paint
          ..color = eraserColor
          ..strokeWidth = baseStroke * 3;
        _drawStroke(canvas, points, paint);
        break;
      case _AnnotationTool.rectangle:
        if (points.length < 2) return;
        final rect = Rect.fromPoints(points.first, points.last);
        canvas.drawRect(rect, paint);
        break;
      case _AnnotationTool.circle:
        if (points.length < 2) return;
        final radius = (points.last - points.first).distance;
        canvas.drawCircle(points.first, radius, paint);
        break;
      case _AnnotationTool.arrow:
        if (points.length < 2) return;
        _drawArrow(canvas, points.first, points.last, paint);
        break;
      case _AnnotationTool.text:
        if (annotation.text == null || points.isEmpty) return;
        final textPainter = TextPainter(
          text: TextSpan(
            text: annotation.text,
            style: TextStyle(
              color: annotation.color,
              fontSize: (annotation.textSize ?? 14) * ((scaleX + scaleY) / 2),
              fontWeight: FontWeight.w400,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, points.first);
        break;
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(points.first, paint.strokeWidth / 2, paint);
      return;
    }
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  void _drawArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    canvas.drawLine(start, end, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final arrowSize = 10 + paint.strokeWidth;
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle - math.pi / 6),
        end.dy - arrowSize * math.sin(angle - math.pi / 6),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle + math.pi / 6),
        end.dy - arrowSize * math.sin(angle + math.pi / 6),
      );
    canvas.drawPath(path, paint);
  }
}

class _AnnotationPainter extends CustomPainter {
  _AnnotationPainter({
    required this.image,
    required this.imageRect,
    required this.annotations,
    required this.active,
    required this.preview,
    required this.backgroundColor,
    required this.pageColor,
    required this.documentName,
    required this.placeholderTextColor,
  });

  final ui.Image? image;
  final Rect imageRect;
  final List<_Annotation> annotations;
  final _Annotation? active;
  final _Annotation? preview;
  final Color backgroundColor;
  final Color pageColor;
  final String documentName;
  final Color placeholderTextColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    final rect = imageRect.isEmpty ? Offset.zero & size : imageRect;
    if (image != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        image!.width.toDouble(),
        image!.height.toDouble(),
      );
      canvas.drawImageRect(image!, src, rect, Paint());
    } else {
      final pagePaint = Paint()..color = pageColor;
      canvas.drawRect(rect, pagePaint);
      final textPainter = TextPainter(
        text: TextSpan(
          text: documentName,
          style: TextStyle(
            color: placeholderTextColor,
            fontSize: 24,
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: rect.width - 40);
      textPainter.paint(
        canvas,
        Offset(
          rect.center.dx - textPainter.width / 2,
          rect.top + 50,
        ),
      );
      final subtitle = TextPainter(
        text: TextSpan(
          text: 'Document preview - Annotation ready',
          style: TextStyle(
            color: placeholderTextColor,
            fontSize: 16,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: rect.width - 40);
      subtitle.paint(
        canvas,
        Offset(
          rect.center.dx - subtitle.width / 2,
          rect.top + 100,
        ),
      );
    }

    canvas.save();
    canvas.clipRect(rect);
    final allAnnotations = [
      ...annotations,
      if (active != null) active!,
      if (preview != null) preview!,
    ];
    final eraserColor = pageColor;
    for (final annotation in allAnnotations) {
      _drawAnnotation(canvas, annotation, eraserColor);
    }
    canvas.restore();
  }

  void _drawAnnotation(Canvas canvas, _Annotation annotation, Color eraserColor) {
    final points = annotation.points;
    final paint = Paint()
      ..color = annotation.color
      ..strokeWidth = annotation.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (annotation.tool) {
      case _AnnotationTool.draw:
        _drawStroke(canvas, points, paint);
        break;
      case _AnnotationTool.highlight:
        paint
          ..color = annotation.color.withValues(alpha: 0.3)
          ..strokeWidth = annotation.strokeWidth * 4;
        _drawStroke(canvas, points, paint);
        break;
      case _AnnotationTool.eraser:
        paint
          ..color = eraserColor
          ..strokeWidth = annotation.strokeWidth * 3;
        _drawStroke(canvas, points, paint);
        break;
      case _AnnotationTool.rectangle:
        if (points.length < 2) return;
        final rect = Rect.fromPoints(points.first, points.last);
        canvas.drawRect(rect, paint);
        break;
      case _AnnotationTool.circle:
        if (points.length < 2) return;
        final radius = (points.last - points.first).distance;
        canvas.drawCircle(points.first, radius, paint);
        break;
      case _AnnotationTool.arrow:
        if (points.length < 2) return;
        _drawArrow(canvas, points.first, points.last, paint);
        break;
      case _AnnotationTool.text:
        if (annotation.text == null || points.isEmpty) return;
        final textPainter = TextPainter(
          text: TextSpan(
            text: annotation.text,
            style: TextStyle(
              color: annotation.color,
              fontSize: annotation.textSize ?? 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, points.first);
        break;
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(points.first, paint.strokeWidth / 2, paint);
      return;
    }
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final arrowSize = 10 + paint.strokeWidth;
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle - math.pi / 6),
        end.dy - arrowSize * math.sin(angle - math.pi / 6),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle + math.pi / 6),
        end.dy - arrowSize * math.sin(angle + math.pi / 6),
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    return true;
  }
}

class _AnnotationToolButton extends StatelessWidget {
  const _AnnotationToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isSelected
        ? const Color(0xFF2563EB)
        : (isDark ? const Color(0xFF1F2937) : Colors.white);
    final color = isSelected
        ? Colors.white
        : (isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151));
    final hoverColor = isSelected
        ? Colors.white.withValues(alpha: 0.12)
        : (isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6));
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: hoverColor,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

class _AnnotationActionButton extends StatelessWidget {
  const _AnnotationActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    final color = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final hoverColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(8),
            hoverColor: hoverColor,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : Colors.transparent,
              width: 2,
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
    this.strokeWidth = 2,
  });

  final Color color;
  final double radius;
  final Widget child;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

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
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _SignatureRequirement {
  const _SignatureRequirement({
    required this.role,
    this.name,
    this.email,
  });

  final String role;
  final String? name;
  final String? email;
}

class _SignatureCollectionSheet extends ConsumerStatefulWidget {
  const _SignatureCollectionSheet({required this.document});

  final Document document;

  @override
  ConsumerState<_SignatureCollectionSheet> createState() =>
      _SignatureCollectionSheetState();
}

class _SignatureCollectionSheetState
    extends ConsumerState<_SignatureCollectionSheet> {
  late Document _document;
  late final List<_SignatureRequirement> _requirements;
  final DrawingController _controller =
      DrawingController(color: Colors.black, strokeWidth: 2);
  static const _signatureBucketName = String.fromEnvironment(
    'SUPABASE_BUCKET',
    defaultValue: 'formbridge-attachments',
  );
  final Map<String, Future<String?>> _signatureUrlCache = {};
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  Size _canvasSize = const Size(300, 160);
  int _currentIndex = 0;
  int _capturedCount = 0;
  bool _saving = false;
  bool _hasSignature = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleDrawingChange);
    _nameController.addListener(_handleFieldChange);
    _emailController.addListener(_handleFieldChange);
    _document = widget.document;
    _requirements = _loadRequirements();
    _capturedCount = _existingSignatures().length;
    if (_requirements.isNotEmpty) {
      _currentIndex =
          _capturedCount.clamp(0, _requirements.length - 1).toInt();
    }
    _seedFields();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleDrawingChange);
    _nameController.removeListener(_handleFieldChange);
    _emailController.removeListener(_handleFieldChange);
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  List<_SignatureRequirement> _loadRequirements() {
    final raw = _document.metadata?['requiredSignatures'];
    if (raw is List) {
      return raw
          .map((entry) {
            final map = entry is Map<String, dynamic>
                ? entry
                : Map<String, dynamic>.from(entry as Map);
            return _SignatureRequirement(
              role: map['role']?.toString() ?? 'Signer',
              name: map['name']?.toString(),
              email: map['email']?.toString(),
            );
          })
          .toList()
          .cast<_SignatureRequirement>();
    }
    return const [
      _SignatureRequirement(role: 'Project Manager'),
      _SignatureRequirement(role: 'Safety Officer'),
      _SignatureRequirement(role: 'Client Representative'),
    ];
  }

  void _seedFields() {
    if (_requirements.isEmpty || _currentIndex >= _requirements.length) return;
    final current = _requirements[_currentIndex];
    _nameController.text = current.name ?? '';
    _emailController.text = current.email ?? '';
  }

  bool get _isComplete {
    if (_requirements.isEmpty) return true;
    final signatures = _signaturesFromMetadata(_document.metadata);
    return signatures.length >= _requirements.length;
  }

  void _handleDrawingChange() {
    final hasSignature = _controller.strokes.isNotEmpty;
    if (hasSignature == _hasSignature) return;
    if (!mounted) return;
    setState(() => _hasSignature = hasSignature);
  }

  void _handleFieldChange() {
    if (!mounted) return;
    setState(() {});
  }

  Future<Map<String, dynamic>?> _captureLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      return {
        'lat': position.latitude,
        'lng': position.longitude,
        'address': 'Location captured',
      };
    } catch (e, st) {
      developer.log('DocumentsPage capture location failed',
          error: e, stackTrace: st, name: 'DocumentsPage._captureLocation');
      return null;
    }
  }

  List<Map<String, dynamic>> _existingSignatures() {
    final raw = _document.metadata?['signatures'];
    if (raw is! List) return const [];
    return raw
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  List<DocumentSignature> _parsedSignatures() {
    return _signaturesFromMetadata(_document.metadata);
  }

  List<DocumentSignature> _signaturesFromMetadata(
    Map<String, dynamic>? metadata,
  ) {
    final raw = metadata?['signatures'];
    if (raw is! List) return const [];
    return raw
        .map((entry) => DocumentSignature.fromJson(
            Map<String, dynamic>.from(entry as Map)))
        .toList();
  }

  Future<String?> _signatureImageUrl(DocumentSignature signature) {
    final url = signature.url;
    if (url.startsWith('http')) return Future.value(url);
    final cacheKey = signature.storagePath ?? url;
    return _signatureUrlCache.putIfAbsent(cacheKey, () async {
      return createSignedStorageUrl(
        client: Supabase.instance.client,
        url: url,
        defaultBucket: signature.bucket ?? _signatureBucketName,
        metadata: {
          'storagePath': signature.storagePath,
          'bucket': signature.bucket,
        },
      );
    });
  }

  Future<ui.Image?> _loadSignatureImage(String url) async {
    try {
      final data = await NetworkAssetBundle(Uri.parse(url)).load(url);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(
        data.buffer.asUint8List(),
        completer.complete,
      );
      return completer.future;
    } catch (e, st) {
      developer.log('DocumentsPage decode image failed',
          error: e, stackTrace: st, name: 'DocumentsPage._decodeImage');
      return null;
    }
  }

  Future<void> _downloadSignatureCertificate(DocumentSignature signature) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final signedUrl = await _signatureImageUrl(signature);
    final signatureImage =
        signedUrl == null ? null : await _loadSignatureImage(signedUrl);
    final bytes = await _buildSignatureCertificate(
      signature: signature,
      signatureImage: signatureImage,
      isDark: isDark,
    );
    final name = (signature.signerName ?? 'signature')
        .replaceAll(' ', '-')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: 'signature-certificate-$name.png',
          mimeType: 'image/png',
        ),
      ],
    );
  }

  Future<Uint8List> _buildSignatureCertificate({
    required DocumentSignature signature,
    required ui.Image? signatureImage,
    required bool isDark,
  }) async {
    const size = Size(800, 600);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final backgroundColor =
        isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = backgroundColor,
    );

    final title = TextPainter(
      text: TextSpan(
        text: 'Digital Signature Certificate',
        style: TextStyle(
          color: textColor,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);
    title.paint(
      canvas,
      Offset((size.width - title.width) / 2, 40),
    );

    final detailStyle = TextStyle(
      color: textColor,
      fontSize: 16,
      fontWeight: FontWeight.w400,
    );

    void drawLine(String text, double y) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: detailStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: size.width - 100);
      painter.paint(canvas, Offset(50, y));
    }

    drawLine('Document: ${widget.document.title}', 120);
    drawLine('Signer: ${signature.signerName ?? 'Unknown'}', 160);
    drawLine('Role: ${signature.signerRole ?? 'Signer'}', 200);
    drawLine(
      'Date: ${DateFormat.yMd().add_jm().format(signature.signedAt)}',
      240,
    );
    drawLine('Email: ${signature.signerEmail ?? 'Unavailable'}', 280);

    if (signatureImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        signatureImage.width.toDouble(),
        signatureImage.height.toDouble(),
      );
      const dest = Rect.fromLTWH(50, 320, 300, 150);
      canvas.drawImageRect(signatureImage, src, dest, Paint());
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.round(), size.height.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _saveSignature() async {
    if (_requirements.isEmpty ||
        _saving ||
        _currentIndex >= _requirements.length) {
      return;
    }
    if (!_hasSignature || _controller.strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature is required')),
      );
      return;
    }
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and email are required')),
      );
      return;
    }
    setState(() => _saving = true);
    final bytes = await renderDrawingToPng(
      size: _canvasSize,
      strokes: _controller.strokes,
      backgroundColor: Colors.transparent,
    );
    final location = await _captureLocation();
    final repo = ref.read(documentsRepositoryProvider);
    try {
      final updated = await repo.addSignature(
        document: _document,
        bytes: bytes,
        signerName: name,
        signerEmail: email,
        signerRole: _requirements[_currentIndex].role,
        location: location,
      );
      ref.invalidate(documentsProvider(widget.document.projectId));
      if (!mounted) return;
      final updatedSignatures = _signaturesFromMetadata(updated.metadata);
      final nextIndex = _currentIndex + 1;
      setState(() {
        _document = updated;
        _capturedCount = updatedSignatures.length;
        _controller.clear();
        _hasSignature = false;
        _currentIndex =
            nextIndex < _requirements.length ? nextIndex : _requirements.length;
        _saving = false;
      });
      _seedFields();
      if (_currentIndex >= _requirements.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All signatures captured.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signature saved.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signature save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final signatures = _parsedSignatures();
    final penColor = isDark ? Colors.white : Colors.black;
    if (_controller.color != penColor) {
      _controller.color = penColor;
    }
    if (_controller.strokeWidth != 2) {
      _controller.strokeWidth = 2;
    }
    final signatureCount = signatures.length;
    final progress = _requirements.isEmpty
        ? 0.0
        : (signatureCount / _requirements.length).clamp(0.0, 1.0);
    final canSubmit = !_saving &&
        _hasSignature &&
        _nameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty;
    final hasRequirements = _requirements.isNotEmpty;
    final isLastStep =
        hasRequirements && _currentIndex == _requirements.length - 1;
    final modalBackground =
        isDark ? const Color(0xFF1F2937) : Colors.white;
    final chromeColor =
        isDark ? const Color(0xFF2D3748) : const Color(0xFFF9FAFB);
    final titleColor =
        isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final progressLabelColor =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final progressValueColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cancelForeground =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final cancelHover =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final closeHover =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final buttonTextStyle = theme.textTheme.bodyMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ) ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w500);
    final cancelStyle = ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith(
        (states) => states.contains(MaterialState.hovered)
            ? cancelHover
            : Colors.transparent,
      ),
      foregroundColor: MaterialStateProperty.all(cancelForeground),
      padding: MaterialStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textStyle: MaterialStateProperty.all(buttonTextStyle),
    );
    ButtonStyle filledStyle({
      required Color baseColor,
      required Color hoverColor,
      required Color foregroundColor,
      required EdgeInsets padding,
      double radius = 8,
    }) {
      return ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return baseColor.withValues(alpha: 0.6);
          }
          if (states.contains(MaterialState.hovered)) {
            return hoverColor;
          }
          return baseColor;
        }),
        foregroundColor: MaterialStateProperty.all(foregroundColor),
        padding: MaterialStateProperty.all(padding),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
        textStyle: MaterialStateProperty.all(buttonTextStyle),
        elevation: MaterialStateProperty.all(0),
        shadowColor: MaterialStateProperty.all(Colors.transparent),
      );
    }
    final nextStyle = filledStyle(
      baseColor: const Color(0xFF2563EB),
      hoverColor: const Color(0xFF1D4ED8),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );
    final finalizeStyle = filledStyle(
      baseColor: const Color(0xFF16A34A),
      hoverColor: const Color(0xFF15803D),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );

    return Material(
      color: modalBackground,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 24,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: modalBackground,
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Signature Collection',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.document.title,
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  hoverColor: closeHover,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      size: 24,
                      color: subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: chromeColor,
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Signature Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: progressLabelColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$signatureCount of ${_requirements.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: progressValueColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? const Color(0xFF374151)
                        : const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fieldBorder = OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFD1D5DB),
                    ),
                  );
                  final focusedBorder = OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 2,
                    ),
                  );
                  final labelColor = isDark
                      ? const Color(0xFFD1D5DB)
                      : const Color(0xFF374151);
                  final secondaryText = isDark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF6B7280);
                  final clearSignatureStyle = ButtonStyle(
                    foregroundColor:
                        MaterialStateProperty.resolveWith((states) {
                      if (!_hasSignature) return secondaryText;
                      return isDark
                          ? const Color(0xFFF87171)
                          : const Color(0xFFDC2626);
                    }),
                    backgroundColor:
                        MaterialStateProperty.resolveWith((states) {
                      if (!_hasSignature) return Colors.transparent;
                      if (states.contains(MaterialState.hovered)) {
                        return isDark
                            ? const Color(0xFF7F1D1D)
                                .withValues(alpha: 0.3)
                            : const Color(0xFFFEF2F2);
                      }
                      return Colors.transparent;
                    }),
                    padding: MaterialStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    textStyle: MaterialStateProperty.all(
                      const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );

                  if (_isComplete) {
                    Widget buildSignatureCard(DocumentSignature signature) {
                      final name =
                          signature.signerName?.trim().isNotEmpty == true
                              ? signature.signerName!
                              : 'Unknown signer';
                      final role = signature.signerRole?.trim();
                      final email = signature.signerEmail?.trim();
                      final hasLocation = signature.location != null;
                      final detailParts = [
                        if (role != null && role.isNotEmpty) role,
                        if (email != null && email.isNotEmpty) email,
                      ];
                      final detailLine = detailParts.isEmpty
                          ? 'Signer'
                          : detailParts.join(' \u{2022} ');

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2D3748)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
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
                                        name,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        detailLine,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontSize: 14,
                                          color: secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () =>
                                      _downloadSignatureCertificate(signature),
                                  borderRadius: BorderRadius.circular(8),
                                  hoverColor: closeHover,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.download_outlined,
                                      size: 20,
                                      color: secondaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<String?>(
                              future: _signatureImageUrl(signature),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return SizedBox(
                                    height: 64,
                                    child: Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            secondaryText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final url = snapshot.data;
                                if (url == null) {
                                  return Container(
                                    height: 64,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: border),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Signature unavailable',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontSize: 14,
                                        color: secondaryText,
                                      ),
                                    ),
                                  );
                                }
                                return Container(
                                  height: 64,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: border),
                                  ),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) {
                                      return Center(
                                        child: Text(
                                          'Signature unavailable',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontSize: 14,
                                            color: secondaryText,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 12,
                                        color: secondaryText,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          DateFormat.yMd()
                                              .add_jm()
                                              .format(signature.signedAt),
                                          style:
                                              theme.textTheme.bodySmall?.copyWith(
                                            fontSize: 12,
                                            color: secondaryText,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (hasLocation)
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 12,
                                          color: secondaryText,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Location verified',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontSize: 12,
                                              color: secondaryText,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF064E3B)
                                    .withValues(alpha: 0.2)
                                : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF047857)
                                      .withValues(alpha: 0.5)
                                  : const Color(0xFFBBF7D0),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check,
                                size: 64,
                                color: isDark
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFF16A34A),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'All Signatures Collected!',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${signatures.length} signature${signatures.length == 1 ? '' : 's'} successfully captured',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 16,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (final signature in signatures) ...[
                          buildSignatureCard(signature),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }

                  final current = _requirements[_currentIndex];
                  final isWide = constraints.maxWidth >= 768;

                  Widget buildField({
                    required String label,
                    required IconData icon,
                    required TextEditingController controller,
                    required String hintText,
                    TextInputType? keyboardType,
                  }) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, size: 16, color: labelColor),
                            const SizedBox(width: 6),
                            Text.rich(
                              TextSpan(
                                text: label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: labelColor,
                                ),
                                children: const [
                                  TextSpan(
                                    text: ' *',
                                    style: TextStyle(color: Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: controller,
                          keyboardType: keyboardType,
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: TextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? const Color(0xFF6B7280)
                                  : const Color(0xFF9CA3AF),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF111827)
                                : Colors.white,
                            border: fieldBorder,
                            enabledBorder: fieldBorder,
                            focusedBorder: focusedBorder,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 16,
                            color:
                                isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                      ],
                    );
                  }

                        final signaturePad = LayoutBuilder(
                          builder: (context, padConstraints) {
                            final width = padConstraints.maxWidth;
                            const height = 250.0;
                            _canvasSize = Size(width, height);
                            return _DashedBorder(
                              color: isDark
                                  ? const Color(0xFF4B5563)
                                  : const Color(0xFFD1D5DB),
                              radius: 12,
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: DrawingBoard(
                                        controller: _controller,
                                        backgroundColor: isDark
                                            ? const Color(0xFF111827)
                                            : Colors.white,
                                      ),
                                    ),
                                    if (!_hasSignature)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.edit_outlined,
                                                size: 48,
                                                color: isDark
                                                    ? const Color(0xFF4B5563)
                                                    : const Color(0xFF9CA3AF),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Sign here with mouse or touch',
                                                style: theme.textTheme.bodyMedium
                                                    ?.copyWith(
                                                  fontSize: 14,
                                                  color: isDark
                                                      ? const Color(0xFF6B7280)
                                                      : const Color(0xFF9CA3AF),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E3A8A)
                                        .withValues(alpha: 0.2)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF1D4ED8)
                                          .withValues(alpha: 0.5)
                                      : const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Requesting signature from:',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? const Color(0xFF93C5FD)
                                          : const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    current.role,
                                    style:
                                        theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: buildField(
                                      label: 'Full Name',
                                      icon: Icons.person_outline,
                                      controller: _nameController,
                                      hintText: 'Enter your full name',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: buildField(
                                      label: 'Email Address',
                                      icon: Icons.mail_outline,
                                      controller: _emailController,
                                      hintText: 'Enter your email',
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildField(
                                    label: 'Full Name',
                                    icon: Icons.person_outline,
                                    controller: _nameController,
                                    hintText: 'Enter your full name',
                                  ),
                                  const SizedBox(height: 12),
                                  buildField(
                                    label: 'Email Address',
                                    icon: Icons.mail_outline,
                                    controller: _emailController,
                                    hintText: 'Enter your email',
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: 16, color: labelColor),
                                const SizedBox(width: 6),
                                Text.rich(
                                  TextSpan(
                                    text: 'Digital Signature',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: labelColor,
                                    ),
                                    children: const [
                                      TextSpan(
                                        text: ' *',
                                        style:
                                            TextStyle(color: Color(0xFFEF4444)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            signaturePad,
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    _hasSignature ? _controller.clear : null,
                                style: clearSignatureStyle,
                                child: const Text('Clear Signature'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF78350F)
                                        .withValues(alpha: 0.3)
                                    : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '\u{2696}\u{FE0F} Legal Acknowledgment:',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? const Color(0xFFFCD34D)
                                          : const Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'By signing this document, you acknowledge that your signature is legally binding and will be associated with your name, email, IP address, timestamp, and location data.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: isDark
                                          ? const Color(0xFFFCD34D)
                                          : const Color(0xFF92400E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: chromeColor,
              border: Border(top: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: cancelStyle,
                  child: Text(_isComplete ? 'Close' : 'Cancel'),
                ),
                const Spacer(),
                _isComplete
                    ? FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: finalizeStyle,
                        child: const Text('Finalize Document'),
                      )
                    : FilledButton.icon(
                        onPressed: canSubmit ? _saveSignature : null,
                        icon: const Icon(Icons.check, size: 20),
                        label: Text(
                          isLastStep ? 'Complete' : 'Next Signature',
                        ),
                        style: nextStyle,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentVersionControlSheet extends ConsumerStatefulWidget {
  const _DocumentVersionControlSheet({
    required this.document,
    required this.onClose,
    required this.onDownload,
    required this.onRestore,
  });

  final Document document;
  final VoidCallback onClose;
  final ValueChanged<DocumentVersion> onDownload;
  final ValueChanged<DocumentVersion> onRestore;

  @override
  ConsumerState<_DocumentVersionControlSheet> createState() =>
      _DocumentVersionControlSheetState();
}

class _DocumentVersionControlSheetState
    extends ConsumerState<_DocumentVersionControlSheet> {
  String? _selectedVersionId;
  String? _hoveredVersionId;

  String _formatRelative(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    return DateFormat.yMd().format(timestamp);
  }

  String _formatBytes(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var suffixIndex = 0;
    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
  }

  Color _versionBadgeColor(String version, bool isCurrent) {
    if (isCurrent) return const Color(0xFF16A34A);
    if (version.startsWith('1.')) return const Color(0xFF2563EB);
    if (version.startsWith('2.')) return const Color(0xFF16A34A);
    if (version.startsWith('3.')) return const Color(0xFF7C3AED);
    return const Color(0xFF6B7280);
  }

  String _changesForVersion(DocumentVersion version) {
    final raw = version.metadata?['changes'] ?? version.metadata?['notes'];
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) {
      return 'Updated document version.';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final modalBackground =
        isDark ? const Color(0xFF1F2937) : Colors.white;
    final listCardBase =
        isDark ? const Color(0xFF2D3748) : Colors.white;
    final listCardHover =
        isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB);
    final listCardSelected = isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.2)
        : const Color(0xFFEFF6FF);
    final selectedBorder = const Color(0xFF3B82F6);
    final secondaryText =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final versionsAsync =
        ref.watch(documentVersionsProvider(widget.document.id));
    final versionCount = versionsAsync.asData?.value.length ?? 0;

    Widget actionButton({
      required VoidCallback onPressed,
      required IconData icon,
      required String label,
      required Color baseColor,
      required Color hoverColor,
      required Color textColor,
    }) {
      return TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.hovered)) {
              return hoverColor;
            }
            return baseColor;
          }),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          minimumSize: MaterialStateProperty.all(Size.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          overlayColor: MaterialStateProperty.all(Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: modalBackground,
      borderRadius: BorderRadius.circular(16),
      elevation: 24,
      clipBehavior: Clip.antiAlias,
      child: SizedBox.expand(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: modalBackground,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF7C3AED),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: const Icon(
                      Icons.device_hub_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Version History',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.document.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 14,
                            color: isDark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(8),
                    hoverColor:
                        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.close,
                        size: 24,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: versionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(
                  child: Text(
                    'Version load error: $e',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                data: (versions) {
                  if (versions.isEmpty) {
                    return Center(
                      child: Text(
                        'No versions available.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    );
                  }
                  final sortedVersions = List<DocumentVersion>.from(versions)
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  DocumentVersion? selected;
                  if (_selectedVersionId != null) {
                    for (final version in sortedVersions) {
                      if (version.id == _selectedVersionId) {
                        selected = version;
                        break;
                      }
                    }
                  }
                  final isSelectedCurrent = selected != null &&
                      selected.version == widget.document.version;
                  final selectedChanges =
                      selected == null ? null : _changesForVersion(selected);
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1024;
                      final list = ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedVersions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final version = sortedVersions[index];
                          final isCurrent =
                              version.version == widget.document.version;
                          final isSelected = version.id == _selectedVersionId;
                          final isHovered = _hoveredVersionId == version.id;
                          final badgeColor = _versionBadgeColor(
                              version.version, isCurrent);
                          final cardColor = isSelected
                              ? listCardSelected
                              : (isHovered ? listCardHover : listCardBase);
                          final cardBorder =
                              isSelected ? selectedBorder : border;
                          final sizeBadgeBackground = isDark
                              ? const Color(0xFF374151)
                              : const Color(0xFFF3F4F6);
                          return MouseRegion(
                            onEnter: (_) =>
                                setState(() => _hoveredVersionId = version.id),
                            onExit: (_) {
                              if (_hoveredVersionId == version.id) {
                                setState(() => _hoveredVersionId = null);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cardBorder),
                              ),
                              child: InkWell(
                                onTap: () => setState(
                                    () => _selectedVersionId = version.id),
                                hoverColor: Colors.transparent,
                                splashColor: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: badgeColor,
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  isCurrent
                                                      ? 'CURRENT'
                                                      : 'v${version.version}',
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Version ${version.version}',
                                                    style: theme
                                                        .textTheme.bodyMedium
                                                        ?.copyWith(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF111827),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _formatRelative(
                                                        version.createdAt),
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      fontSize: 14,
                                                      color: secondaryText,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: sizeBadgeBackground,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _formatBytes(version.fileSize),
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                fontSize: 12,
                                                color: secondaryText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person_outline,
                                            size: 16,
                                            color: secondaryText,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            version.uploadedBy ??
                                                widget.document.uploadedBy,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontSize: 14,
                                              color: secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _changesForVersion(version),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          fontSize: 14,
                                          color: isDark
                                              ? const Color(0xFFD1D5DB)
                                              : const Color(0xFF374151),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          actionButton(
                                            onPressed: () =>
                                                widget.onDownload(version),
                                            icon: Icons.download_outlined,
                                            label: 'Download',
                                            baseColor: isDark
                                                ? const Color(0xFF374151)
                                                : const Color(0xFFE5E7EB),
                                            hoverColor: isDark
                                                ? const Color(0xFF4B5563)
                                                : const Color(0xFFD1D5DB),
                                            textColor: isDark
                                                ? const Color(0xFFD1D5DB)
                                                : const Color(0xFF374151),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!isCurrent)
                                            actionButton(
                                              onPressed: () =>
                                                  widget.onRestore(version),
                                              icon: Icons.restore_outlined,
                                              label: 'Restore',
                                              baseColor:
                                                  const Color(0xFF2563EB),
                                              hoverColor:
                                                  const Color(0xFF1D4ED8),
                                              textColor: Colors.white,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );

                      final details = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2D3748)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: selected == null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Version Information',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFFD1D5DB)
                                          : const Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 32),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.description_outlined,
                                            size: 48,
                                            color: (isDark
                                                    ? const Color(0xFF6B7280)
                                                    : const Color(0xFF9CA3AF))
                                                .withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Select a version to view details',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontSize: 14,
                                              color: isDark
                                                  ? const Color(0xFF6B7280)
                                                  : const Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Version Information',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFFD1D5DB)
                                          : const Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _VersionInfoRow(
                                    label: 'VERSION NUMBER',
                                    value: selected.version,
                                    valueColor: isDark
                                        ? Colors.white
                                        : const Color(0xFF111827),
                                    valueWeight: FontWeight.w600,
                                  ),
                                  _VersionInfoRow(
                                    label: 'CREATED BY',
                                    value: selected.uploadedBy ??
                                        widget.document.uploadedBy,
                                  ),
                                  _VersionInfoRow(
                                    label: 'TIMESTAMP',
                                    value: DateFormat.yMd()
                                        .add_jm()
                                        .format(selected.createdAt),
                                  ),
                                  _VersionInfoRow(
                                    label: 'FILE SIZE',
                                    value: _formatBytes(selected.fileSize),
                                  ),
                                  _VersionInfoRow(
                                    label: 'CHANGES',
                                    value: selectedChanges ?? '',
                                  ),
                                  if (isSelectedCurrent)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF14532D)
                                                .withValues(alpha: 0.3)
                                            : const Color(0xFFECFDF5),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '\u2713 This is the current version',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? const Color(0xFF86EFAC)
                                              : const Color(0xFF15803D),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      );
                      final autoArchive = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF1D4ED8)
                                    .withValues(alpha: 0.5)
                                : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\u{1F4A1} Auto-Archive',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF93C5FD)
                                    : const Color(0xFF1D4ED8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Versions are automatically archived when changes are saved. Previous versions are kept for 90 days.',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF93C5FD)
                                    : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                      );
                      final detailsSection = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          details,
                          const SizedBox(height: 16),
                          autoArchive,
                        ],
                      );

                      final content = isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: list),
                                const SizedBox(width: 24),
                                Expanded(child: detailsSection),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                list,
                                const SizedBox(height: 24),
                                detailsSection,
                              ],
                            );
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: content,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF2D3748) : const Color(0xFFF9FAFB),
                border: Border(top: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Text(
                    '$versionCount version${versionCount == 1 ? '' : 's'} available',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onClose,
                    style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.hovered)) {
                          return const Color(0xFF1D4ED8);
                        }
                        return const Color(0xFF2563EB);
                      }),
                      foregroundColor:
                          MaterialStateProperty.all(Colors.white),
                      padding: MaterialStateProperty.all(
                        const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      minimumSize: MaterialStateProperty.all(Size.zero),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: MaterialStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      overlayColor:
                          MaterialStateProperty.all(Colors.transparent),
                      textStyle: MaterialStateProperty.all(
                        theme.textTheme.bodySmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    child: const Text('Close'),
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

class _VersionInfoRow extends StatelessWidget {
  const _VersionInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWeight,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final FontWeight? valueWeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 14,
                  fontWeight: valueWeight ?? FontWeight.w400,
                  color: valueColor ??
                      (isDark
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF374151)),
                ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTableRow extends StatefulWidget {
  const _DocumentTableRow({
    required this.doc,
    required this.border,
    required this.isDark,
    required this.onOpen,
    required this.onDownload,
    required this.onShare,
    required this.onDelete,
    required this.downloadColor,
    required this.shareColor,
    required this.deleteColor,
  });

  final _DocumentViewModel doc;
  final Color border;
  final bool isDark;
  final ValueChanged<Document> onOpen;
  final ValueChanged<Document> onDownload;
  final ValueChanged<Document> onShare;
  final ValueChanged<Document> onDelete;
  final Color downloadColor;
  final Color shareColor;
  final Color deleteColor;

  @override
  State<_DocumentTableRow> createState() => _DocumentTableRowState();
}

class _DocumentTableRowState extends State<_DocumentTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText =
        widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final secondaryStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      color: secondaryText,
    );
    final iconColor =
        widget.isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final hoverBackground = widget.isDark
        ? const Color(0xFF374151).withValues(alpha: 0.5)
        : const Color(0xFFF9FAFB);
    final downloadHover = widget.isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
        : const Color(0xFFEFF6FF);
    final shareHover =
        widget.isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB);
    final deleteHover = widget.isDark
        ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
        : const Color(0xFFFEF2F2);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _isHovered ? hoverBackground : Colors.transparent,
          border: Border(bottom: BorderSide(color: widget.border)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onOpen(widget.doc.document),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  _TableCell(
                    flex: 4,
                    child: Row(
                      children: [
                        if (widget.doc.starred)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.star,
                              size: 16,
                              color: Color(0xFFFBBF24),
                            ),
                          ),
                        Icon(
                          _iconForType(widget.doc.type),
                          size: 20,
                          color: iconColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.doc.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: widget.isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TableCell(
                    flex: 2,
                    child: Text(
                      widget.doc.type,
                      style: secondaryStyle,
                    ),
                  ),
                  _TableCell(
                    flex: 2,
                    child: Text(
                      widget.doc.sizeLabel,
                      style: secondaryStyle,
                    ),
                  ),
                  _TableCell(
                    flex: 2,
                    child: _FolderPill(label: widget.doc.folder),
                  ),
                  _TableCell(
                    flex: 2,
                    child: Text(
                      widget.doc.uploadedBy,
                      style: secondaryStyle,
                    ),
                  ),
                  _TableCell(
                    flex: 2,
                    child: Text(
                      widget.doc.dateLabel,
                      style: secondaryStyle,
                    ),
                  ),
                  _TableCell(
                    flex: 1,
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 12, color: secondaryText),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.doc.views}',
                          style: secondaryStyle,
                        ),
                      ],
                    ),
                  ),
                  _TableCell(
                    flex: 2,
                    child: Row(
                      children: [
                        _InlineIconButton(
                          icon: Icons.download_outlined,
                          color: widget.downloadColor,
                          hoverColor: downloadHover,
                          onPressed: () => widget.onDownload(widget.doc.document),
                        ),
                        _InlineIconButton(
                          icon: Icons.share_outlined,
                          color: widget.shareColor,
                          hoverColor: shareHover,
                          onPressed: () => widget.onShare(widget.doc.document),
                        ),
                        _InlineIconButton(
                          icon: Icons.delete_outline,
                          color: widget.deleteColor,
                          hoverColor: deleteHover,
                          onPressed: () => widget.onDelete(widget.doc.document),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentsErrorView extends StatelessWidget {
  const _DocumentsErrorView({required this.error});

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
