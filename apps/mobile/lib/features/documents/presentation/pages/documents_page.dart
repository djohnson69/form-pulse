import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/storage_utils.dart';
import '../../../projects/data/projects_provider.dart';
import '../../data/documents_provider.dart';
import 'document_detail_page.dart';
import 'document_editor_page.dart';

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
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final projectNames = {
      for (final project in projects) project.id: project.name,
    };
    final projectName = widget.projectName ??
        (widget.projectId == null
            ? null
            : projectNames[widget.projectId!]);

    return Scaffold(
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _DocumentsErrorView(error: e.toString()),
        data: (docs) {
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
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(context),
                if (projectName != null) ...[
                  const SizedBox(height: 12),
                  _ProjectContextCard(
                    projectName: projectName,
                    documentCount: models.length,
                  ),
                ],
                const SizedBox(height: 16),
                _buildCollaborationTools(context, models),
                const SizedBox(height: 16),
                _DocumentStatsGrid(stats: stats),
                const SizedBox(height: 16),
                _buildFolderSection(context, folders),
                const SizedBox(height: 16),
                _buildFilters(context, folders),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  _EmptyDocumentsCard(
                    onClear: _clearFilters,
                    onUpload: () => _openEditor(context),
                  )
                else
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
        final isWide = constraints.maxWidth >= 720;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Management',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage and access all project documents and files',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );

        final controls = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ViewToggle(
              selected: _viewMode,
              onChanged: (mode) => setState(() => _viewMode = mode),
            ),
            FilledButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Document'),
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
            const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Collaboration Tools:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          _ToolButton(
            icon: Icons.document_scanner,
            label: 'Scan Document',
            onPressed: () => _openEditor(context),
          ),
          _ToolButton(
            icon: Icons.edit_outlined,
            label: 'Annotate',
            onPressed: () async {
              final doc = await _pickDocument(context, docs);
              if (doc == null || !context.mounted) return;
              await _openEditor(
                context,
                document: doc,
                mode: DocumentEditorMode.version,
              );
            },
          ),
          _ToolButton(
            icon: Icons.history,
            label: 'Version History',
            onPressed: () async {
              final doc = await _pickDocument(context, docs);
              if (doc == null || !context.mounted) return;
              await _openDetail(doc);
            },
          ),
          _ToolButton(
            icon: Icons.approval_outlined,
            label: 'Collect Signatures',
            onPressed: () async {
              final doc = await _pickDocument(context, docs);
              if (doc == null || !context.mounted) return;
              await _openDetail(doc, openSignatureOnLoad: true);
            },
          ),
          _ToolButton(
            icon: Icons.fact_check_outlined,
            label: 'Templates',
            onPressed: () => _openTemplates(context),
          ),
          _ToolButton(
            icon: Icons.group_outlined,
            label: 'Collaborate',
            onPressed: () async {
              await _openCollaborativeEditor(context, docs);
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
    if (folders.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_open_outlined, size: 18),
            const SizedBox(width: 8),
            Text(
              'Quick Access Folders',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 1100
                ? 7
                : width >= 900
                    ? 5
                    : width >= 720
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final children = [
            Expanded(
              flex: isWide ? 2 : 0,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search documents...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
              ),
            ),
            SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedFolder,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
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
            SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_list),
              label: const Text('Filters'),
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
        final crossAxisCount = width >= 1100 ? 4 : (width >= 720 ? 2 : 1);
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
                  onDelete: () => _confirmDelete(context, doc.document),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    Document? document,
    DocumentEditorMode mode = DocumentEditorMode.create,
  }) async {
    final result = await Navigator.of(context).push<Document?>(
      MaterialPageRoute(
        builder: (_) => DocumentEditorPage(
          document: document,
          projectId: widget.projectId,
          mode: mode,
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

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedFolder = 'all';
    });
  }

  Future<void> _openTemplates(
    BuildContext context,
  ) async {
    final selection = await showModalBottomSheet<_DocumentTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _TemplateLibrarySheet(),
    );
    if (selection == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Using template: ${selection.name}')),
    );
  }

  Future<void> _openCollaborativeEditor(
    BuildContext context,
    List<_DocumentViewModel> docs,
  ) async {
    final doc = await _pickDocument(context, docs);
    if (doc == null || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CollaborativeEditorSheet(document: doc),
    );
  }

  Future<Document?> _pickDocument(
    BuildContext context,
    List<_DocumentViewModel> docs,
  ) async {
    if (docs.isEmpty) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No documents available.')),
      );
      return null;
    }
    return showModalBottomSheet<Document>(
      context: context,
      builder: (context) => _DocumentPickerSheet(
        title: 'Select a document',
        docs: docs,
      ),
    );
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
    final message = StringBuffer()
      ..writeln(doc.title)
      ..writeln(doc.fileUrl);
    await SharePlus.instance.share(ShareParams(text: message.toString()));
  }

  Future<void> _openDocumentUrl(Document doc) async {
    final signedUrl = await createSignedStorageUrl(
      client: Supabase.instance.client,
      url: doc.fileUrl,
      defaultBucket: _bucketName,
      metadata: doc.metadata,
      expiresInSeconds: kSignedUrlExpirySeconds,
    );
    final effectiveUrl = signedUrl ?? doc.fileUrl;
    final isImage = doc.mimeType.startsWith('image/') ||
        doc.filename.toLowerCase().endsWith('.png') ||
        doc.filename.toLowerCase().endsWith('.jpg') ||
        doc.filename.toLowerCase().endsWith('.jpeg') ||
        doc.filename.toLowerCase().endsWith('.heic') ||
        doc.filename.toLowerCase().endsWith('.heif');
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
          doc.title.toLowerCase().contains(_searchQuery) ||
          doc.folder.toLowerCase().contains(_searchQuery) ||
          doc.type.toLowerCase().contains(_searchQuery) ||
          doc.filename.toLowerCase().contains(_searchQuery);
      final matchesFolder =
          _selectedFolder == 'all' || doc.folder == _selectedFolder;
      return matchesSearch && matchesFolder;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<_FolderSummary> _buildFolderSummaries(List<_DocumentViewModel> docs) {
    final counts = <String, int>{};
    for (final doc in docs) {
      counts.update(doc.folder, (value) => value + 1, ifAbsent: () => 1);
    }
    final items = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return items
        .map((entry) => _FolderSummary.fromName(entry.key, entry.value))
        .toList();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
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
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              Icon(icon, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
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
  final bool starred;
  final int views;
  final bool isShared;
  final bool isTemplate;
  final int fileSize;

  String get sizeLabel => document.formattedFileSize;
  String get dateLabel => DateFormat('MMM d').format(updatedAt);

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
    required this.icon,
    required this.color,
  });

  final String name;
  final int count;
  final IconData icon;
  final Color color;

  factory _FolderSummary.fromName(String name, int count) {
    final lower = name.toLowerCase();
    if (lower.contains('manual')) {
      return _FolderSummary(
        name: name,
        count: count,
        icon: Icons.menu_book_outlined,
        color: const Color(0xFF3B82F6),
      );
    }
    if (lower.contains('blueprint') || lower.contains('cad')) {
      return _FolderSummary(
        name: name,
        count: count,
        icon: Icons.square_foot_outlined,
        color: const Color(0xFF8B5CF6),
      );
    }
    if (lower.contains('report')) {
      return _FolderSummary(
        name: name,
        count: count,
        icon: Icons.analytics_outlined,
        color: const Color(0xFF10B981),
      );
    }
    if (lower.contains('photo') || lower.contains('image')) {
      return _FolderSummary(
        name: name,
        count: count,
        icon: Icons.photo_outlined,
        color: const Color(0xFFF97316),
      );
    }
    if (lower.contains('contract')) {
      return _FolderSummary(
        name: name,
        count: count,
        icon: Icons.article_outlined,
        color: const Color(0xFFEF4444),
      );
    }
    if (lower.contains('training')) {
      return _FolderSummary(
        name: name,
        count: count,
        icon: Icons.school_outlined,
        color: const Color(0xFFF59E0B),
      );
    }
    if (lower.contains('certificate')) {
      return _FolderSummary(
        name: name,
        count: count,
        icon: Icons.workspace_premium_outlined,
        color: const Color(0xFFEC4899),
      );
    }
    return _FolderSummary(
      name: name,
      count: count,
      icon: Icons.folder_outlined,
      color: const Color(0xFF64748B),
    );
  }
}

enum _TemplateSort { popular, recent, name }

class _TemplateCategorySeed {
  const _TemplateCategorySeed({
    required this.id,
    required this.name,
    required this.icon,
  });

  final String id;
  final String name;
  final IconData icon;
}

class _TemplateCategory {
  const _TemplateCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.count,
  });

  final String id;
  final String name;
  final IconData icon;
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
  const _TemplateLibrarySheet();

  @override
  State<_TemplateLibrarySheet> createState() => _TemplateLibrarySheetState();
}

class _TemplateLibrarySheetState extends State<_TemplateLibrarySheet> {
  static const List<_TemplateCategorySeed> _categorySeeds = [
    _TemplateCategorySeed(
      id: 'all',
      name: 'All Templates',
      icon: Icons.article_outlined,
    ),
    _TemplateCategorySeed(
      id: 'safety',
      name: 'Safety Forms',
      icon: Icons.health_and_safety_outlined,
    ),
    _TemplateCategorySeed(
      id: 'inspection',
      name: 'Inspection Reports',
      icon: Icons.fact_check_outlined,
    ),
    _TemplateCategorySeed(
      id: 'contracts',
      name: 'Contracts',
      icon: Icons.description_outlined,
    ),
    _TemplateCategorySeed(
      id: 'checklists',
      name: 'Checklists',
      icon: Icons.checklist_outlined,
    ),
    _TemplateCategorySeed(
      id: 'incident',
      name: 'Incident Reports',
      icon: Icons.report_problem_outlined,
    ),
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';
  _TemplateSort _sortBy = _TemplateSort.popular;
  late final List<_DocumentTemplate> _templates;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _templates = [
      _DocumentTemplate(
        id: '1',
        name: 'Daily Safety Inspection',
        category: 'safety',
        description:
            'Comprehensive daily safety inspection checklist for construction sites',
        downloads: 1245,
        rating: 4.8,
        lastUsed: now.subtract(const Duration(days: 1)),
        isFavorite: true,
        tags: const ['safety', 'daily', 'construction'],
      ),
      _DocumentTemplate(
        id: '2',
        name: 'Equipment Inspection Form',
        category: 'inspection',
        description: 'Detailed equipment condition assessment and maintenance log',
        downloads: 987,
        rating: 4.6,
        isFavorite: false,
        tags: const ['equipment', 'maintenance', 'inspection'],
      ),
      _DocumentTemplate(
        id: '3',
        name: 'Service Contract Agreement',
        category: 'contracts',
        description: 'Standard service contract template with terms and conditions',
        downloads: 2341,
        rating: 4.9,
        lastUsed: now.subtract(const Duration(days: 2)),
        isFavorite: true,
        tags: const ['contract', 'legal', 'service'],
      ),
      _DocumentTemplate(
        id: '4',
        name: 'Site Safety Checklist',
        category: 'checklists',
        description: 'Pre-work safety verification checklist for job sites',
        downloads: 1567,
        rating: 4.7,
        isFavorite: false,
        tags: const ['safety', 'checklist', 'pre-work'],
      ),
      _DocumentTemplate(
        id: '5',
        name: 'Incident Report Form',
        category: 'incident',
        description:
            'Comprehensive incident documentation with witness statements',
        downloads: 876,
        rating: 4.5,
        lastUsed: now.subtract(const Duration(days: 7)),
        isFavorite: true,
        tags: const ['incident', 'report', 'safety'],
      ),
      _DocumentTemplate(
        id: '6',
        name: 'Weekly Toolbox Talk',
        category: 'safety',
        description: 'Weekly safety meeting documentation template',
        downloads: 654,
        rating: 4.4,
        isFavorite: false,
        tags: const ['safety', 'training', 'weekly'],
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_TemplateCategory> _buildCategories() {
    final counts = <String, int>{};
    for (final template in _templates) {
      counts.update(template.category, (value) => value + 1, ifAbsent: () => 1);
    }
    final total = _templates.length;
    return _categorySeeds.map((seed) {
      final count = seed.id == 'all' ? total : (counts[seed.id] ?? 0);
      return _TemplateCategory(
        id: seed.id,
        name: seed.name,
        icon: seed.icon,
        count: count,
      );
    }).toList();
  }

  List<_DocumentTemplate> _filteredTemplates() {
    final query = _searchQuery.trim().toLowerCase();
    final items = _templates.where((template) {
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FractionallySizedBox(
          heightFactor: 0.95,
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _TemplateLibraryHeader(
                  onClose: () => Navigator.pop(context),
                ),
                _TemplateLibrarySearchBar(
                  controller: _searchController,
                  sortBy: _sortBy,
                  onSearchChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  onSortChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortBy = value);
                  },
                  borderColor: border,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      if (isWide) {
                        return Row(
                          children: [
                            SizedBox(
                              width: 240,
                              child: _TemplateCategoryList(
                                categories: categories,
                                selectedCategory: _selectedCategory,
                                onSelected: (value) {
                                  setState(() => _selectedCategory = value);
                                },
                                borderColor: border,
                                isDark: isDark,
                                axis: Axis.vertical,
                              ),
                            ),
                            VerticalDivider(width: 1, color: border),
                            Expanded(
                              child: _TemplateGrid(
                                templates: filtered,
                                onSelect: (template) {
                                  Navigator.pop(context, template);
                                },
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          SizedBox(
                            height: 116,
                            child: _TemplateCategoryList(
                              categories: categories,
                              selectedCategory: _selectedCategory,
                              onSelected: (value) {
                                setState(() => _selectedCategory = value);
                              },
                              borderColor: border,
                              isDark: isDark,
                              axis: Axis.horizontal,
                            ),
                          ),
                          Divider(height: 1, color: border),
                          Expanded(
                            child: _TemplateGrid(
                              templates: filtered,
                              onSelect: (template) {
                                Navigator.pop(context, template);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                _TemplateLibraryFooter(
                  count: filtered.length,
                  onClose: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateLibraryHeader extends StatelessWidget {
  const _TemplateLibraryHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Template Library',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose from professionally designed document templates',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
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
    final searchField = TextField(
      controller: controller,
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search templates by name, description, or tags...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        isDense: true,
      ),
    );

    final sortDropdown = DropdownButtonFormField<_TemplateSort>(
      value: sortBy,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        isDense: true,
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
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 680;
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
    final background = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    return Container(
      color: background,
      padding: const EdgeInsets.all(12),
      child: ListView.separated(
        scrollDirection: axis,
        itemCount: categories.length,
        separatorBuilder: (_, __) =>
            axis == Axis.vertical ? const SizedBox(height: 8) : const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.id == selectedCategory;
          final color = isSelected
              ? theme.colorScheme.primary
              : (isDark ? const Color(0xFF1F2937) : Colors.white);
          final textColor = isSelected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelected(category.id),
            child: Container(
              width: axis == Axis.horizontal ? 200 : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? color : borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    category.icon,
                    color: textColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${category.count} templates',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isSelected
                                ? textColor.withValues(alpha: 0.8)
                                : theme.colorScheme.onSurfaceVariant,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No templates found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search or filter',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100
            ? 3
            : width >= 760
                ? 2
                : 1;
        final aspectRatio = width >= 1100
            ? 0.9
            : width >= 760
                ? 1.05
                : 1.2;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
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

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onSelect,
  });

  final _DocumentTemplate template;
  final VoidCallback onSelect;

  String _lastUsedLabel(DateTime? lastUsed) {
    if (lastUsed == null) return '';
    final days = DateTime.now().difference(lastUsed).inDays;
    if (days <= 0) return 'Today';
    return '${days}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final formatter = NumberFormat.compact();
    final lastUsedLabel = _lastUsedLabel(template.lastUsed);
    return Container(
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
          Stack(
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1F2937)
                      : const Color(0xFFF3F4F6),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.description_outlined,
                    size: 56,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
              if (template.isFavorite)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.star,
                    size: 20,
                    color: Color(0xFFFBBF24),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: template.tags.take(3).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatter.format(template.downloads),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.star,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        template.rating.toStringAsFixed(1),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (lastUsedLabel.isNotEmpty) ...[
                        const Spacer(),
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          lastUsedLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onSelect,
                      child: const Text('Use Template'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Text(
            '$count template${count == 1 ? '' : 's'} available',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onClose,
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
    setState(() {
      _showChanges = !_showChanges;
      if (_showChanges) _showComments = false;
    });
  }

  void _toggleComments() {
    setState(() {
      _showComments = !_showComments;
      if (_showComments) _showChanges = false;
    });
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
          content: value.length <= 12 ? value : value.substring(value.length - 12),
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
      const SnackBar(content: Text('Changes saved.')),
    );
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FractionallySizedBox(
          heightFactor: 0.95,
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _CollaborativeHeader(
                  documentName: widget.document.title,
                  isOnline: _isOnline,
                  isSaving: _isSaving,
                  lastSaved: _lastSaved,
                  collaborators: activeCollaborators,
                  totalCollaborators: _collaborators.length,
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
                      final isWide = constraints.maxWidth >= 900;
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
                              changes: _changes,
                              collaborators: _collaborators,
                              isDark: isDark,
                              timeAgo: _formatTimeAgo,
                            )
                          : null;
                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(child: editor),
                            if (sidebar != null) VerticalDivider(width: 1, color: border),
                            if (sidebar != null)
                              SizedBox(width: 300, child: sidebar),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Expanded(child: editor),
                          if (sidebar != null) Divider(height: 1, color: border),
                          if (sidebar != null)
                            SizedBox(height: 240, child: sidebar),
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
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      documentName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              isOnline ? 'Connected' : 'Offline',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, size: 14, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              isSaving ? 'Saving...' : 'Saved ${_formatTimeAgo(lastSaved)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (collaborators.isNotEmpty)
                _CollaboratorStack(
                  collaborators: collaborators,
                  totalCount: totalCollaborators,
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onToggleChanges,
                icon: const Icon(Icons.history, size: 16),
                label: Text('Changes ($changeCount)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: showChanges ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  side: BorderSide(
                    color: showChanges ? theme.colorScheme.primary : theme.dividerColor,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onToggleComments,
                icon: const Icon(Icons.comment_outlined, size: 16),
                label: const Text('Comments'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: showComments ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  side: BorderSide(
                    color: showComments ? theme.colorScheme.primary : theme.dividerColor,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: Text(isSaving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
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
    final visible = collaborators.take(4).toList();
    final overlap = 18.0;
    final width = visible.length * overlap + 32;
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
              '+${totalCount - visible.length}',
              style: Theme.of(context).textTheme.bodySmall,
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
    return Stack(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: collaborator.color,
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
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
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
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                  height: 1.6,
                  fontFamily: 'Georgia',
                ),
              ),
            ),
          ),
        ),
        if (activeCollaborators.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Active editors: ${activeCollaborators.map((c) => c.name).join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
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
    required this.changes,
    required this.collaborators,
    required this.isDark,
    required this.timeAgo,
  });

  final bool showChanges;
  final List<_CollaborativeChange> changes;
  final List<_Collaborator> collaborators;
  final bool isDark;
  final String Function(DateTime) timeAgo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            showChanges ? 'Recent Changes' : 'Comments',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (showChanges)
            ..._buildChangeCards(theme)
          else
            _buildCommentsPlaceholder(theme),
        ],
      ),
    );
  }

  List<Widget> _buildChangeCards(ThemeData theme) {
    if (changes.isEmpty) {
      return [
        Text(
          'No changes yet.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ];
    }
    return changes
        .take(10)
        .toList()
        .reversed
        .map((change) {
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
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        timeAgo(change.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${change.type == 'insert' ? 'Added' : 'Updated'} "${change.content}"',
                        style: theme.textTheme.bodySmall,
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
    return Column(
      children: [
        const SizedBox(height: 12),
        Icon(
          Icons.comment_outlined,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'No comments yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select text in the document to add a comment.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.people_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '$activeCount active',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.visibility_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '$viewerCount viewers',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$wordCount words, $charCount chars',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            'All changes are automatically saved',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectContextCard extends StatelessWidget {
  const _ProjectContextCard({
    required this.projectName,
    required this.documentCount,
  });

  final String projectName;
  final int documentCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF374151)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.work_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              projectName,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Text(
            '$documentCount docs',
            style: theme.textTheme.bodySmall,
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
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1000),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFF9FAFB),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
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
                (doc) => InkWell(
                  onTap: () => onOpen(doc.document),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: border)),
                    ),
                    child: Row(
                      children: [
                        _TableCell(
                          flex: 4,
                          child: Row(
                            children: [
                              if (doc.starred)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Color(0xFFFBBF24),
                                  ),
                                ),
                              Icon(
                                _iconForType(doc.type),
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  doc.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _TableCell(flex: 2, child: Text(doc.type)),
                        _TableCell(flex: 2, child: Text(doc.sizeLabel)),
                        _TableCell(
                          flex: 2,
                          child: _FolderPill(label: doc.folder),
                        ),
                        _TableCell(flex: 2, child: Text(doc.uploadedBy)),
                        _TableCell(flex: 2, child: Text(doc.dateLabel)),
                        _TableCell(
                          flex: 1,
                          child: Row(
                            children: [
                              const Icon(Icons.visibility, size: 14),
                              const SizedBox(width: 4),
                              Text('${doc.views}'),
                            ],
                          ),
                        ),
                        _TableCell(
                          flex: 2,
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Download',
                                icon: const Icon(Icons.download_outlined),
                                onPressed: () => onDownload(doc.document),
                              ),
                              IconButton(
                                tooltip: 'Share',
                                icon: const Icon(Icons.share_outlined),
                                onPressed: () => onShare(doc.document),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => onDelete(doc.document),
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

enum _DocumentMenuAction { open, download, share, delete }

class _DocumentGridCard extends StatelessWidget {
  const _DocumentGridCard({
    required this.model,
    required this.onOpen,
    required this.onDownload,
    required this.onShare,
    required this.onDelete,
  });

  final _DocumentViewModel model;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onDelete;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DocumentIconBadge(type: model.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          model.sizeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _FolderPill(label: model.type),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (model.starred)
                    const Icon(
                      Icons.star,
                      size: 16,
                      color: Color(0xFFFBBF24),
                    )
                  else
                    const SizedBox(height: 16),
                  PopupMenuButton<_DocumentMenuAction>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      switch (value) {
                        case _DocumentMenuAction.open:
                          onOpen();
                          break;
                        case _DocumentMenuAction.download:
                          onDownload();
                          break;
                        case _DocumentMenuAction.share:
                          onShare();
                          break;
                        case _DocumentMenuAction.delete:
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _DocumentMenuAction.open,
                        child: Text('Open'),
                      ),
                      PopupMenuItem(
                        value: _DocumentMenuAction.download,
                        child: Text('Download'),
                      ),
                      PopupMenuItem(
                        value: _DocumentMenuAction.share,
                        child: Text('Share'),
                      ),
                      PopupMenuItem(
                        value: _DocumentMenuAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: border),
          const SizedBox(height: 12),
          Text(
            'Uploaded by ${model.uploadedBy}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            model.dateLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Row(
                children: [
                  const Icon(Icons.visibility, size: 14),
                  const SizedBox(width: 4),
                  Text('${model.views} views'),
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Download',
                icon: const Icon(Icons.download_outlined),
                onPressed: onDownload,
              ),
              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.share_outlined),
                onPressed: onShare,
              ),
            ],
          ),
        ],
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
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

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.isSelected,
    required this.onTap,
  });

  final _FolderSummary folder;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isSelected
        ? (isDark ? const Color(0xFF1D4ED8) : const Color(0xFFDBEAFE))
        : theme.colorScheme.surface;
    final border = isSelected
        ? folder.color
        : (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(folder.icon, color: folder.color),
            const SizedBox(height: 8),
            Text(
              folder.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${folder.count} files',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderPill extends StatelessWidget {
  const _FolderPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall,
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
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
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
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF374151) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 18,
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
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _DocumentPickerSheet extends StatelessWidget {
  const _DocumentPickerSheet({
    required this.title,
    required this.docs,
  });

  final String title;
  final List<_DocumentViewModel> docs;

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
                    title,
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
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return ListTile(
                    leading: Icon(_iconForType(doc.type)),
                    title: Text(doc.title),
                    subtitle: Text('${doc.folder} • ${doc.sizeLabel}'),
                    onTap: () => Navigator.pop(context, doc.document),
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

class _EmptyDocumentsCard extends StatelessWidget {
  const _EmptyDocumentsCard({required this.onClear, required this.onUpload});

  final VoidCallback onClear;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No documents match your filters.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Clear filters or upload a new document to get started.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Clear filters'),
                  onPressed: onClear,
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload document'),
                  onPressed: onUpload,
                ),
              ],
            ),
          ],
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
