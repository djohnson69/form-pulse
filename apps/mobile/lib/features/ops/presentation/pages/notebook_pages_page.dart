import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/ops_provider.dart';
import '../../../projects/data/projects_provider.dart';
import 'notebook_editor_page.dart';

class NotebookPagesPage extends ConsumerWidget {
  const NotebookPagesPage({super.key, this.projectId});

  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagesAsync = ref.watch(notebookPagesProvider(projectId));
    return Scaffold(
      appBar: AppBar(title: const Text('Notebook')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New page'),
      ),
      body: pagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (pages) {
          if (pages.isEmpty) {
            return const Center(child: Text('No notebook pages yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pages.length,
            itemBuilder: (context, index) {
              final page = pages[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: Text(page.title),
                  subtitle: Text(
                    page.body?.trim().isNotEmpty == true
                        ? page.body!.trim()
                        : 'Tap to edit details',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _openEditor(context, ref, existing: page),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    NotebookPage? existing,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NotebookEditorPage(existing: existing),
      ),
    );
    if (result == true) {
      ref.invalidate(notebookPagesProvider(projectId));
      ref.invalidate(projectsProvider);
    }
  }
}
