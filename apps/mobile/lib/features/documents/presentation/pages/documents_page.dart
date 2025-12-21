import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/documents_provider.dart';
import '../../../projects/data/projects_provider.dart';
import 'document_detail_page.dart';
import 'document_editor_page.dart';

enum _DocumentTypeFilter { all, templates, documents }

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({this.projectId, this.projectName, super.key});

  final String? projectId;
  final String? projectName;

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  String _query = '';
  String? _categoryFilter;
  _DocumentTypeFilter _typeFilter = _DocumentTypeFilter.all;
  RealtimeChannel? _documentsChannel;

  @override
  void initState() {
    super.initState();
    _subscribeToDocumentChanges();
  }

  @override
  void dispose() {
    _documentsChannel?.unsubscribe();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName ?? 'Documents'),
        actions: [
          IconButton(
            tooltip: 'Upload document',
            icon: const Icon(Icons.upload_file),
            onPressed: () => _openEditor(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Upload'),
      ),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Documents Load Error',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load documents.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${e.toString()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => ref.invalidate(documentsProvider(widget.projectId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
        data: (docs) {
          final categories = docs
              .map((doc) => doc.category)
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final filtered = _applyFilters(docs, projectNames);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(documentsProvider(widget.projectId));
              await ref.read(documentsProvider(widget.projectId).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.projectId != null && widget.projectName != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.work),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.projectName!,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '${docs.length} docs',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.projectId != null && widget.projectName != null)
                  const SizedBox(height: 12),
                _buildSearchField(),
                const SizedBox(height: 12),
                _buildTypeFilters(),
                if (categories.isNotEmpty) const SizedBox(height: 8),
                if (categories.isNotEmpty) _buildCategoryFilters(categories),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'No documents found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text('Upload files to keep your records organized.'),
                        ],
                      ),
                    ),
                  )
                else
                  ...filtered.map((doc) {
                    final projectName = widget.projectName ??
                        (doc.projectId == null
                            ? null
                            : projectNames[doc.projectId!]);
                    return _DocumentCard(
                      document: doc,
                      projectName: projectName,
                      onTap: () => _openDetail(doc, projectName),
                    );
                  }),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'Search documents',
        border: OutlineInputBorder(),
      ),
      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
    );
  }

  Widget _buildTypeFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('All'),
          selected: _typeFilter == _DocumentTypeFilter.all,
          onSelected: (_) => setState(() => _typeFilter = _DocumentTypeFilter.all),
        ),
        FilterChip(
          label: const Text('Templates'),
          selected: _typeFilter == _DocumentTypeFilter.templates,
          onSelected: (_) =>
              setState(() => _typeFilter = _DocumentTypeFilter.templates),
        ),
        FilterChip(
          label: const Text('Documents'),
          selected: _typeFilter == _DocumentTypeFilter.documents,
          onSelected: (_) =>
              setState(() => _typeFilter = _DocumentTypeFilter.documents),
        ),
      ],
    );
  }

  Widget _buildCategoryFilters(List<String> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('All categories'),
          selected: _categoryFilter == null,
          onSelected: (_) => setState(() => _categoryFilter = null),
        ),
        ...categories.map(
          (category) => FilterChip(
            label: Text(category),
            selected: _categoryFilter == category,
            onSelected: (_) => setState(() => _categoryFilter = category),
          ),
        ),
      ],
    );
  }

  List<Document> _applyFilters(
    List<Document> docs,
    Map<String, String> projectNames,
  ) {
    return docs.where((doc) {
      final projectName =
          doc.projectId == null ? null : projectNames[doc.projectId!];
      final matchesQuery = _query.isEmpty ||
          doc.title.toLowerCase().contains(_query) ||
          (doc.description?.toLowerCase().contains(_query) ?? false) ||
          doc.filename.toLowerCase().contains(_query) ||
          (doc.category?.toLowerCase().contains(_query) ?? false) ||
          (projectName?.toLowerCase().contains(_query) ?? false) ||
          (doc.tags?.any((tag) => tag.toLowerCase().contains(_query)) ?? false);
      final matchesCategory =
          _categoryFilter == null || doc.category == _categoryFilter;
      final matchesType = switch (_typeFilter) {
        _DocumentTypeFilter.templates => doc.isTemplate,
        _DocumentTypeFilter.documents => !doc.isTemplate,
        _DocumentTypeFilter.all => true,
      };
      return matchesQuery && matchesCategory && matchesType;
    }).toList();
  }

  Future<void> _openEditor(BuildContext context) async {
    final result = await Navigator.of(context).push<Document?>(
      MaterialPageRoute(
        builder: (_) => DocumentEditorPage(projectId: widget.projectId),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      ref.invalidate(documentsProvider(widget.projectId));
    }
  }

  Future<void> _openDetail(Document document, String? projectName) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentDetailPage(
          document: document,
          projectId: widget.projectId,
          projectName: projectName,
        ),
      ),
    );
    if (!mounted) return;
    ref.invalidate(documentsProvider(widget.projectId));
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.projectName,
    required this.onTap,
  });

  final Document document;
  final String? projectName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final signatureCount = _signatureCount(document);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            _iconFor(document),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(document.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((document.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  document.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 4),
            Text('${document.filename} • ${document.formattedFileSize}'),
            if (projectName != null && projectName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Project: $projectName'),
              ),
            if (signatureCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Signatures: $signatureCount'),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Pill(label: document.version),
                if (document.isTemplate) const _Pill(label: 'Template'),
                if (!document.isPublished) const _Pill(label: 'Draft'),
                if ((document.category ?? '').isNotEmpty)
                  _Pill(label: document.category!),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  IconData _iconFor(Document doc) {
    final filename = doc.filename.toLowerCase();
    final mime = doc.mimeType.toLowerCase();
    if (mime.contains('pdf') || filename.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }
    if (mime.startsWith('image/') ||
        filename.endsWith('.png') ||
        filename.endsWith('.jpg') ||
        filename.endsWith('.jpeg') ||
        filename.endsWith('.heic') ||
        filename.endsWith('.heif')) {
      return Icons.image;
    }
    if (filename.endsWith('.csv') || filename.endsWith('.xls')) {
      return Icons.table_chart;
    }
    if (filename.endsWith('.doc') || filename.endsWith('.docx')) {
      return Icons.description;
    }
    return Icons.insert_drive_file;
  }

  int _signatureCount(Document doc) {
    final signatures = doc.metadata?['signatures'];
    if (signatures is List) return signatures.length;
    return 0;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
