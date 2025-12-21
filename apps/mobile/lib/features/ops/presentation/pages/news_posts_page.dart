import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/ops_provider.dart';
import '../../../projects/data/projects_provider.dart';

class NewsPostsPage extends ConsumerWidget {
  const NewsPostsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsPostsProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final projects = projectsAsync.asData?.value ?? const [];
    final projectNames = {
      for (final project in projects) project.id: project.name,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('News & Alerts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New post'),
      ),
      body: newsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (posts) {
          if (posts.isEmpty) {
            return const _EmptyState(
              title: 'No news yet',
              message: 'Share company or site updates here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    post.scope == 'site' ? Icons.location_on : Icons.campaign,
                  ),
                  title: Text(post.title),
                  subtitle: Text(
                    [
                      post.scope.toUpperCase(),
                      if (post.scope == 'site' && post.siteId != null)
                        projectNames[post.siteId] ?? 'Site',
                      _formatDate(post.publishedAt),
                    ].join(' • '),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String scope = 'company';
    String? siteId;
    bool isPublished = true;
    final projects = await ref
        .read(projectsProvider.future)
        .catchError((_) => const <Project>[]);
    if (!context.mounted) {
      titleController.dispose();
      bodyController.dispose();
      return;
    }
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Create news post',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: scope,
                    decoration: const InputDecoration(
                      labelText: 'Scope',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'company', child: Text('Company')),
                      DropdownMenuItem(value: 'site', child: Text('Site')),
                    ],
                    onChanged: (value) =>
                        setState(() => scope = value ?? 'company'),
                  ),
                  if (scope == 'site') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: siteId,
                      decoration: const InputDecoration(
                        labelText: 'Site',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Select site'),
                        ),
                        ...projects.map((project) {
                          return DropdownMenuItem<String?>(
                            value: project.id,
                            child: Text(project.name),
                          );
                        }),
                      ],
                      onChanged: (value) => setState(() => siteId = value),
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publish now'),
                    value: isPublished,
                    onChanged: (value) =>
                        setState(() => isPublished = value),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      if (scope == 'site' && siteId == null) return;
                      await ref.read(opsRepositoryProvider).createNewsPost(
                            title: title,
                            body: bodyController.text.trim().isEmpty
                                ? null
                                : bodyController.text.trim(),
                            scope: scope,
                            siteId: scope == 'site' ? siteId : null,
                            isPublished: isPublished,
                            tags: const [],
                          );
                      if (context.mounted) Navigator.of(context).pop(true);
                    },
                    child: const Text('Publish'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    titleController.dispose();
    bodyController.dispose();
    if (result == true) {
      ref.invalidate(newsPostsProvider);
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style:
                    Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Error: $message'));
  }
}
