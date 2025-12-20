import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/storage_utils.dart';
import '../../data/documents_provider.dart';
import '../../../dashboard/presentation/pages/signature_pad_page.dart';
import '../../../projects/data/projects_provider.dart';
import 'document_editor_page.dart';

class DocumentDetailPage extends ConsumerStatefulWidget {
  const DocumentDetailPage({
    required this.document,
    this.projectId,
    this.projectName,
    super.key,
  });

  final Document document;
  final String? projectId;
  final String? projectName;

  @override
  ConsumerState<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends ConsumerState<DocumentDetailPage> {
  late Document _document;
  bool _saving = false;
  static const _bucketName =
      String.fromEnvironment('SUPABASE_BUCKET', defaultValue: 'formbridge-attachments');

  @override
  void initState() {
    super.initState();
    _document = widget.document;
  }

  @override
  Widget build(BuildContext context) {
    final versionsAsync = ref.watch(documentVersionsProvider(_document.id));
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final projectNames = {
      for (final project in projects) project.id: project.name,
    };
    final projectName = widget.projectName ??
        (_document.projectId == null
            ? null
            : projectNames[_document.projectId!]);
    final signatures = _signatures(_document);

    return Scaffold(
      appBar: AppBar(
        title: Text(_document.title),
        actions: [
          IconButton(
            tooltip: 'Open file',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openUrl(
              _document.fileUrl,
              mimeType: _document.mimeType,
              filename: _document.filename,
              metadata: _document.metadata,
            ),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: _shareDocument,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit details'),
                ),
              ),
              PopupMenuItem(
                value: 'version',
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Add version'),
                ),
              ),
              PopupMenuItem(
                value: 'sign',
                child: ListTile(
                  leading: Icon(Icons.verified),
                  title: Text('Add approval'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _document.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if ((_document.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(_document.description!),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(label: _document.version),
                          if (_document.isTemplate) const _Pill(label: 'Template'),
                          _Pill(label: _document.isPublished ? 'Published' : 'Draft'),
                          if ((_document.category ?? '').isNotEmpty)
                            _Pill(label: _document.category!),
                          if (projectName != null && projectName.isNotEmpty)
                            _Pill(label: projectName),
                        ],
                      ),
                      if ((_document.tags ?? []).isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _document.tags!
                              .map((tag) => _Pill(label: tag))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(_document.filename),
                  subtitle:
                      Text('${_document.formattedFileSize} • ${_document.mimeType}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () => _openUrl(
                      _document.fileUrl,
                      mimeType: _document.mimeType,
                      filename: _document.filename,
                      metadata: _document.metadata,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(
            title: 'Approvals',
            actionLabel: _saving ? 'Saving...' : 'Add approval',
            onAction: _saving ? null : _captureSignature,
          ),
          const SizedBox(height: 8),
          if (signatures.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'No approvals yet',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text('Capture signatures to approve this document.'),
                  ],
                ),
              ),
            )
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: signatures.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final signature = signatures[index];
                  final name = signature['signerName'] as String?;
                  final signedAt = signature['signedAt'] as DateTime?;
                  final url = signature['url'] as String?;
                  return ListTile(
                    leading: const Icon(Icons.verified),
                    title: Text(name?.isNotEmpty == true ? name! : 'Signature'),
                    subtitle: Text(
                      signedAt == null
                          ? 'Signed'
                          : _formatDateTime(context, signedAt),
                    ),
                    trailing: url == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () => _openUrl(
                              url,
                              mimeType: 'image/png',
                              filename: 'signature.png',
                              metadata: signature,
                            ),
                          ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          _SectionHeader(
            title: 'Version history',
            actionLabel: 'Add version',
            onAction: () => _openEditor(DocumentEditorMode.version),
          ),
          const SizedBox(height: 8),
          versionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Card(
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
                          'Versions Load Error',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
            data: (versions) {
              if (versions.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'No versions yet',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 6),
                        Text('Upload a new version to keep history.'),
                      ],
                    ),
                  ),
                );
              }
              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: versions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final version = versions[index];
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(version.version),
                      subtitle: Text(
                        '${version.filename} • ${_formatFileSize(version.fileSize)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => _openUrl(
                          version.fileUrl,
                          mimeType: version.mimeType,
                          filename: version.filename,
                          metadata: version.metadata,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'edit':
        await _openEditor(DocumentEditorMode.edit);
        break;
      case 'version':
        await _openEditor(DocumentEditorMode.version);
        break;
      case 'sign':
        await _captureSignature();
        break;
    }
  }

  Future<void> _openEditor(DocumentEditorMode mode) async {
    final updated = await Navigator.of(context).push<Document?>(
      MaterialPageRoute(
        builder: (_) => DocumentEditorPage(
          document: _document,
          projectId: widget.projectId,
          mode: mode,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _document = updated);
    ref.invalidate(documentVersionsProvider(_document.id));
    ref.invalidate(documentsProvider(widget.projectId));
  }

  Future<void> _shareDocument() async {
    final message = StringBuffer()
      ..writeln(_document.title)
      ..writeln(_document.fileUrl);
    await SharePlus.instance.share(ShareParams(text: message.toString()));
  }

  Future<void> _captureSignature() async {
    final result = await Navigator.of(context).push<SignatureResult>(
      MaterialPageRoute(
        builder: (_) => const SignaturePadPage(title: 'Approve document'),
      ),
    );
    if (result == null) return;
    setState(() => _saving = true);
    final repo = ref.read(documentsRepositoryProvider);
    try {
      final updated = await repo.addSignature(
        document: _document,
        bytes: result.bytes,
        signerName: result.name,
      );
      if (!mounted) return;
      setState(() {
        _document = updated;
        _saving = false;
      });
      ref.invalidate(documentsProvider(widget.projectId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signature failed: $e')),
      );
    }
  }

  Future<void> _openUrl(
    String url, {
    required String mimeType,
    required String filename,
    Map<String, dynamic>? metadata,
  }) async {
    if (url.isEmpty) return;
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

  List<Map<String, dynamic>> _signatures(Document doc) {
    final raw = doc.metadata?['signatures'];
    if (raw is! List) return const [];
    return raw
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .map((entry) {
      final signedAt = entry['signedAt'];
      return {
        ...entry,
        'signedAt': signedAt is DateTime
            ? signedAt
            : signedAt is String
            ? DateTime.tryParse(signedAt)
            : null,
      };
    }).toList();
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

  String _formatDateTime(BuildContext context, DateTime value) {
    final date = MaterialLocalizations.of(context).formatShortDate(value);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(value));
    return '$date $time';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add),
          label: Text(actionLabel),
        ),
      ],
    );
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
