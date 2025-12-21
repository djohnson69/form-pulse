import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/sop_provider.dart';
import 'sop_detail_page.dart';
import 'sop_editor_page.dart';

class SopLibraryPage extends ConsumerStatefulWidget {
  const SopLibraryPage({super.key});

  @override
  ConsumerState<SopLibraryPage> createState() => _SopLibraryPageState();
}

class _SopLibraryPageState extends ConsumerState<SopLibraryPage> {
  String _query = '';
  String _status = 'all';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final sopsAsync = ref.watch(sopDocumentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('SOP Library')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('New SOP'),
      ),
      body: sopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sops) {
          final categories = sops
              .map((sop) => sop.category)
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final filtered = _filterSops(sops);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search SOPs',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                      DropdownMenuItem(
                        value: 'pending_approval',
                        child: Text('Pending approval'),
                      ),
                      DropdownMenuItem(value: 'published', child: Text('Published')),
                      DropdownMenuItem(value: 'archived', child: Text('Archived')),
                    ],
                    onChanged: (value) => setState(() => _status = value ?? 'all'),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ...categories.map(
                        (category) => DropdownMenuItem<String?>(
                          value: category,
                          child: Text(category),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _category = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const _EmptyState()
              else
                ...filtered.map((sop) => _SopCard(sop: sop)),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  List<SopDocument> _filterSops(List<SopDocument> sops) {
    final query = _query.toLowerCase();
    return sops.where((sop) {
      final latestBody =
          sop.metadata?['latest_body']?.toString().toLowerCase() ?? '';
      final matchesQuery = query.isEmpty ||
          sop.title.toLowerCase().contains(query) ||
          (sop.summary ?? '').toLowerCase().contains(query) ||
          sop.tags.any((tag) => tag.toLowerCase().contains(query)) ||
          latestBody.contains(query);
      final matchesStatus = _status == 'all' || sop.status == _status;
      final matchesCategory =
          _category == null || (sop.category ?? '') == _category;
      return matchesQuery && matchesStatus && matchesCategory;
    }).toList();
  }

  Future<void> _openEditor(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SopEditorPage()),
    );
    if (result == true) {
      ref.invalidate(sopDocumentsProvider);
    }
  }
}

class _SopCard extends ConsumerWidget {
  const _SopCard({required this.sop});

  final SopDocument sop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = <String>[
      sop.status.replaceAll('_', ' '),
      if ((sop.category ?? '').isNotEmpty) sop.category!,
      if ((sop.currentVersion ?? '').isNotEmpty) sop.currentVersion!,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.description),
        title: Text(sop.title),
        subtitle: Text(meta.join(' • ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SopDetailPage(document: sop)),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'No SOPs yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Create a SOP to standardize procedures across the team.'),
          ],
        ),
      ),
    );
  }
}
