import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/sop_provider.dart';
import '../../data/sop_repository.dart';

class SopEditorPage extends ConsumerStatefulWidget {
  const SopEditorPage({this.document, this.initialVersion, super.key});

  final SopDocument? document;
  final SopVersion? initialVersion;

  @override
  ConsumerState<SopEditorPage> createState() => _SopEditorPageState();
}

class _SopEditorPageState extends ConsumerState<SopEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _bodyController = TextEditingController();
  String _status = 'draft';
  bool _saving = false;
  String _initialBody = '';
  Timer? _draftDebounce;
  DateTime? _lastDraftUpdate;
  RealtimeChannel? _draftChannel;
  bool _applyingRemote = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final doc = widget.document;
    if (doc != null) {
      _titleController.text = doc.title;
      _summaryController.text = doc.summary ?? '';
      _categoryController.text = doc.category ?? '';
      _tagsController.text = doc.tags.join(', ');
      _status = doc.status;
      final draftBody = doc.metadata?['draft_body']?.toString();
      if (draftBody != null && draftBody.isNotEmpty) {
        _bodyController.text = draftBody;
        _initialBody = draftBody;
      }
    }
    final body = widget.initialVersion?.body ?? '';
    if (_bodyController.text.isEmpty) {
      _bodyController.text = body;
      _initialBody = body;
    }
    if (doc != null) {
      _bodyController.addListener(_scheduleDraftUpdate);
      _subscribeToDraftChanges(doc.id);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _bodyController.dispose();
    _draftDebounce?.cancel();
    _draftChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.document != null;
    final templatesAsync = ref.watch(sopDocumentsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit SOP' : 'New SOP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (!isEditing)
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _openTemplatePicker(templatesAsync),
                    icon: const Icon(Icons.layers),
                    label: const Text('Use template'),
                  ),
                ),
              if (!isEditing) const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _summaryController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Summary',
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
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(
                    value: 'pending_approval',
                    child: Text('Pending approval'),
                  ),
                  DropdownMenuItem(value: 'published', child: Text('Published')),
                  DropdownMenuItem(value: 'archived', child: Text('Archived')),
                ],
                onChanged: (value) => setState(() => _status = value ?? 'draft'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Procedure',
                  border: OutlineInputBorder(),
                ),
              ),
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
                label: Text(_saving ? 'Saving...' : 'Save SOP'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTemplatePicker(
    AsyncValue<List<SopDocument>> templatesAsync,
  ) async {
    final templates = templatesAsync.asData?.value ?? const <SopDocument>[];
    if (templates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No SOP templates available.')),
      );
      return;
    }
    final selected = await showModalBottomSheet<SopDocument>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Select template',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...templates.map(
              (doc) => ListTile(
                leading: const Icon(Icons.description),
                title: Text(doc.title),
                subtitle: Text(doc.summary ?? ''),
                onTap: () => Navigator.of(context).pop(doc),
              ),
            ),
          ],
        );
      },
    );
    if (selected == null) return;
    await _applyTemplate(selected);
  }

  Future<void> _applyTemplate(SopDocument template) async {
    try {
      final repo = ref.read(sopRepositoryProvider);
      final versions = await repo.fetchVersions(template.id);
      final body = versions.isNotEmpty ? versions.first.body ?? '' : '';
      setState(() {
        _titleController.text = template.title;
        _summaryController.text = template.summary ?? '';
        _categoryController.text = template.category ?? '';
        _tagsController.text = template.tags.join(', ');
        _status = 'draft';
        _bodyController.text = body;
        _initialBody = body;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template load failed: $e')),
      );
    }
  }

  void _scheduleDraftUpdate() {
    if (_applyingRemote || widget.document == null) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 800), () async {
      final body = _bodyController.text;
      _lastDraftUpdate = DateTime.now();
      await ref.read(sopRepositoryProvider).updateDraft(
            document: widget.document!,
            body: body,
          );
    });
  }

  void _subscribeToDraftChanges(String sopId) {
    final client = Supabase.instance.client;
    _draftChannel = client.channel('sop-draft-$sopId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'sop_documents',
        callback: (payload) {
          final record = payload.newRecord;
          if (record['id']?.toString() != sopId) return;
          final metadata = Map<String, dynamic>.from(
            record['metadata'] as Map? ?? const {},
          );
          final draftBody = metadata['draft_body']?.toString();
          final updatedRaw = metadata['draft_updated_at']?.toString();
          final updatedBy = metadata['draft_updated_by']?.toString();
          if (draftBody == null || draftBody.isEmpty) return;
          if (updatedBy != null && updatedBy == _currentUserId) return;
          final updatedAt = DateTime.tryParse(updatedRaw ?? '');
          if (updatedAt == null) return;
          if (_lastDraftUpdate != null &&
              !updatedAt.isAfter(_lastDraftUpdate!)) {
            return;
          }
          if (!mounted) return;
          _applyingRemote = true;
          _bodyController.text = draftBody;
          _initialBody = draftBody;
          _applyingRemote = false;
        },
      )
      ..subscribe();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(sopRepositoryProvider);
      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final body = _bodyController.text.trim();
      if (widget.document == null) {
        await repo.createDocument(
          SopDocumentDraft(
            title: _titleController.text.trim(),
            summary: _summaryController.text.trim().isEmpty
                ? null
                : _summaryController.text.trim(),
            category: _categoryController.text.trim().isEmpty
                ? null
                : _categoryController.text.trim(),
            tags: tags,
            status: _status,
            body: body,
          ),
        );
      } else {
        final updated = await repo.updateDocument(
          document: widget.document!,
          title: _titleController.text.trim(),
          summary: _summaryController.text.trim().isEmpty
              ? null
              : _summaryController.text.trim(),
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          tags: tags,
          status: _status,
        );
        if (body != _initialBody) {
          await repo.addVersion(document: updated, body: body);
        }
      }
      if (!mounted) return;
      ref.invalidate(sopDocumentsProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
